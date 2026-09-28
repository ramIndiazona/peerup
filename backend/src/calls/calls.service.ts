import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CallStatus, CallEndReason } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { PresenceService, PresenceStatus } from '../presence/presence.service';
import { RealtimeEventsService } from '../realtime/realtime-events.service';
import { ApiException, notFound } from '../common/errors/api.exception';

export const CALL_STATE_KEY_PREFIX = 'call:';

export interface CallRedisState {
  callId: string;
  participants: [string, string];
  status: CallStatus;
  createdAt: number;
}

@Injectable()
export class CallsService {
  private readonly logger = new Logger(CallsService.name);
  private readonly webRtcTimeoutSeconds: number;
  private readonly postCallAvailableSeconds: number;
  private connectTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly presence: PresenceService,
    private readonly events: RealtimeEventsService,
    config: ConfigService,
  ) {
    this.webRtcTimeoutSeconds = config.get<number>('matchmaking.webRtcTimeoutSeconds', 30);
    this.postCallAvailableSeconds = config.get<number>('matchmaking.postCallAvailableSeconds', 3);
  }

  private callKey(callId: string): string {
    return `${CALL_STATE_KEY_PREFIX}${callId}`;
  }

  // ============================== Session lifecycle ==============================

  async registerCall(callId: string, participants: [string, string], status: CallStatus): Promise<void> {
    const state: CallRedisState = {
      callId,
      participants,
      status,
      createdAt: Date.now(),
    };
    await this.redis.setJson(this.callKey(callId), state, this.webRtcTimeoutSeconds * 4);
  }

  async getCallState(callId: string): Promise<CallRedisState | null> {
    return this.redis.getJson<CallRedisState>(this.callKey(callId));
  }

  async verifyParticipant(callId: string, userId: string): Promise<CallRedisState> {
    const state = await this.getCallState(callId);
    if (!state) {
      throw notFound('CALL_NOT_FOUND', 'Call session not found');
    }
    if (!state.participants.includes(userId)) {
      throw new ApiException('FORBIDDEN', 'You are not a participant of this call', 403);
    }
    // Cross-check with DB (never fully trust redis transient state).
    const db = await this.prisma.callSession.findUnique({ where: { id: callId } });
    if (!db || ![db.userAId, db.userBId].includes(userId)) {
      throw new ApiException('FORBIDDEN', 'You are not a participant of this call', 403);
    }
    return {
      ...state,
      participants: [db.userAId, db.userBId],
    };
  }

  scheduleConnectTimeout(callId: string): void {
    this.clearConnectTimer(callId);
    const timer = setTimeout(async () => {
      const state = await this.getCallState(callId);
      if (!state) return;
      if (
        state.status === CallStatus.MATCHED ||
        state.status === CallStatus.SIGNALING ||
        state.status === CallStatus.CONNECTING
      ) {
        this.logger.warn(`WebRTC connect timeout for ${callId}`);
        await this.failCall(callId, CallEndReason.SIGNALING_FAILED, 'WebRTC connection timed out');
      }
    }, this.webRtcTimeoutSeconds * 1000);
    timer.unref?.();
    this.connectTimers.set(callId, timer);
  }

  async confirmSignaling(callId: string): Promise<void> {
    await this.updateStatus(callId, CallStatus.SIGNALING);
    const state = await this.getCallState(callId);
    if (state) {
      await this.redis.setJson(this.callKey(callId), { ...state, status: CallStatus.SIGNALING }, this.webRtcTimeoutSeconds * 4);
    }
  }

  async confirmConnecting(callId: string): Promise<void> {
    await this.confirmSignaling(callId);
  }

  async confirmConnected(callId: string): Promise<void> {
    await this.updateStatus(callId, CallStatus.CONNECTED);
    this.clearConnectTimer(callId);
    const state = await this.getCallState(callId);
    if (state) {
      await this.redis.setJson(this.callKey(callId), { ...state, status: CallStatus.CONNECTED });
    }
    const db = await this.prisma.callSession.findUnique({ where: { id: callId } });
    if (db && !db.connectedAt) {
      await this.prisma.callSession.update({
        where: { id: callId },
        data: { connectedAt: new Date() },
      });
    }
  }

  private async updateStatus(callId: string, status: CallStatus): Promise<void> {
    await this.prisma.callSession.update({
      where: { id: callId },
      data: { status },
    });
  }

  // ============================== Signaling relay ==============================

  async relaySignaling(
    callId: string,
    senderId: string,
    signalType: 'CALL_OFFER' | 'CALL_ANSWER' | 'ICE_CANDIDATE',
    payload: unknown,
  ): Promise<void> {
    const state = await this.verifyParticipant(callId, senderId);
    const peerId = state.participants.find((id) => id !== senderId);
    if (!peerId) throw new ApiException('CALL_INVALID', 'Call has no peer', 400);

    if (signalType === 'CALL_OFFER') {
      await this.confirmSignaling(callId);
    }

    await this.events.sendToUser(peerId, signalType, {
      callId,
      from: senderId,
      data: payload,
    });
  }

  // ============================== End / Disconnect ==============================

  async endCall(callId: string, userId: string): Promise<{ success: boolean; callId: string }> {
    const state = await this.verifyParticipant(callId, userId);
    if (state.status === CallStatus.ENDED) {
      return { success: true, callId };
    }
    await this.finishCall(callId, CallEndReason.USER_HANGUP, userId, 'User ended the call');
    return { success: true, callId };
  }

  async failCall(callId: string, reason: CallEndReason, detail: string): Promise<void> {
    await this.finishCall(callId, reason, undefined, detail);
  }

  async handleDisconnect(userId: string): Promise<void> {
    const p = await this.presence.get(userId);
    const callId = p?.currentCallId;
    if (!callId) return;

    const state = await this.getCallState(callId);
    const callStatus = state?.status;
    if (!callStatus) return;

    this.logger.log(`User ${userId} disconnected during call ${callId} (${callStatus})`);

    if (callStatus === CallStatus.ENDED) return;

    if (callStatus === CallStatus.MATCHED || callStatus === CallStatus.SIGNALING) {
      // Never had WebRTC; cancel cleanly.
      await this.finishCall(callId, CallEndReason.USER_DISCONNECTED, userId, 'User disconnected before connection');
    } else if (callStatus === CallStatus.CONNECTED || callStatus === CallStatus.CONNECTING) {
      await this.finishCall(callId, CallEndReason.PEER_DISCONNECTED, userId, 'Peer connection lost');
    }
  }

  private async finishCall(
    callId: string,
    reason: CallEndReason,
    endedBy?: string,
    detail?: string,
  ): Promise<void> {
    const db = await this.prisma.callSession.findFirst({ where: { id: callId } });
    if (!db) {
      this.logger.error(`finishCall: call ${callId} not found`);
      return;
    }
    if (db.status === CallStatus.ENDED || db.status === CallStatus.CANCELLED) return;

    const endedAt = new Date();
    const duration = db.connectedAt
      ? Math.max(0, Math.round((endedAt.getTime() - db.connectedAt.getTime()) / 1000))
      : null;

    // 1. Persist final state.
    await this.prisma.callSession.update({
      where: { id: callId },
      data: {
        status: CallStatus.ENDED,
        endedAt,
        duration,
        endReason: reason,
        endedBy: endedBy ?? db.endedBy,
        endReasonDetail: detail,
      },
    });

    await this.redis.setJson(this.callKey(callId), {
      callId,
      participants: [db.userAId, db.userBId],
      status: CallStatus.ENDED,
      createdAt: Date.now(),
    });

    this.clearConnectTimer(callId);

    // 2. Emit CALL_ENDED to both participants and, after a short grace
    //    period, mark them AVAILABLE again (if their socket is alive).
    const postAvailable = async () => {
      for (const uid of [db.userAId, db.userBId]) {
        const p = await this.presence.get(uid);
        if (p && p.currentCallId === callId) {
          const stillConnected = this.events.isConnected(uid);
          await this.presence.upsert(uid, {
            currentCallId: null,
            status: stillConnected ? PresenceStatus.AVAILABLE : PresenceStatus.OFFLINE,
            availableSince: stillConnected ? Date.now() : null,
          });
        }
      }
      const count = await this.presence.getLiveCount();
      await this.events.broadcastLiveCount(count);
    };
    setTimeout(postAvailable, this.postCallAvailableSeconds * 1000).unref();

    await Promise.all([
      this.events.sendToUser(db.userAId, 'CALL_ENDED', {
        callId,
        reason,
        duration,
        endedBy,
      }),
      this.events.sendToUser(db.userBId, 'CALL_ENDED', {
        callId,
        reason,
        duration,
        endedBy,
      }),
    ]);

    this.logger.log(`Call ${callId} finished reason=${reason} duration=${duration ?? 0}s`);
  }

  async getCall(callId: string, userId: string) {
    const state = await this.verifyParticipant(callId, userId);
    const db = await this.prisma.callSession.findUnique({
      where: { id: callId },
      include: { match: true },
    });
    const peerId = state.participants.find((id) => id !== userId);
    return {
      call: {
        id: db?.id,
        status: state.status,
        startedAt: db?.startedAt,
        connectedAt: db?.connectedAt,
        endedAt: db?.endedAt,
        duration: db?.duration,
        endReason: db?.endReason,
      },
      peerId,
    };
  }

  private clearConnectTimer(callId: string): void {
    const t = this.connectTimers.get(callId);
    if (t) {
      clearTimeout(t);
      this.connectTimers.delete(callId);
    }
  }
}