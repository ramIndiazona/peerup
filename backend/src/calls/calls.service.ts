import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
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
export class CallsService implements OnModuleDestroy {
  private readonly logger = new Logger(CallsService.name);
  private readonly webRtcTimeoutSeconds: number;
  private readonly postCallAvailableSeconds: number;
  readonly reconnectTimeoutSeconds: number;
  private reconnectTimers = new Map<string, NodeJS.Timeout>();
  /** How many extra attempts the grace period gets when the call lock is busy. */
  private readonly recoveryLockRetries = 3;
  /** Backoff between those extra attempts. */
  private readonly recoveryLockRetryMs = 1000;
  private connectTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly presence: PresenceService,
    private readonly events: RealtimeEventsService,
    config: ConfigService,
  ) {
    this.reconnectTimeoutSeconds = config.get<number>('webrtc.reconnectTimeoutSeconds', 15);
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
    await this.withCallLock(callId, async () => {
      const state = await this.getCallState(callId);
      if (!state || state.status === CallStatus.CONNECTED || this.isTerminal(state.status)) return;
      await this.prisma.callSession.updateMany({
        where: { id: callId, status: { notIn: [CallStatus.ENDED, CallStatus.CANCELLED, CallStatus.CONNECTED] } },
        data: { status: CallStatus.SIGNALING },
      });
      await this.redis.setJson(this.callKey(callId), { ...state, status: CallStatus.SIGNALING }, this.webRtcTimeoutSeconds * 4);
    });
  }

  async confirmConnecting(callId: string): Promise<void> {
    await this.confirmSignaling(callId);
  }

  async confirmConnected(callId: string): Promise<void> {
    await this.withCallLock(callId, async () => {
      const state = await this.getCallState(callId);
      if (!state || this.isTerminal(state.status)) return;
      const db = await this.prisma.callSession.findUnique({ where: { id: callId } });
      if (!db || this.isTerminal(db.status)) return;
      await this.prisma.callSession.updateMany({
        where: { id: callId, status: { notIn: [CallStatus.ENDED, CallStatus.CANCELLED] } },
        data: { status: CallStatus.CONNECTED, connectedAt: db.connectedAt ?? new Date() },
      });
      this.clearConnectTimer(callId);
      await this.redis.setJson(this.callKey(callId), { ...state, status: CallStatus.CONNECTED });
    });
  }

  private isTerminal(status: CallStatus): boolean {
    return status === CallStatus.ENDED || status === CallStatus.CANCELLED;
  }

  // Reuse the Redis lock helper so timeout, reconnect and hangup have one winner.
  private async withCallLock<T>(callId: string, work: () => Promise<T>): Promise<T> {
    const deadline = Date.now() + 5000;
    do {
      const release = await this.redis.acquireLock(`call:${callId}`, 30);
      if (release) {
        try { return await work(); } finally { await release(); }
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    } while (Date.now() < deadline);
    throw new ApiException('CALL_BUSY', 'Call update in progress, try again', 409);
  }

  // ============================== Signaling relay ==============================

  async relaySignaling(
    callId: string,
    senderId: string,
    signalType: 'CALL_OFFER' | 'CALL_ANSWER' | 'ICE_CANDIDATE',
    payload: unknown,
  ): Promise<void> {
    const state = await this.verifyParticipant(callId, senderId);
    if (this.isTerminal(state.status)) return;
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

  private recoveryKey(callId: string, userId: string): string {
    return `call:reconnecting:${callId}:${userId}`;
  }

  async handleDisconnect(userId: string, socketId?: string): Promise<void> {
    const p = await this.presence.get(userId);
    const callId = p?.currentCallId;
    if (!callId) return;
    await this.withCallLock(callId, async () => {
      const current = await this.presence.get(userId);
      // A replacement socket may have authenticated while we waited for the lock.
      if (current?.currentCallId !== callId || (socketId && current.socketId !== socketId)) return;
      const state = await this.getCallState(callId);
      if (!state || this.isTerminal(state.status)) return;
      if (state.status !== CallStatus.CONNECTED) {
        await this.finishCallLocked(callId,
          state.status === CallStatus.CONNECTING ? CallEndReason.PEER_DISCONNECTED : CallEndReason.USER_DISCONNECTED,
          userId, 'User disconnected before connection');
        return;
      }
      const key = this.recoveryKey(callId, userId);
      if (await this.redis.get(key)) return; // Repeated callbacks never extend grace.
      const deadline = Date.now() + this.reconnectTimeoutSeconds * 1000;
      await this.redis.setJson(key, { deadline }, this.reconnectTimeoutSeconds + 120);
      this.scheduleRecoveryExpiry(callId, userId, key, deadline);
      await Promise.all(state.participants.map((id) => this.events.sendToUser(id, 'CALL_RECONNECTING', {
        callId, userId, reason: 'socket_disconnected',
      })));
    });
  }

  /**
   * Arm the grace-period expiry for a reconnecting participant.
   *
   * The stored deadline is authoritative, so a retry can never extend it and
   * the call still ends exactly `reconnectTimeoutSeconds` after the disconnect.
   */
  private scheduleRecoveryExpiry(callId: string, userId: string, key: string, deadline: number, attempt = 0): void {
    // On the first attempt wait for the stored deadline; a retry waits for the
    // call lock to clear instead.
    const delay = attempt === 0 ? Math.max(deadline - Date.now(), 0) : attempt * this.recoveryLockRetryMs;
    const timer = setTimeout(() => {
      void this.expireRecovery(callId, userId, key, deadline, attempt);
    }, delay);
    timer.unref?.();
    this.reconnectTimers.set(key, timer);
  }

  private async expireRecovery(callId: string, userId: string, key: string, deadline: number, attempt = 0): Promise<void> {
    try {
      await this.withCallLock(callId, async () => {
        const pending = await this.redis.getJson<{ deadline: number }>(key);
        // A cleared key means a reconnect or a manual hangup already won.
        if (pending?.deadline !== deadline) return;
        await this.finishCallLocked(callId, CallEndReason.PEER_DISCONNECTED, userId, 'Reconnect timed out');
      });
    } catch (error) {
      // The call lock was unavailable (for example another instance died while
      // holding it). Retry against the same deadline so an established call
      // can never be left open, unless the call already ended another way.
      if (attempt >= this.recoveryLockRetries || !this.reconnectTimers.has(key)) return;
      this.logger.error(`Call recovery expiry retry ${attempt + 1} call=${callId} user=${userId}: ${error}`);
      this.scheduleRecoveryExpiry(callId, userId, key, deadline, attempt + 1);
    }
  }

  async handleReconnect(userId: string): Promise<void> {
    const p = await this.presence.get(userId);
    if (!p?.currentCallId) return;
    const callId = p.currentCallId;
    await this.withCallLock(callId, async () => {
      const state = await this.getCallState(callId);
      if (!state || this.isTerminal(state.status)) return;
      const key = this.recoveryKey(callId, userId);
      const pending = await this.redis.getJson<{ deadline: number }>(key);
      if (pending && Date.now() >= pending.deadline) {
        await this.finishCallLocked(callId, CallEndReason.PEER_DISCONNECTED, userId, 'Reconnect timed out');
        return;
      }
      await this.clearRecovery(callId, userId);
      if (state.status === CallStatus.CONNECTED) {
        // Signaling is available again; clients still verify actual WebRTC connectivity.
        await Promise.all(state.participants.map((id) => this.events.sendToUser(id, 'CALL_RECONNECTED', {
          callId, userId, reason: 'socket_reconnected',
        })));
      }
    });
  }

  async requestRecovery(callId: string, userId: string): Promise<void> {
    const state = await this.verifyParticipant(callId, userId);
    if (state.status !== CallStatus.CONNECTED) return;
    const peer = state.participants.find((id) => id !== userId)!;
    await this.events.sendToUser(peer, 'CALL_RECONNECTING', { callId, userId, reason: 'ice_restart' });
  }

  private async clearRecovery(callId: string, userId: string): Promise<void> {
    const key = this.recoveryKey(callId, userId);
    const timer = this.reconnectTimers.get(key);
    if (timer) clearTimeout(timer);
    this.reconnectTimers.delete(key);
    await this.redis.del(key);
  }

  private async finishCall(
    callId: string,
    reason: CallEndReason,
    endedBy?: string,
    detail?: string,
  ): Promise<void> {
    await this.withCallLock(callId, () => this.finishCallLocked(callId, reason, endedBy, detail));
  }

  private async finishCallLocked(
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
    const finished = await this.prisma.callSession.updateMany({
      where: { id: callId, status: { notIn: [CallStatus.ENDED, CallStatus.CANCELLED] } },
      data: {
        status: CallStatus.ENDED,
        endedAt,
        duration,
        endReason: reason,
        endedBy: endedBy ?? db.endedBy,
        endReasonDetail: detail,
      },
    });

    if (finished.count === 0) return;
    await Promise.all([db.userAId, db.userBId].map((id) => this.clearRecovery(callId, id)));

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

  onModuleDestroy(): void {
    for (const timer of this.connectTimers.values()) clearTimeout(timer);
    for (const timer of this.reconnectTimers.values()) clearTimeout(timer);
    this.connectTimers.clear();
    this.reconnectTimers.clear();
  }

  private clearConnectTimer(callId: string): void {
    const t = this.connectTimers.get(callId);
    if (t) {
      clearTimeout(t);
      this.connectTimers.delete(callId);
    }
  }
}