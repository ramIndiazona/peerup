

import { Logger } from "@nestjs/common";
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from "@nestjs/websockets";
import { Socket, Server } from "socket.io";
import { ConfigService } from "@nestjs/config";
import {
  Cron,
  CronExpression,
} from "@nestjs/schedule";

import { TokenService } from "../auth/token.service";
import {
  PresenceService,
  PresenceStatus,
} from "../presence/presence.service";
import { RealtimeEventsService } from "./realtime-events.service";
import { MatchmakingService } from "../matchmaking/matchmaking.service";
import { CallsService } from "../calls/calls.service";
import { PrismaService } from "../prisma/prisma.service";
import { ApiException } from "../common/errors/api.exception";

@WebSocketGateway({
  cors: {
    origin: true,
    credentials: true,
  },

  path: "/realtime",

  serveClient: false,
})
export class RealtimeGateway
  implements
  OnGatewayConnection,
  OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger =
    new Logger(RealtimeGateway.name);

  /**
   * Socket IDs that successfully passed JWT + account validation.
   *
   * We still register the socket immediately after JWT validation so
   * very early client events don't race the async DB ban check.
   */
  private readonly authenticatedSockets =
    new Set<string>();

  constructor(
    private readonly events: RealtimeEventsService,
    private readonly tokens: TokenService,
    private readonly presence: PresenceService,
    private readonly matchmaking: MatchmakingService,
    private readonly calls: CallsService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) { }

  // ============================================================
  // CONNECTION
  // ============================================================

  async handleConnection(
    socket: Socket,
  ): Promise<void> {
    let userId: string | null = null;

    try {
      // --------------------------------------------------------
      // Extract token
      // --------------------------------------------------------

      const token =
        this.extractToken(socket);

      if (!token) {
        this.logger.warn(
          `[WS] missing token socket=${socket.id}`,
        );

        socket.emit("ERROR", {
          code: "UNAUTHORIZED",
          message: "Missing token",
        });

        socket.disconnect(true);

        return;
      }

      // --------------------------------------------------------
      // Verify JWT
      // --------------------------------------------------------

      const payload =
        this.tokens.verifyAccess(token);

      if (!payload?.sub) {
        throw new ApiException(
          "UNAUTHORIZED",
          "Invalid token",
          401,
        );
      }

      userId = payload.sub;

      // --------------------------------------------------------
      // IMPORTANT
      //
      // Register immediately after JWT verification.
      //
      // This fixes:
      //
      // socket connected
      //       ↓
      // LIVE_START
      //       ↓
      // requireUser()
      //       ↓
      // user not registered
      //
      // The previous implementation waited for the DB query
      // before registering the socket.
      // --------------------------------------------------------

      this.events.register(
        socket.id,
        userId,
        socket,
      );

      socket.data.userId =
        userId;

      // --------------------------------------------------------
      // Account validation
      // --------------------------------------------------------

      const account =
        await this.prisma.user.findUnique({
          where: {
            id: userId,
          },

          select: {
            id: true,
            isBanned: true,
          },
        });

      if (!account) {
        this.logger.warn(
          `[WS] user not found user=${userId} socket=${socket.id}`,
        );

        this.events.unregister(
          socket.id,
        );

        socket.emit("ERROR", {
          code: "UNAUTHORIZED",
          message: "Account not found",
        });

        socket.disconnect(true);

        return;
      }

      if (account.isBanned) {
        this.logger.warn(
          `[WS] banned account user=${userId}`,
        );

        this.events.unregister(
          socket.id,
        );

        socket.emit("ERROR", {
          code: "ACCOUNT_BANNED",
          message:
            "Account is suspended",
        });

        socket.disconnect(true);

        return;
      }

      // --------------------------------------------------------
      // Mark socket authenticated
      // --------------------------------------------------------

      this.authenticatedSockets.add(
        socket.id,
      );

      socket.data.authenticated =
        true;

      // --------------------------------------------------------
      // Update presence socket binding
      // --------------------------------------------------------

      const existing =
        await this.presence.get(
          userId,
        );

      if (existing) {
        const previousSocketId =
          existing.socketId;

        // ------------------------------------------------------
        // IMPORTANT: bind the NEW socket first.
        //
        // If the old socket disconnects after this point, its
        // disconnect handler will see that presence.socketId is
        // different and will NOT mark the user offline.
        // ------------------------------------------------------

        await this.presence.upsert(
          userId,
          {
            socketId:
              socket.id,
            status:
              existing.status === PresenceStatus.OFFLINE
                ? PresenceStatus.ONLINE
                : existing.status,
          },
        );

        if (
          previousSocketId &&
          previousSocketId !== socket.id
        ) {
          // ----------------------------------------------------
          // Invalidate the old socket BEFORE disconnecting it.
          // This prevents an old socket from sending LIVE_STOP,
          // START_MATCH, HEARTBEAT, or call events after a new
          // socket has taken ownership of the user session.
          // ----------------------------------------------------

          this.authenticatedSockets.delete(
            previousSocketId,
          );

          const previousSocket =
            this.server.sockets.sockets.get(
              previousSocketId,
            );

          if (previousSocket) {
            previousSocket.data.authenticated =
              false;

            previousSocket.disconnect(
              true,
            );
          }

          // Remove the old socket from the realtime registry.
          // Its later disconnect callback becomes a no-op.
          this.events.unregister(
            previousSocketId,
          );

          this.logger.log(
            `[WS] replaced old socket ` +
            `user=${userId} ` +
            `oldSocket=${previousSocketId} ` +
            `newSocket=${socket.id}`,
          );
        }

        this.logger.log(
          `[WS] presence socket updated ` +
          `user=${userId} ` +
          `status=${existing.status} ` +
          `socket=${socket.id}`,
        );
      }

      // --------------------------------------------------------
      // Connection successful
      // --------------------------------------------------------

      this.logger.log(
        `[WS] CONNECTED user=${userId} ` +
        `socket=${socket.id}`,
      );

      socket.emit(
        "CONNECTED",
        {
          userId,
          callReconnectTimeoutSeconds: this.calls.reconnectTimeoutSeconds,

          heartbeatIntervalSeconds:
            this.config.get<number>(
              "heartbeat.intervalSeconds",
              15,
            ),
        },
      );

      await this.calls.handleReconnect(userId);

      // --------------------------------------------------------
      // Send current live snapshot
      // --------------------------------------------------------

      void this.presence
        .broadcastLiveUsers()
        .catch((error) => {
          this.logger.warn(
            `[WS] LIVE_USERS broadcast failed ` +
            `user=${userId} ` +
            `${this.errorMessage(error)}`,
          );
        });

      // --------------------------------------------------------
      // Recovery
      //
      // If the user reconnects while MATCHED / IN_CALL,
      // the Flutter side can call getStatus() and recover.
      // --------------------------------------------------------

      if (
        existing?.currentCallId &&
        (
          existing.status ===
          PresenceStatus.MATCHED ||
          existing.status ===
          PresenceStatus.CONNECTING ||
          existing.status ===
          PresenceStatus.IN_CALL
        )
      ) {
        this.logger.log(
          `[WS] reconnecting active call ` +
          `user=${userId} ` +
          `call=${existing.currentCallId}`,
        );
      }
    } catch (error) {
      this.logger.warn(
        `[WS] connection authentication failed ` +
        `socket=${socket.id} ` +
        `user=${userId ?? "unknown"} ` +
        `${this.errorMessage(error)}`,
      );

      this.authenticatedSockets.delete(
        socket.id,
      );

      this.events.unregister(
        socket.id,
      );

      if (socket.connected) {
        socket.emit("ERROR", {
          code: "UNAUTHORIZED",
          message:
            "Authentication failed",
        });

        socket.disconnect(true);
      }
    }
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  async handleDisconnect(
    socket: Socket,
  ): Promise<void> {
    // ----------------------------------------------------------
    // Remove authentication marker
    // ----------------------------------------------------------

    this.authenticatedSockets.delete(
      socket.id,
    );

    // ----------------------------------------------------------
    // Remove socket mapping. If a newer socket already replaced
    // this socket, unregister() returns no user and we exit without
    // touching presence.
    // ----------------------------------------------------------

    const {
      userId,
    } =
      this.events.unregister(
        socket.id,
      );

    if (!userId) {
      return;
    }

    this.logger.log(
      `[WS] DISCONNECTED ` +
      `user=${userId} ` +
      `socket=${socket.id}`,
    );

    // ----------------------------------------------------------
    // Get current presence
    // ----------------------------------------------------------

    const current =
      await this.presence.get(
        userId,
      );

    if (!current) {
      return;
    }

    // ----------------------------------------------------------
    // IMPORTANT
    //
    // A user may have connected with a NEW socket before the
    // OLD socket's disconnect callback executes.
    //
    // Never change presence for an old socket.
    // ----------------------------------------------------------

    // A presence record without a socketId is not owned by this
    // disconnect callback. Do not let an unknown/stale socket
    // transition the user offline.
    if (current.socketId !== socket.id) {
      this.logger.debug(
        `[WS] ignoring stale disconnect ` +
        `user=${userId} ` +
        `oldSocket=${socket.id} ` +
        `currentSocket=${current.socketId ?? "none"}`,
      );

      return;
    }

    try {
      // --------------------------------------------------------
      // SEARCHING
      // --------------------------------------------------------

      if (
        current.status ===
        PresenceStatus.SEARCHING
      ) {
        this.logger.log(
          `[WS] cancelling matchmaking ` +
          `user=${userId}`,
        );

        await this.matchmaking
          .cancelByDisconnect(
            userId,
          );

        return;
      }

      // --------------------------------------------------------
      // ACTIVE CALL
      // --------------------------------------------------------

      if (
        current.currentCallId &&
        (
          current.status ===
          PresenceStatus.MATCHED ||
          current.status ===
          PresenceStatus.CONNECTING ||
          current.status ===
          PresenceStatus.IN_CALL
        )
      ) {
        this.logger.log(
          `[WS] call disconnect ` +
          `user=${userId} ` +
          `call=${current.currentCallId}`,
        );

        await this.calls.handleDisconnect(
          userId,
          socket.id,
        );

        return;
      }

      // --------------------------------------------------------
      // NORMAL OFFLINE
      // --------------------------------------------------------

      await this.presence.setOffline(
        userId,
      );
    } catch (error) {
      this.logger.error(
        `[WS] disconnect handling failed ` +
        `user=${userId} ` +
        `${this.errorMessage(error)}`,
      );

      try {
        const latest =
          await this.presence.get(
            userId,
          );

        // Don't overwrite a newer socket.
        if (
          !latest ||
          latest.socketId !==
          socket.id
        ) {
          return;
        }

        await this.presence.setOffline(
          userId,
        );
      } catch (offlineError) {
        this.logger.error(
          `[WS] fallback offline failed ` +
          `user=${userId} ` +
          `${this.errorMessage(offlineError)}`,
        );
      }
    }
  }

  // ============================================================
  // HEARTBEAT
  // ============================================================

  @SubscribeMessage("HEARTBEAT")
  async onHeartbeat(
    socket: Socket,
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      await this.presence.heartbeat(
        userId,
        socket.id,
      );

      socket.emit(
        "HEARTBEAT_ACK",
        {
          at: Date.now(),
        },
      );
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // LIVE START
  // ============================================================

  @SubscribeMessage("LIVE_START")
  async onLiveStart(
    socket: Socket,
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      const current =
        await this.presence.get(
          userId,
        );

      const status =
        current?.status;

      // --------------------------------------------------------
      // If user is already in an active flow, DON'T reset it.
      // --------------------------------------------------------

      if (
        status ===
        PresenceStatus.SEARCHING ||
        status ===
        PresenceStatus.MATCHED ||
        status ===
        PresenceStatus.CONNECTING ||
        status ===
        PresenceStatus.IN_CALL ||
        status ===
        PresenceStatus.ENDING
      ) {
        await this.presence.heartbeat(
          userId,
          socket.id,
        );

        this.logger.log(
          `[LIVE] preserving active state ` +
          `user=${userId} ` +
          `status=${status}`,
        );
      } else {
        // ------------------------------------------------------
        // OFFLINE / AVAILABLE
        // -> AVAILABLE
        // ------------------------------------------------------

        await this.presence.availability(
          userId,
          true,
          socket.id,
        );

        this.logger.log(
          `[LIVE] user became AVAILABLE ` +
          `user=${userId}`,
        );
      }

      const refreshed =
        await this.presence.get(
          userId,
        );

      socket.emit(
        "LIVE_STARTED",
        {
          userId,

          status:
            refreshed?.status ??
            PresenceStatus.AVAILABLE,
        },
      );
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // LIVE STOP
  // ============================================================

  @SubscribeMessage("LIVE_STOP")
  async onLiveStop(
    socket: Socket,
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      const current =
        await this.presence.get(
          userId,
        );

      // --------------------------------------------------------
      // Cancel matchmaking first.
      // --------------------------------------------------------

      if (
        current?.status ===
        PresenceStatus.SEARCHING
      ) {
        await this.matchmaking.cancel(
          userId,
        );
      }

      // --------------------------------------------------------
      // Then offline
      // --------------------------------------------------------

      await this.presence.setOffline(
        userId,
      );

      this.logger.log(
        `[LIVE] user stopped live ` +
        `user=${userId}`,
      );

      socket.emit(
        "LIVE_STOPPED",
        {
          userId,

          status:
            PresenceStatus.OFFLINE,
        },
      );
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // START MATCH
  // ============================================================

  @SubscribeMessage("START_MATCH")
  async onStartMatch(
    socket: Socket,
    payload?: {
      filters?: Record<
        string,
        any
      >;
    },
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      await this.matchmaking.start(
        userId,
        payload?.filters ?? {},
      );

      this.logger.log(
        `[MATCH] START_MATCH received ` +
        `user=${userId}`,
      );
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // CANCEL MATCH
  // ============================================================

  @SubscribeMessage("START_MATCH_CANCEL")
  async onCancelMatch(
    socket: Socket,
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      await this.matchmaking.cancel(
        userId,
      );
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // CALL OFFER
  // ============================================================

  @SubscribeMessage("CALL_OFFER")
  async onOffer(
    socket: Socket,
    payload: {
      callId: string;
      data: unknown;
    },
  ): Promise<void> {
    await this.relaySignaling(
      socket,
      payload,
      "CALL_OFFER",
    );
  }

  // ============================================================
  // CALL ANSWER
  // ============================================================

  @SubscribeMessage("CALL_ANSWER")
  async onAnswer(
    socket: Socket,
    payload: {
      callId: string;
      data: unknown;
    },
  ): Promise<void> {
    await this.relaySignaling(
      socket,
      payload,
      "CALL_ANSWER",
    );
  }

  // ============================================================
  // ICE CANDIDATE
  // ============================================================

  @SubscribeMessage("ICE_CANDIDATE")
  async onIceCandidate(
    socket: Socket,
    payload: {
      callId: string;
      data: unknown;
    },
  ): Promise<void> {
    await this.relaySignaling(
      socket,
      payload,
      "ICE_CANDIDATE",
    );
  }

  // ============================================================
  // CALL CONNECTED
  // ============================================================

  @SubscribeMessage("CALL_RECONNECTING")
  async onCallReconnecting(socket: Socket, payload: { callId: string }): Promise<void> {
    try {
      const userId = this.requireUser(socket);
      if (!payload?.callId) throw new ApiException('INVALID_CALL', 'callId is required', 400);
      await this.calls.requestRecovery(payload.callId, userId);
    } catch (error) {
      this.error(socket, error);
    }
  }

  @SubscribeMessage("CALL_CONNECTED")
  async onCallConnected(
    socket: Socket,
    payload: {
      callId: string;
    },
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      if (!payload?.callId) {
        throw new ApiException(
          "INVALID_CALL",
          "callId is required",
          400,
        );
      }

      const state =
        await this.calls.verifyParticipant(
          payload.callId,
          userId,
        );

      await this.calls.confirmConnected(
        payload.callId,
      );

      const peer =
        state.participants.find(
          (id) => id !== userId,
        );

      if (peer) {
        await this.events.sendToUser(
          peer,
          "CALL_CONNECTED",
          {
            callId:
              payload.callId,

            at:
              Date.now(),
          },
        );
      }
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // END CALL
  // ============================================================

  @SubscribeMessage("END_CALL")
  async onEndCall(
    socket: Socket,
    payload: {
      callId: string;
    },
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      if (!payload?.callId) {
        throw new ApiException(
          "INVALID_CALL",
          "callId is required",
          400,
        );
      }

      await this.calls.endCall(
        payload.callId,
        userId,
      );
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // CALL FAILED
  // ============================================================

  @SubscribeMessage("CALL_FAILED")
  async onCallFailed(
    socket: Socket,
    payload: {
      callId: string;
      reason?: string;
    },
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      if (!payload?.callId) {
        throw new ApiException(
          "INVALID_CALL",
          "callId is required",
          400,
        );
      }

      await this.calls.verifyParticipant(
        payload.callId,
        userId,
      );

      await this.calls.failCall(
        payload.callId,
        "SIGNALING_FAILED",
        payload.reason ??
        "client reported failure",
      );
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // PRESENCE SWEEP
  // ============================================================

  @Cron(
    CronExpression.EVERY_10_SECONDS,
    {
      name: "presence-sweep",
    },
  )
  async sweepPresence(): Promise<void> {
    try {
      const timeoutMs =
        this.config.get<number>(
          "heartbeat.timeoutSeconds",
          45,
        ) * 1000;

      const liveIds =
        await this.presence.listLiveUserIds();

      if (!liveIds.length) {
        return;
      }

      const now =
        Date.now();

      const expired: string[] = [];

      // --------------------------------------------------------
      // Find expired users
      // --------------------------------------------------------

      for (const userId of liveIds) {
        const p =
          await this.presence.get(
            userId,
          );

        if (!p) {
          expired.push(
            userId,
          );
          continue;
        }

        if (
          now -
          p.lastHeartbeat >
          timeoutMs
        ) {
          expired.push(
            userId,
          );
        }
      }

      if (!expired.length) {
        return;
      }

      // --------------------------------------------------------
      // Expire users
      // --------------------------------------------------------

      for (const userId of expired) {
        this.logger.log(
          `[LIVE] PRESENCE_EXPIRED ` +
          `user=${userId}`,
        );

        const p =
          await this.presence.get(
            userId,
          );

        if (
          p?.status ===
          PresenceStatus.SEARCHING
        ) {
          await this.matchmaking
            .cancelByDisconnect(
              userId,
            )
            .catch((error) => {
              this.logger.warn(
                `[LIVE] expired search cleanup failed ` +
                `user=${userId} ` +
                `${this.errorMessage(error)}`,
              );
            });

          continue;
        }

        // ------------------------------------------------------
        // Active call
        // ------------------------------------------------------

        if (
          p?.currentCallId &&
          (
            p.status ===
            PresenceStatus.MATCHED ||
            p.status ===
            PresenceStatus.CONNECTING ||
            p.status ===
            PresenceStatus.IN_CALL
          )
        ) {
          await this.calls
            .handleDisconnect(
              userId,
            )
            .catch((error) => {
              this.logger.warn(
                `[LIVE] expired call cleanup failed ` +
                `user=${userId} ` +
                `${this.errorMessage(error)}`,
              );
            });

          continue;
        }

        await this.presence.setOffline(
          userId,
        );
      }
    } catch (error) {
      this.logger.error(
        `[LIVE] presence sweep failed ` +
        `${this.errorMessage(error)}`,
      );
    }
  }

  // ============================================================
  // SIGNALING RELAY
  // ============================================================

  private async relaySignaling(
    socket: Socket,
    payload: {
      callId: string;
      data: unknown;
    },
    signalType:
      | "CALL_OFFER"
      | "CALL_ANSWER"
      | "ICE_CANDIDATE",
  ): Promise<void> {
    try {
      const userId =
        this.requireUser(socket);

      if (!payload?.callId) {
        throw new ApiException(
          "INVALID_SIGNAL",
          "callId is required",
          400,
        );
      }

      if (
        payload.data ===
        undefined ||
        payload.data ===
        null
      ) {
        throw new ApiException(
          "INVALID_SIGNAL",
          "Signal data is required",
          400,
        );
      }

      await this.calls.relaySignaling(
        payload.callId,
        userId,
        signalType,
        payload.data,
      );
    } catch (error) {
      this.error(
        socket,
        error,
      );
    }
  }

  // ============================================================
  // REQUIRE USER
  // ============================================================

  private requireUser(
    socket: Socket,
  ): string {
    // ----------------------------------------------------------
    // First check that this socket passed connection validation.
    // ----------------------------------------------------------

    const authenticated =
      this.authenticatedSockets.has(
        socket.id,
      ) &&
      socket.data.authenticated ===
      true;

    if (!authenticated) {
      throw new ApiException(
        "UNAUTHORIZED",
        "Socket is no longer active",
        401,
      );
    }

    // ----------------------------------------------------------
    // Then get user from realtime registry.
    // ----------------------------------------------------------

    const userId =
      this.events.getUserId(
        socket.id,
      );

    if (!userId) {
      throw new ApiException(
        "UNAUTHORIZED",
        "Not authenticated",
        401,
      );
    }

    return userId;
  }

  // ============================================================
  // ERROR
  // ============================================================

  private error(
    socket: Socket,
    error: unknown,
  ): void {
    if (
      error instanceof
      ApiException
    ) {
      socket.emit(
        "ERROR",
        {
          code:
            error.code,

          message:
            error.message,
        },
      );

      return;
    }

    this.logger.warn(
      `[WS] handler error ` +
      `${this.errorMessage(error)}`,
    );

    socket.emit(
      "ERROR",
      {
        code:
          "INTERNAL_ERROR",

        message:
          "Unexpected error",
      },
    );
  }

  // ============================================================
  // TOKEN EXTRACTION
  // ============================================================

  private extractToken(
    socket: Socket,
  ): string | null {
    // ----------------------------------------------------------
    // Socket.IO auth
    // ----------------------------------------------------------

    const auth =
      socket.handshake
        .auth as
      | {
        token?: string;
      }
      | undefined;

    if (auth?.token) {
      return auth.token;
    }

    // ----------------------------------------------------------
    // Authorization header
    // ----------------------------------------------------------

    const header =
      socket.handshake
        .headers?.authorization;

    if (
      header &&
      header.startsWith(
        "Bearer ",
      )
    ) {
      return header.slice(
        7,
      );
    }

    return null;
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  private errorMessage(
    error: unknown,
  ): string {
    if (
      error instanceof Error
    ) {
      return (
        error.stack ??
        error.message
      );
    }

    return String(error);
  }
}