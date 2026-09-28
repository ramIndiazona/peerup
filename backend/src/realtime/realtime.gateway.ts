// // import { Logger } from "@nestjs/common";
// // import {
// //   OnGatewayConnection,
// //   OnGatewayDisconnect,
// //   SubscribeMessage,
// //   WebSocketGateway,
// //   WebSocketServer,
// // } from "@nestjs/websockets";
// // import { Socket, Server } from "socket.io";
// // import { ConfigService } from "@nestjs/config";
// // import { Cron, CronExpression } from "@nestjs/schedule";
// // import { TokenService } from "../auth/token.service";
// // import { PresenceService, PresenceStatus } from "../presence/presence.service";
// // import { RealtimeEventsService } from "./realtime-events.service";
// // import { MatchmakingService } from "../matchmaking/matchmaking.service";
// // import { CallsService } from "../calls/calls.service";
// // import { PrismaService } from "../prisma/prisma.service";
// // import { ApiException } from "../common/errors/api.exception";

// // @WebSocketGateway({
// //   cors: { origin: true, credentials: true },
// //   path: "/realtime",
// //   serveClient: false,
// // })
// // export class RealtimeGateway
// //   implements OnGatewayConnection, OnGatewayDisconnect
// // {
// //   @WebSocketServer()
// //   server!: Server;

// //   private readonly logger = new Logger(RealtimeGateway.name);

// //   constructor(
// //     private readonly events: RealtimeEventsService,
// //     private readonly tokens: TokenService,
// //     private readonly presence: PresenceService,
// //     private readonly matchmaking: MatchmakingService,
// //     private readonly calls: CallsService,
// //     private readonly prisma: PrismaService,
// //     private readonly config: ConfigService,
// //   ) {}

// //   // async handleConnection(socket: Socket): Promise<void> {
// //   //   try {
// //   //     const token = this.extractToken(socket);
// //   //     if (!token) {
// //   //       socket.emit("ERROR", {
// //   //         code: "UNAUTHORIZED",
// //   //         message: "Missing token",
// //   //       });
// //   //       socket.disconnect(true);
// //   //       return;
// //   //     }
// //   //     const payload = this.tokens.verifyAccess(token);
// //   //     if (!payload?.sub)
// //   //       throw new ApiException("UNAUTHORIZED", "Invalid token", 401);

// //   //     const ban = await this.prisma.user.findUnique({
// //   //       where: { id: payload.sub },
// //   //       select: { isBanned: true },
// //   //     });
// //   //     if (!ban || ban.isBanned) {
// //   //       socket.emit("ERROR", {
// //   //         code: "ACCOUNT_BANNED",
// //   //         message: "Account is suspended",
// //   //       });
// //   //       socket.disconnect(true);
// //   //       return;
// //   //     }

// //   //     this.logger.log(
// //   //       `[LIVE] socket connected user=${payload.sub} (socket ${socket.id})`,
// //   //     );
// //   //     this.events.register(socket.id, payload.sub, socket);

// //   //     const existing = await this.presence.get(payload.sub);
// //   //     if (existing) {
// //   //       await this.presence.upsert(payload.sub, { socketId: socket.id });
// //   //     }

// //   //     socket.emit("CONNECTED", {
// //   //       userId: payload.sub,
// //   //       heartbeatIntervalSeconds: this.config.get<number>(
// //   //         "heartbeat.intervalSeconds",
// //   //         15,
// //   //       ),
// //   //     });
// //   //     // Send the current snapshot to every client (including the new socket)
// //   //     // so reconnects recover the live presence without polling.
// //   //     void this.presence.broadcastLiveUsers();
// //   //   } catch (err) {
// //   //     this.logger.warn(`WS auth failed: ${(err as Error).message}`);
// //   //     socket.emit("ERROR", {
// //   //       code: "UNAUTHORIZED",
// //   //       message: "Authentication failed",
// //   //     });
// //   //     socket.disconnect(true);
// //   //   }
// //   // }

// //   async handleConnection(socket: Socket): Promise<void> {
// //   try {
// //     const token = this.extractToken(socket);

// //     if (!token) {
// //       socket.emit("ERROR", {
// //         code: "UNAUTHORIZED",
// //         message: "Missing token",
// //       });

// //       socket.disconnect(true);
// //       return;
// //     }

// //     const payload = this.tokens.verifyAccess(token);

// //     if (!payload?.sub) {
// //       throw new ApiException(
// //         "UNAUTHORIZED",
// //         "Invalid token",
// //         401,
// //       );
// //     }

// //     const userId = payload.sub;

// //     // IMPORTANT:
// //     // Register immediately after JWT validation.
// //     //
// //     // This prevents:
// //     //
// //     // socket connected
// //     //       ↓
// //     // LIVE_START
// //     //       ↓
// //     // requireUser()
// //     //       ↓
// //     // user not registered yet
// //     //
// //     this.events.register(
// //       socket.id,
// //       userId,
// //       socket,
// //     );

// //     // Now perform slower DB validation.
// //     const ban = await this.prisma.user.findUnique({
// //       where: {
// //         id: userId,
// //       },
// //       select: {
// //         isBanned: true,
// //       },
// //     });

// //     if (!ban || ban.isBanned) {
// //       this.events.unregister(socket.id);

// //       socket.emit("ERROR", {
// //         code: "ACCOUNT_BANNED",
// //         message: "Account is suspended",
// //       });

// //       socket.disconnect(true);

// //       return;
// //     }

// //     this.logger.log(
// //       `[LIVE] socket connected user=${userId} socket=${socket.id}`,
// //     );

// //     const existing = await this.presence.get(userId);

// //     if (existing) {
// //       await this.presence.upsert(
// //         userId,
// //         {
// //           socketId: socket.id,
// //         },
// //       );
// //     }

// //     socket.emit(
// //       "CONNECTED",
// //       {
// //         userId,
// //         heartbeatIntervalSeconds:
// //           this.config.get<number>(
// //             "heartbeat.intervalSeconds",
// //             15,
// //           ),
// //       },
// //     );

// //     void this.presence.broadcastLiveUsers();

// //   } catch (err) {
// //     this.logger.warn(
// //       `WS auth failed: ${
// //         err instanceof Error
// //           ? err.message
// //           : String(err)
// //       }`,
// //     );

// //     this.events.unregister(socket.id);

// //     socket.emit(
// //       "ERROR",
// //       {
// //         code: "UNAUTHORIZED",
// //         message: "Authentication failed",
// //       },
// //     );

// //     socket.disconnect(true);
// //   }
// // }

// //   async handleDisconnect(socket: Socket): Promise<void> {
// //     const { userId } = this.events.unregister(socket.id);
// //     if (!userId) return;

// //     this.logger.log(
// //       `[LIVE] socket disconnected user=${userId} (socket ${socket.id})`,
// //     );

// //     const p = await this.presence.get(userId);
// //     if (!p) return;

// //     // Only treat as offline if this was their registered socket.
// //     if (p.socketId && p.socketId !== socket.id) return;

// //     try {
// //       if (p.status === PresenceStatus.SEARCHING) {
// //         await this.matchmaking.cancelByDisconnect(userId);
// //       } else if (
// //         p.currentCallId &&
// //         (p.status === PresenceStatus.MATCHED ||
// //           p.status === PresenceStatus.CONNECTING ||
// //           p.status === PresenceStatus.IN_CALL)
// //       ) {
// //         await this.calls.handleDisconnect(userId);
// //       } else {
// //         await this.presence.setOffline(userId);
// //       }
// //       // Every branch above updates presence, which broadcasts LIVE_USERS.
// //     } catch (err) {
// //       this.logger.error(
// //         `Disconnect handling failed for ${userId}: ${(err as Error).message}`,
// //       );
// //       await this.presence.setOffline(userId);
// //     }
// //   }

// //   // ============================== Events ==============================

// //   @SubscribeMessage("HEARTBEAT")
// //   async onHeartbeat(socket: Socket): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     await this.presence.heartbeat(userId, socket.id);
// //     socket.emit("HEARTBEAT_ACK", { at: Date.now() });
// //   }

// //   @SubscribeMessage("LIVE_START")
// //   async onLiveStart(socket: Socket): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     try {
// //       const current = await this.presence.get(userId);
// //       const status = current?.status;

// //       if (
// //         status !== PresenceStatus.SEARCHING &&
// //         status !== PresenceStatus.MATCHED &&
// //         status !== PresenceStatus.CONNECTING &&
// //         status !== PresenceStatus.IN_CALL &&
// //         status !== PresenceStatus.ENDING
// //       ) {
// //         // Not in an active flow -> become AVAILABLE.
// //         await this.presence.availability(userId, true, socket.id);
// //       } else {
// //         // Already SEARCHING / MATCHED / IN_CALL: keep that state, just refresh
// //         // heartbeat + socket binding. LIVE_START must not reset matchmaking.
// //         await this.presence.heartbeat(userId, socket.id);
// //       }

// //       this.logger.log(`[LIVE] user started live user=${userId}`);
// //       const refreshed = await this.presence.get(userId);
// //       socket.emit("LIVE_STARTED", {
// //         userId,
// //         status: refreshed?.status ?? PresenceStatus.AVAILABLE,
// //       });
// //     } catch (err) {
// //       this.error(socket, err);
// //     }
// //   }

// //   @SubscribeMessage("LIVE_STOP")
// //   async onLiveStop(socket: Socket): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     try {
// //       const current = await this.presence.get(userId);

// //       if (current?.status === PresenceStatus.SEARCHING) {
// //         // Leaving the live section also abandons any active search.
// //         await this.matchmaking.cancel(userId);
// //       }

// //       await this.presence.setOffline(userId);
// //       this.logger.log(`[LIVE] user stopped live user=${userId}`);
// //       socket.emit("LIVE_STOPPED", { userId, status: PresenceStatus.OFFLINE });
// //     } catch (err) {
// //       this.error(socket, err);
// //     }
// //   }

// //   @SubscribeMessage("START_MATCH")
// //   async onStartMatch(
// //     socket: Socket,
// //     payload: { filters?: Record<string, any> },
// //   ): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     try {
// //       await this.matchmaking.start(userId, payload?.filters ?? {});
// //     } catch (err) {
// //       this.error(socket, err);
// //     }
// //   }

// //   @SubscribeMessage("START_MATCH_CANCEL")
// //   async onCancelMatch(socket: Socket): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     try {
// //       await this.matchmaking.cancel(userId);
// //     } catch (err) {
// //       this.error(socket, err);
// //     }
// //   }

// //   @SubscribeMessage("CALL_OFFER")
// //   async onOffer(
// //     socket: Socket,
// //     payload: { callId: string; data: unknown },
// //   ): Promise<void> {
// //     await this.relaySignaling(socket, payload, "CALL_OFFER");
// //   }

// //   @SubscribeMessage("CALL_ANSWER")
// //   async onAnswer(
// //     socket: Socket,
// //     payload: { callId: string; data: unknown },
// //   ): Promise<void> {
// //     await this.relaySignaling(socket, payload, "CALL_ANSWER");
// //   }

// //   @SubscribeMessage("ICE_CANDIDATE")
// //   async onIceCandidate(
// //     socket: Socket,
// //     payload: { callId: string; data: unknown },
// //   ): Promise<void> {
// //     await this.relaySignaling(socket, payload, "ICE_CANDIDATE");
// //   }

// //   @SubscribeMessage("CALL_CONNECTED")
// //   async onCallConnected(
// //     socket: Socket,
// //     payload: { callId: string },
// //   ): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     try {
// //       const state = await this.calls.verifyParticipant(payload.callId, userId);
// //       await this.calls.confirmConnected(payload.callId);
// //       const peer = state.participants.find((id) => id !== userId);
// //       if (peer) {
// //         await this.events.sendToUser(peer, "CALL_CONNECTED", {
// //           callId: payload.callId,
// //           at: Date.now(),
// //         });
// //       }
// //     } catch (err) {
// //       this.error(socket, err);
// //     }
// //   }

// //   @SubscribeMessage("END_CALL")
// //   async onEndCall(socket: Socket, payload: { callId: string }): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     try {
// //       await this.calls.endCall(payload.callId, userId);
// //     } catch (err) {
// //       this.error(socket, err);
// //     }
// //   }

// //   @SubscribeMessage("CALL_FAILED")
// //   async onCallFailed(
// //     socket: Socket,
// //     payload: { callId: string; reason?: string },
// //   ): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     try {
// //       await this.calls.verifyParticipant(payload.callId, userId);
// //       await this.calls.failCall(
// //         payload.callId,
// //         "SIGNALING_FAILED",
// //         payload.reason ?? "client reported failure",
// //       );
// //     } catch (err) {
// //       this.error(socket, err);
// //     }
// //   }

// //   // ============================== Presence sweep ==============================

// //   // Safety net for crash / force-quit / lost-network: if a live user stops
// //   // heartbeating for heartbeat.timeoutSeconds (default 45s), expire them,
// //   // cancel any active search, and broadcast the updated list.
// //   @Cron(CronExpression.EVERY_10_SECONDS, { name: "presence-sweep" })
// //   async sweepPresence(): Promise<void> {
// //     try {
// //       const timeoutMs =
// //         this.config.get<number>("heartbeat.timeoutSeconds", 45) * 1000;
// //       const liveIds = await this.presence.listLiveUserIds();
// //       const now = Date.now();

// //       const expired: string[] = [];
// //       for (const id of liveIds) {
// //         const p = await this.presence.get(id);
// //         if (!p || now - p.lastHeartbeat > timeoutMs) expired.push(id);
// //       }

// //       if (expired.length === 0) return;

// //       for (const id of expired) {
// //         this.logger.log(`[LIVE] user expired user=${id}`);
// //         const p = await this.presence.get(id);
// //         if (p?.status === PresenceStatus.SEARCHING) {
// //           await this.matchmaking.cancelByDisconnect(id).catch(() => {
// //             /* search already gone */
// //           });
// //         }
// //         await this.presence.setOffline(id);
// //       }
// //     } catch (err) {
// //       this.logger.error(
// //         `[LIVE] presence sweep failed: ${err instanceof Error ? err.message : String(err)}`,
// //       );
// //     }
// //   }

// //   // ============================== Helpers ==============================

// //   private async relaySignaling(
// //     socket: Socket,
// //     payload: { callId: string; data: unknown },
// //     signalType: "CALL_OFFER" | "CALL_ANSWER" | "ICE_CANDIDATE",
// //   ): Promise<void> {
// //     const userId = this.requireUser(socket);
// //     try {
// //       if (!payload?.callId || !payload?.data) {
// //         socket.emit("ERROR", {
// //           code: "INVALID_SIGNAL",
// //           message: "callId and data are required",
// //         });
// //         return;
// //       }
// //       await this.calls.relaySignaling(
// //         payload.callId,
// //         userId,
// //         signalType,
// //         payload.data,
// //       );
// //     } catch (err) {
// //       this.error(socket, err);
// //     }
// //   }

// //   private requireUser(socket: Socket): string {
// //     const userId = this.events.getUserId(socket.id);
// //     if (!userId) {
// //       throw new ApiException("UNAUTHORIZED", "Not authenticated", 401);
// //     }
// //     return userId;
// //   }

// //   private error(socket: Socket, err: unknown): void {
// //     if (err instanceof ApiException) {
// //       socket.emit("ERROR", { code: err.code, message: err.message });
// //       return;
// //     }
// //     this.logger.warn(`WS handler error: ${(err as Error).message}`);
// //     socket.emit("ERROR", {
// //       code: "INTERNAL_ERROR",
// //       message: "Unexpected error",
// //     });
// //   }

// //   private extractToken(socket: Socket): string | null {
// //     const auth = socket.handshake.auth as { token?: string } | undefined;
// //     if (auth?.token) return auth.token;
// //     const header = socket.handshake.headers?.authorization;
// //     if (header && header.startsWith("Bearer ")) return header.slice(7);
// //     return null;
// //   }
// // }



// import { Logger } from "@nestjs/common";
// import {
//   OnGatewayConnection,
//   OnGatewayDisconnect,
//   SubscribeMessage,
//   WebSocketGateway,
//   WebSocketServer,
// } from "@nestjs/websockets";
// import { Socket, Server } from "socket.io";
// import { ConfigService } from "@nestjs/config";
// import {
//   Cron,
//   CronExpression,
// } from "@nestjs/schedule";

// import { TokenService } from "../auth/token.service";
// import {
//   PresenceService,
//   PresenceStatus,
// } from "../presence/presence.service";
// import { RealtimeEventsService } from "./realtime-events.service";
// import { MatchmakingService } from "../matchmaking/matchmaking.service";
// import { CallsService } from "../calls/calls.service";
// import { PrismaService } from "../prisma/prisma.service";
// import { ApiException } from "../common/errors/api.exception";

// @WebSocketGateway({
//   cors: {
//     origin: true,
//     credentials: true,
//   },

//   path: "/realtime",

//   serveClient: false,
// })
// export class RealtimeGateway
//   implements
//     OnGatewayConnection,
//     OnGatewayDisconnect
// {
//   @WebSocketServer()
//   server!: Server;

//   private readonly logger =
//     new Logger(RealtimeGateway.name);

//   /**
//    * Socket IDs that successfully passed JWT + account validation.
//    *
//    * We still register the socket immediately after JWT validation so
//    * very early client events don't race the async DB ban check.
//    */
//   private readonly authenticatedSockets =
//     new Set<string>();

//   constructor(
//     private readonly events: RealtimeEventsService,
//     private readonly tokens: TokenService,
//     private readonly presence: PresenceService,
//     private readonly matchmaking: MatchmakingService,
//     private readonly calls: CallsService,
//     private readonly prisma: PrismaService,
//     private readonly config: ConfigService,
//   ) {}

//   // ============================================================
//   // CONNECTION
//   // ============================================================

//   async handleConnection(
//     socket: Socket,
//   ): Promise<void> {
//     let userId: string | null = null;

//     try {
//       // --------------------------------------------------------
//       // Extract token
//       // --------------------------------------------------------

//       const token =
//         this.extractToken(socket);

//       if (!token) {
//         this.logger.warn(
//           `[WS] missing token socket=${socket.id}`,
//         );

//         socket.emit("ERROR", {
//           code: "UNAUTHORIZED",
//           message: "Missing token",
//         });

//         socket.disconnect(true);

//         return;
//       }

//       // --------------------------------------------------------
//       // Verify JWT
//       // --------------------------------------------------------

//       const payload =
//         this.tokens.verifyAccess(token);

//       if (!payload?.sub) {
//         throw new ApiException(
//           "UNAUTHORIZED",
//           "Invalid token",
//           401,
//         );
//       }

//       userId = payload.sub;

//       // --------------------------------------------------------
//       // IMPORTANT
//       //
//       // Register immediately after JWT verification.
//       //
//       // This fixes:
//       //
//       // socket connected
//       //       ↓
//       // LIVE_START
//       //       ↓
//       // requireUser()
//       //       ↓
//       // user not registered
//       //
//       // The previous implementation waited for the DB query
//       // before registering the socket.
//       // --------------------------------------------------------

//       this.events.register(
//         socket.id,
//         userId,
//         socket,
//       );

//       socket.data.userId =
//         userId;

//       // --------------------------------------------------------
//       // Account validation
//       // --------------------------------------------------------

//       const account =
//         await this.prisma.user.findUnique({
//           where: {
//             id: userId,
//           },

//           select: {
//             id: true,
//             isBanned: true,
//           },
//         });

//       if (!account) {
//         this.logger.warn(
//           `[WS] user not found user=${userId} socket=${socket.id}`,
//         );

//         this.events.unregister(
//           socket.id,
//         );

//         socket.emit("ERROR", {
//           code: "UNAUTHORIZED",
//           message: "Account not found",
//         });

//         socket.disconnect(true);

//         return;
//       }

//       if (account.isBanned) {
//         this.logger.warn(
//           `[WS] banned account user=${userId}`,
//         );

//         this.events.unregister(
//           socket.id,
//         );

//         socket.emit("ERROR", {
//           code: "ACCOUNT_BANNED",
//           message:
//             "Account is suspended",
//         });

//         socket.disconnect(true);

//         return;
//       }

//       // --------------------------------------------------------
//       // Mark socket authenticated
//       // --------------------------------------------------------

//       this.authenticatedSockets.add(
//         socket.id,
//       );

//       socket.data.authenticated =
//         true;

//       // --------------------------------------------------------
//       // Update presence socket binding
//       // --------------------------------------------------------

//       const existing =
//         await this.presence.get(
//           userId,
//         );

//       if (existing) {
//         await this.presence.upsert(
//           userId,
//           {
//             socketId:
//               socket.id,
//           },
//         );

//         this.logger.log(
//           `[WS] presence socket updated ` +
//             `user=${userId} ` +
//             `status=${existing.status} ` +
//             `socket=${socket.id}`,
//         );
//       }

//       // --------------------------------------------------------
//       // Connection successful
//       // --------------------------------------------------------

//       this.logger.log(
//         `[WS] CONNECTED user=${userId} ` +
//           `socket=${socket.id}`,
//       );

//       socket.emit(
//         "CONNECTED",
//         {
//           userId,

//           heartbeatIntervalSeconds:
//             this.config.get<number>(
//               "heartbeat.intervalSeconds",
//               15,
//             ),
//         },
//       );

//       // --------------------------------------------------------
//       // Send current live snapshot
//       // --------------------------------------------------------

//       void this.presence
//         .broadcastLiveUsers()
//         .catch((error) => {
//           this.logger.warn(
//             `[WS] LIVE_USERS broadcast failed ` +
//               `user=${userId} ` +
//               `${this.errorMessage(error)}`,
//           );
//         });

//       // --------------------------------------------------------
//       // Recovery
//       //
//       // If the user reconnects while MATCHED / IN_CALL,
//       // the Flutter side can call getStatus() and recover.
//       // --------------------------------------------------------

//       if (
//         existing?.currentCallId &&
//         (
//           existing.status ===
//             PresenceStatus.MATCHED ||
//           existing.status ===
//             PresenceStatus.CONNECTING ||
//           existing.status ===
//             PresenceStatus.IN_CALL
//         )
//       ) {
//         this.logger.log(
//           `[WS] reconnecting active call ` +
//             `user=${userId} ` +
//             `call=${existing.currentCallId}`,
//         );
//       }
//     } catch (error) {
//       this.logger.warn(
//         `[WS] connection authentication failed ` +
//           `socket=${socket.id} ` +
//           `user=${userId ?? "unknown"} ` +
//           `${this.errorMessage(error)}`,
//       );

//       this.authenticatedSockets.delete(
//         socket.id,
//       );

//       this.events.unregister(
//         socket.id,
//       );

//       if (socket.connected) {
//         socket.emit("ERROR", {
//           code: "UNAUTHORIZED",
//           message:
//             "Authentication failed",
//         });

//         socket.disconnect(true);
//       }
//     }
//   }

//   // ============================================================
//   // DISCONNECT
//   // ============================================================

//   async handleDisconnect(
//     socket: Socket,
//   ): Promise<void> {
//     // ----------------------------------------------------------
//     // Remove authentication marker
//     // ----------------------------------------------------------

//     this.authenticatedSockets.delete(
//       socket.id,
//     );

//     // ----------------------------------------------------------
//     // Remove socket mapping
//     // ----------------------------------------------------------

//     const {
//       userId,
//     } =
//       this.events.unregister(
//         socket.id,
//       );

//     if (!userId) {
//       return;
//     }

//     this.logger.log(
//       `[WS] DISCONNECTED ` +
//         `user=${userId} ` +
//         `socket=${socket.id}`,
//     );

//     // ----------------------------------------------------------
//     // Get current presence
//     // ----------------------------------------------------------

//     const current =
//       await this.presence.get(
//         userId,
//       );

//     if (!current) {
//       return;
//     }

//     // ----------------------------------------------------------
//     // IMPORTANT
//     //
//     // A user may have connected with a NEW socket before the
//     // OLD socket's disconnect callback executes.
//     //
//     // Never change presence for an old socket.
//     // ----------------------------------------------------------

//     if (
//       current.socketId &&
//       current.socketId !== socket.id
//     ) {
//       this.logger.debug(
//         `[WS] ignoring stale disconnect ` +
//           `user=${userId} ` +
//           `oldSocket=${socket.id} ` +
//           `currentSocket=${current.socketId}`,
//       );

//       return;
//     }

//     try {
//       // --------------------------------------------------------
//       // SEARCHING
//       // --------------------------------------------------------

//       if (
//         current.status ===
//         PresenceStatus.SEARCHING
//       ) {
//         this.logger.log(
//           `[WS] cancelling matchmaking ` +
//             `user=${userId}`,
//         );

//         await this.matchmaking
//           .cancelByDisconnect(
//             userId,
//           );

//         return;
//       }

//       // --------------------------------------------------------
//       // ACTIVE CALL
//       // --------------------------------------------------------

//       if (
//         current.currentCallId &&
//         (
//           current.status ===
//             PresenceStatus.MATCHED ||
//           current.status ===
//             PresenceStatus.CONNECTING ||
//           current.status ===
//             PresenceStatus.IN_CALL
//         )
//       ) {
//         this.logger.log(
//           `[WS] call disconnect ` +
//             `user=${userId} ` +
//             `call=${current.currentCallId}`,
//         );

//         await this.calls.handleDisconnect(
//           userId,
//         );

//         return;
//       }

//       // --------------------------------------------------------
//       // NORMAL OFFLINE
//       // --------------------------------------------------------

//       await this.presence.setOffline(
//         userId,
//       );
//     } catch (error) {
//       this.logger.error(
//         `[WS] disconnect handling failed ` +
//           `user=${userId} ` +
//           `${this.errorMessage(error)}`,
//       );

//       try {
//         const latest =
//           await this.presence.get(
//             userId,
//           );

//         // Don't overwrite a newer socket.
//         if (
//           latest?.socketId &&
//           latest.socketId !==
//             socket.id
//         ) {
//           return;
//         }

//         await this.presence.setOffline(
//           userId,
//         );
//       } catch (offlineError) {
//         this.logger.error(
//           `[WS] fallback offline failed ` +
//             `user=${userId} ` +
//             `${this.errorMessage(offlineError)}`,
//         );
//       }
//     }
//   }

//   // ============================================================
//   // HEARTBEAT
//   // ============================================================

//   @SubscribeMessage("HEARTBEAT")
//   async onHeartbeat(
//     socket: Socket,
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       await this.presence.heartbeat(
//         userId,
//         socket.id,
//       );

//       socket.emit(
//         "HEARTBEAT_ACK",
//         {
//           at: Date.now(),
//         },
//       );
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // LIVE START
//   // ============================================================

//   @SubscribeMessage("LIVE_START")
//   async onLiveStart(
//     socket: Socket,
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       const current =
//         await this.presence.get(
//           userId,
//         );

//       const status =
//         current?.status;

//       // --------------------------------------------------------
//       // If user is already in an active flow, DON'T reset it.
//       // --------------------------------------------------------

//       if (
//         status ===
//           PresenceStatus.SEARCHING ||
//         status ===
//           PresenceStatus.MATCHED ||
//         status ===
//           PresenceStatus.CONNECTING ||
//         status ===
//           PresenceStatus.IN_CALL ||
//         status ===
//           PresenceStatus.ENDING
//       ) {
//         await this.presence.heartbeat(
//           userId,
//           socket.id,
//         );

//         this.logger.log(
//           `[LIVE] preserving active state ` +
//             `user=${userId} ` +
//             `status=${status}`,
//         );
//       } else {
//         // ------------------------------------------------------
//         // OFFLINE / AVAILABLE
//         // -> AVAILABLE
//         // ------------------------------------------------------

//         await this.presence.availability(
//           userId,
//           true,
//           socket.id,
//         );

//         this.logger.log(
//           `[LIVE] user became AVAILABLE ` +
//             `user=${userId}`,
//         );
//       }

//       const refreshed =
//         await this.presence.get(
//           userId,
//         );

//       socket.emit(
//         "LIVE_STARTED",
//         {
//           userId,

//           status:
//             refreshed?.status ??
//             PresenceStatus.AVAILABLE,
//         },
//       );
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // LIVE STOP
//   // ============================================================

//   @SubscribeMessage("LIVE_STOP")
//   async onLiveStop(
//     socket: Socket,
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       const current =
//         await this.presence.get(
//           userId,
//         );

//       // --------------------------------------------------------
//       // Cancel matchmaking first.
//       // --------------------------------------------------------

//       if (
//         current?.status ===
//         PresenceStatus.SEARCHING
//       ) {
//         await this.matchmaking.cancel(
//           userId,
//         );
//       }

//       // --------------------------------------------------------
//       // Then offline
//       // --------------------------------------------------------

//       await this.presence.setOffline(
//         userId,
//       );

//       this.logger.log(
//         `[LIVE] user stopped live ` +
//           `user=${userId}`,
//       );

//       socket.emit(
//         "LIVE_STOPPED",
//         {
//           userId,

//           status:
//             PresenceStatus.OFFLINE,
//         },
//       );
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // START MATCH
//   // ============================================================

//   @SubscribeMessage("START_MATCH")
//   async onStartMatch(
//     socket: Socket,
//     payload?: {
//       filters?: Record<
//         string,
//         any
//       >;
//     },
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       await this.matchmaking.start(
//         userId,
//         payload?.filters ?? {},
//       );

//       this.logger.log(
//         `[MATCH] START_MATCH received ` +
//           `user=${userId}`,
//       );
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // CANCEL MATCH
//   // ============================================================

//   @SubscribeMessage("START_MATCH_CANCEL")
//   async onCancelMatch(
//     socket: Socket,
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       await this.matchmaking.cancel(
//         userId,
//       );
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // CALL OFFER
//   // ============================================================

//   @SubscribeMessage("CALL_OFFER")
//   async onOffer(
//     socket: Socket,
//     payload: {
//       callId: string;
//       data: unknown;
//     },
//   ): Promise<void> {
//     await this.relaySignaling(
//       socket,
//       payload,
//       "CALL_OFFER",
//     );
//   }

//   // ============================================================
//   // CALL ANSWER
//   // ============================================================

//   @SubscribeMessage("CALL_ANSWER")
//   async onAnswer(
//     socket: Socket,
//     payload: {
//       callId: string;
//       data: unknown;
//     },
//   ): Promise<void> {
//     await this.relaySignaling(
//       socket,
//       payload,
//       "CALL_ANSWER",
//     );
//   }

//   // ============================================================
//   // ICE CANDIDATE
//   // ============================================================

//   @SubscribeMessage("ICE_CANDIDATE")
//   async onIceCandidate(
//     socket: Socket,
//     payload: {
//       callId: string;
//       data: unknown;
//     },
//   ): Promise<void> {
//     await this.relaySignaling(
//       socket,
//       payload,
//       "ICE_CANDIDATE",
//     );
//   }

//   // ============================================================
//   // CALL CONNECTED
//   // ============================================================

//   @SubscribeMessage("CALL_CONNECTED")
//   async onCallConnected(
//     socket: Socket,
//     payload: {
//       callId: string;
//     },
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       if (!payload?.callId) {
//         throw new ApiException(
//           "INVALID_CALL",
//           "callId is required",
//           400,
//         );
//       }

//       const state =
//         await this.calls.verifyParticipant(
//           payload.callId,
//           userId,
//         );

//       await this.calls.confirmConnected(
//         payload.callId,
//       );

//       const peer =
//         state.participants.find(
//           (id) => id !== userId,
//         );

//       if (peer) {
//         await this.events.sendToUser(
//           peer,
//           "CALL_CONNECTED",
//           {
//             callId:
//               payload.callId,

//             at:
//               Date.now(),
//           },
//         );
//       }
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // END CALL
//   // ============================================================

//   @SubscribeMessage("END_CALL")
//   async onEndCall(
//     socket: Socket,
//     payload: {
//       callId: string;
//     },
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       if (!payload?.callId) {
//         throw new ApiException(
//           "INVALID_CALL",
//           "callId is required",
//           400,
//         );
//       }

//       await this.calls.endCall(
//         payload.callId,
//         userId,
//       );
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // CALL FAILED
//   // ============================================================

//   @SubscribeMessage("CALL_FAILED")
//   async onCallFailed(
//     socket: Socket,
//     payload: {
//       callId: string;
//       reason?: string;
//     },
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       if (!payload?.callId) {
//         throw new ApiException(
//           "INVALID_CALL",
//           "callId is required",
//           400,
//         );
//       }

//       await this.calls.verifyParticipant(
//         payload.callId,
//         userId,
//       );

//       await this.calls.failCall(
//         payload.callId,
//         "SIGNALING_FAILED",
//         payload.reason ??
//           "client reported failure",
//       );
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // PRESENCE SWEEP
//   // ============================================================

//   @Cron(
//     CronExpression.EVERY_10_SECONDS,
//     {
//       name: "presence-sweep",
//     },
//   )
//   async sweepPresence(): Promise<void> {
//     try {
//       const timeoutMs =
//         this.config.get<number>(
//           "heartbeat.timeoutSeconds",
//           45,
//         ) * 1000;

//       const liveIds =
//         await this.presence.listLiveUserIds();

//       if (!liveIds.length) {
//         return;
//       }

//       const now =
//         Date.now();

//       const expired: string[] = [];

//       // --------------------------------------------------------
//       // Find expired users
//       // --------------------------------------------------------

//       for (const userId of liveIds) {
//         const p =
//           await this.presence.get(
//             userId,
//           );

//         if (!p) {
//           expired.push(
//             userId,
//           );
//           continue;
//         }

//         if (
//           now -
//             p.lastHeartbeat >
//           timeoutMs
//         ) {
//           expired.push(
//             userId,
//           );
//         }
//       }

//       if (!expired.length) {
//         return;
//       }

//       // --------------------------------------------------------
//       // Expire users
//       // --------------------------------------------------------

//       for (const userId of expired) {
//         this.logger.log(
//           `[LIVE] PRESENCE_EXPIRED ` +
//             `user=${userId}`,
//         );

//         const p =
//           await this.presence.get(
//             userId,
//           );

//         if (
//           p?.status ===
//           PresenceStatus.SEARCHING
//         ) {
//           await this.matchmaking
//             .cancelByDisconnect(
//               userId,
//             )
//             .catch((error) => {
//               this.logger.warn(
//                 `[LIVE] expired search cleanup failed ` +
//                   `user=${userId} ` +
//                   `${this.errorMessage(error)}`,
//               );
//             });

//           continue;
//         }

//         // ------------------------------------------------------
//         // Active call
//         // ------------------------------------------------------

//         if (
//           p?.currentCallId &&
//           (
//             p.status ===
//               PresenceStatus.MATCHED ||
//             p.status ===
//               PresenceStatus.CONNECTING ||
//             p.status ===
//               PresenceStatus.IN_CALL
//           )
//         ) {
//           await this.calls
//             .handleDisconnect(
//               userId,
//             )
//             .catch((error) => {
//               this.logger.warn(
//                 `[LIVE] expired call cleanup failed ` +
//                   `user=${userId} ` +
//                   `${this.errorMessage(error)}`,
//               );
//             });

//           continue;
//         }

//         await this.presence.setOffline(
//           userId,
//         );
//       }
//     } catch (error) {
//       this.logger.error(
//         `[LIVE] presence sweep failed ` +
//           `${this.errorMessage(error)}`,
//       );
//     }
//   }

//   // ============================================================
//   // SIGNALING RELAY
//   // ============================================================

//   private async relaySignaling(
//     socket: Socket,
//     payload: {
//       callId: string;
//       data: unknown;
//     },
//     signalType:
//       | "CALL_OFFER"
//       | "CALL_ANSWER"
//       | "ICE_CANDIDATE",
//   ): Promise<void> {
//     try {
//       const userId =
//         this.requireUser(socket);

//       if (!payload?.callId) {
//         throw new ApiException(
//           "INVALID_SIGNAL",
//           "callId is required",
//           400,
//         );
//       }

//       if (
//         payload.data ===
//         undefined ||
//         payload.data ===
//         null
//       ) {
//         throw new ApiException(
//           "INVALID_SIGNAL",
//           "Signal data is required",
//           400,
//         );
//       }

//       await this.calls.relaySignaling(
//         payload.callId,
//         userId,
//         signalType,
//         payload.data,
//       );
//     } catch (error) {
//       this.error(
//         socket,
//         error,
//       );
//     }
//   }

//   // ============================================================
//   // REQUIRE USER
//   // ============================================================

//   private requireUser(
//     socket: Socket,
//   ): string {
//     // ----------------------------------------------------------
//     // First check that this socket passed connection validation.
//     // ----------------------------------------------------------

//     const authenticated =
//       this.authenticatedSockets.has(
//         socket.id,
//       );

//     if (!authenticated) {
//       throw new ApiException(
//         "UNAUTHORIZED",
//         "Not authenticated",
//         401,
//       );
//     }

//     // ----------------------------------------------------------
//     // Then get user from realtime registry.
//     // ----------------------------------------------------------

//     const userId =
//       this.events.getUserId(
//         socket.id,
//       );

//     if (!userId) {
//       throw new ApiException(
//         "UNAUTHORIZED",
//         "Not authenticated",
//         401,
//       );
//     }

//     return userId;
//   }

//   // ============================================================
//   // ERROR
//   // ============================================================

//   private error(
//     socket: Socket,
//     error: unknown,
//   ): void {
//     if (
//       error instanceof
//       ApiException
//     ) {
//       socket.emit(
//         "ERROR",
//         {
//           code:
//             error.code,

//           message:
//             error.message,
//         },
//       );

//       return;
//     }

//     this.logger.warn(
//       `[WS] handler error ` +
//         `${this.errorMessage(error)}`,
//     );

//     socket.emit(
//       "ERROR",
//       {
//         code:
//           "INTERNAL_ERROR",

//         message:
//           "Unexpected error",
//       },
//     );
//   }

//   // ============================================================
//   // TOKEN EXTRACTION
//   // ============================================================

//   private extractToken(
//     socket: Socket,
//   ): string | null {
//     // ----------------------------------------------------------
//     // Socket.IO auth
//     // ----------------------------------------------------------

//     const auth =
//       socket.handshake
//         .auth as
//         | {
//             token?: string;
//           }
//         | undefined;

//     if (auth?.token) {
//       return auth.token;
//     }

//     // ----------------------------------------------------------
//     // Authorization header
//     // ----------------------------------------------------------

//     const header =
//       socket.handshake
//         .headers?.authorization;

//     if (
//       header &&
//       header.startsWith(
//         "Bearer ",
//       )
//     ) {
//       return header.slice(
//         7,
//       );
//     }

//     return null;
//   }

//   // ============================================================
//   // ERROR MESSAGE
//   // ============================================================

//   private errorMessage(
//     error: unknown,
//   ): string {
//     if (
//       error instanceof Error
//     ) {
//       return (
//         error.stack ??
//         error.message
//       );
//     }

//     return String(error);
//   }
// }

// import { Logger } from "@nestjs/common";
// import {
//   OnGatewayConnection,
//   OnGatewayDisconnect,
//   SubscribeMessage,
//   WebSocketGateway,
//   WebSocketServer,
// } from "@nestjs/websockets";
// import { Socket, Server } from "socket.io";
// import { ConfigService } from "@nestjs/config";
// import { Cron, CronExpression } from "@nestjs/schedule";
// import { TokenService } from "../auth/token.service";
// import { PresenceService, PresenceStatus } from "../presence/presence.service";
// import { RealtimeEventsService } from "./realtime-events.service";
// import { MatchmakingService } from "../matchmaking/matchmaking.service";
// import { CallsService } from "../calls/calls.service";
// import { PrismaService } from "../prisma/prisma.service";
// import { ApiException } from "../common/errors/api.exception";

// @WebSocketGateway({
//   cors: { origin: true, credentials: true },
//   path: "/realtime",
//   serveClient: false,
// })
// export class RealtimeGateway
//   implements OnGatewayConnection, OnGatewayDisconnect
// {
//   @WebSocketServer()
//   server!: Server;

//   private readonly logger = new Logger(RealtimeGateway.name);

//   constructor(
//     private readonly events: RealtimeEventsService,
//     private readonly tokens: TokenService,
//     private readonly presence: PresenceService,
//     private readonly matchmaking: MatchmakingService,
//     private readonly calls: CallsService,
//     private readonly prisma: PrismaService,
//     private readonly config: ConfigService,
//   ) {}

//   // async handleConnection(socket: Socket): Promise<void> {
//   //   try {
//   //     const token = this.extractToken(socket);
//   //     if (!token) {
//   //       socket.emit("ERROR", {
//   //         code: "UNAUTHORIZED",
//   //         message: "Missing token",
//   //       });
//   //       socket.disconnect(true);
//   //       return;
//   //     }
//   //     const payload = this.tokens.verifyAccess(token);
//   //     if (!payload?.sub)
//   //       throw new ApiException("UNAUTHORIZED", "Invalid token", 401);

//   //     const ban = await this.prisma.user.findUnique({
//   //       where: { id: payload.sub },
//   //       select: { isBanned: true },
//   //     });
//   //     if (!ban || ban.isBanned) {
//   //       socket.emit("ERROR", {
//   //         code: "ACCOUNT_BANNED",
//   //         message: "Account is suspended",
//   //       });
//   //       socket.disconnect(true);
//   //       return;
//   //     }

//   //     this.logger.log(
//   //       `[LIVE] socket connected user=${payload.sub} (socket ${socket.id})`,
//   //     );
//   //     this.events.register(socket.id, payload.sub, socket);

//   //     const existing = await this.presence.get(payload.sub);
//   //     if (existing) {
//   //       await this.presence.upsert(payload.sub, { socketId: socket.id });
//   //     }

//   //     socket.emit("CONNECTED", {
//   //       userId: payload.sub,
//   //       heartbeatIntervalSeconds: this.config.get<number>(
//   //         "heartbeat.intervalSeconds",
//   //         15,
//   //       ),
//   //     });
//   //     // Send the current snapshot to every client (including the new socket)
//   //     // so reconnects recover the live presence without polling.
//   //     void this.presence.broadcastLiveUsers();
//   //   } catch (err) {
//   //     this.logger.warn(`WS auth failed: ${(err as Error).message}`);
//   //     socket.emit("ERROR", {
//   //       code: "UNAUTHORIZED",
//   //       message: "Authentication failed",
//   //     });
//   //     socket.disconnect(true);
//   //   }
//   // }

//   async handleConnection(socket: Socket): Promise<void> {
//   try {
//     const token = this.extractToken(socket);

//     if (!token) {
//       socket.emit("ERROR", {
//         code: "UNAUTHORIZED",
//         message: "Missing token",
//       });

//       socket.disconnect(true);
//       return;
//     }

//     const payload = this.tokens.verifyAccess(token);

//     if (!payload?.sub) {
//       throw new ApiException(
//         "UNAUTHORIZED",
//         "Invalid token",
//         401,
//       );
//     }

//     const userId = payload.sub;

//     // IMPORTANT:
//     // Register immediately after JWT validation.
//     //
//     // This prevents:
//     //
//     // socket connected
//     //       ↓
//     // LIVE_START
//     //       ↓
//     // requireUser()
//     //       ↓
//     // user not registered yet
//     //
//     this.events.register(
//       socket.id,
//       userId,
//       socket,
//     );

//     // Now perform slower DB validation.
//     const ban = await this.prisma.user.findUnique({
//       where: {
//         id: userId,
//       },
//       select: {
//         isBanned: true,
//       },
//     });

//     if (!ban || ban.isBanned) {
//       this.events.unregister(socket.id);

//       socket.emit("ERROR", {
//         code: "ACCOUNT_BANNED",
//         message: "Account is suspended",
//       });

//       socket.disconnect(true);

//       return;
//     }

//     this.logger.log(
//       `[LIVE] socket connected user=${userId} socket=${socket.id}`,
//     );

//     const existing = await this.presence.get(userId);

//     if (existing) {
//       await this.presence.upsert(
//         userId,
//         {
//           socketId: socket.id,
//         },
//       );
//     }

//     socket.emit(
//       "CONNECTED",
//       {
//         userId,
//         heartbeatIntervalSeconds:
//           this.config.get<number>(
//             "heartbeat.intervalSeconds",
//             15,
//           ),
//       },
//     );

//     void this.presence.broadcastLiveUsers();

//   } catch (err) {
//     this.logger.warn(
//       `WS auth failed: ${
//         err instanceof Error
//           ? err.message
//           : String(err)
//       }`,
//     );

//     this.events.unregister(socket.id);

//     socket.emit(
//       "ERROR",
//       {
//         code: "UNAUTHORIZED",
//         message: "Authentication failed",
//       },
//     );

//     socket.disconnect(true);
//   }
// }

//   async handleDisconnect(socket: Socket): Promise<void> {
//     const { userId } = this.events.unregister(socket.id);
//     if (!userId) return;

//     this.logger.log(
//       `[LIVE] socket disconnected user=${userId} (socket ${socket.id})`,
//     );

//     const p = await this.presence.get(userId);
//     if (!p) return;

//     // Only treat as offline if this was their registered socket.
//     if (p.socketId && p.socketId !== socket.id) return;

//     try {
//       if (p.status === PresenceStatus.SEARCHING) {
//         await this.matchmaking.cancelByDisconnect(userId);
//       } else if (
//         p.currentCallId &&
//         (p.status === PresenceStatus.MATCHED ||
//           p.status === PresenceStatus.CONNECTING ||
//           p.status === PresenceStatus.IN_CALL)
//       ) {
//         await this.calls.handleDisconnect(userId);
//       } else {
//         await this.presence.setOffline(userId);
//       }
//       // Every branch above updates presence, which broadcasts LIVE_USERS.
//     } catch (err) {
//       this.logger.error(
//         `Disconnect handling failed for ${userId}: ${(err as Error).message}`,
//       );
//       await this.presence.setOffline(userId);
//     }
//   }

//   // ============================== Events ==============================

//   @SubscribeMessage("HEARTBEAT")
//   async onHeartbeat(socket: Socket): Promise<void> {
//     const userId = this.requireUser(socket);
//     await this.presence.heartbeat(userId, socket.id);
//     socket.emit("HEARTBEAT_ACK", { at: Date.now() });
//   }

//   @SubscribeMessage("LIVE_START")
//   async onLiveStart(socket: Socket): Promise<void> {
//     const userId = this.requireUser(socket);
//     try {
//       const current = await this.presence.get(userId);
//       const status = current?.status;

//       if (
//         status !== PresenceStatus.SEARCHING &&
//         status !== PresenceStatus.MATCHED &&
//         status !== PresenceStatus.CONNECTING &&
//         status !== PresenceStatus.IN_CALL &&
//         status !== PresenceStatus.ENDING
//       ) {
//         // Not in an active flow -> become AVAILABLE.
//         await this.presence.availability(userId, true, socket.id);
//       } else {
//         // Already SEARCHING / MATCHED / IN_CALL: keep that state, just refresh
//         // heartbeat + socket binding. LIVE_START must not reset matchmaking.
//         await this.presence.heartbeat(userId, socket.id);
//       }

//       this.logger.log(`[LIVE] user started live user=${userId}`);
//       const refreshed = await this.presence.get(userId);
//       socket.emit("LIVE_STARTED", {
//         userId,
//         status: refreshed?.status ?? PresenceStatus.AVAILABLE,
//       });
//     } catch (err) {
//       this.error(socket, err);
//     }
//   }

//   @SubscribeMessage("LIVE_STOP")
//   async onLiveStop(socket: Socket): Promise<void> {
//     const userId = this.requireUser(socket);
//     try {
//       const current = await this.presence.get(userId);

//       if (current?.status === PresenceStatus.SEARCHING) {
//         // Leaving the live section also abandons any active search.
//         await this.matchmaking.cancel(userId);
//       }

//       await this.presence.setOffline(userId);
//       this.logger.log(`[LIVE] user stopped live user=${userId}`);
//       socket.emit("LIVE_STOPPED", { userId, status: PresenceStatus.OFFLINE });
//     } catch (err) {
//       this.error(socket, err);
//     }
//   }

//   @SubscribeMessage("START_MATCH")
//   async onStartMatch(
//     socket: Socket,
//     payload: { filters?: Record<string, any> },
//   ): Promise<void> {
//     const userId = this.requireUser(socket);
//     try {
//       await this.matchmaking.start(userId, payload?.filters ?? {});
//     } catch (err) {
//       this.error(socket, err);
//     }
//   }

//   @SubscribeMessage("START_MATCH_CANCEL")
//   async onCancelMatch(socket: Socket): Promise<void> {
//     const userId = this.requireUser(socket);
//     try {
//       await this.matchmaking.cancel(userId);
//     } catch (err) {
//       this.error(socket, err);
//     }
//   }

//   @SubscribeMessage("CALL_OFFER")
//   async onOffer(
//     socket: Socket,
//     payload: { callId: string; data: unknown },
//   ): Promise<void> {
//     await this.relaySignaling(socket, payload, "CALL_OFFER");
//   }

//   @SubscribeMessage("CALL_ANSWER")
//   async onAnswer(
//     socket: Socket,
//     payload: { callId: string; data: unknown },
//   ): Promise<void> {
//     await this.relaySignaling(socket, payload, "CALL_ANSWER");
//   }

//   @SubscribeMessage("ICE_CANDIDATE")
//   async onIceCandidate(
//     socket: Socket,
//     payload: { callId: string; data: unknown },
//   ): Promise<void> {
//     await this.relaySignaling(socket, payload, "ICE_CANDIDATE");
//   }

//   @SubscribeMessage("CALL_CONNECTED")
//   async onCallConnected(
//     socket: Socket,
//     payload: { callId: string },
//   ): Promise<void> {
//     const userId = this.requireUser(socket);
//     try {
//       const state = await this.calls.verifyParticipant(payload.callId, userId);
//       await this.calls.confirmConnected(payload.callId);
//       const peer = state.participants.find((id) => id !== userId);
//       if (peer) {
//         await this.events.sendToUser(peer, "CALL_CONNECTED", {
//           callId: payload.callId,
//           at: Date.now(),
//         });
//       }
//     } catch (err) {
//       this.error(socket, err);
//     }
//   }

//   @SubscribeMessage("END_CALL")
//   async onEndCall(socket: Socket, payload: { callId: string }): Promise<void> {
//     const userId = this.requireUser(socket);
//     try {
//       await this.calls.endCall(payload.callId, userId);
//     } catch (err) {
//       this.error(socket, err);
//     }
//   }

//   @SubscribeMessage("CALL_FAILED")
//   async onCallFailed(
//     socket: Socket,
//     payload: { callId: string; reason?: string },
//   ): Promise<void> {
//     const userId = this.requireUser(socket);
//     try {
//       await this.calls.verifyParticipant(payload.callId, userId);
//       await this.calls.failCall(
//         payload.callId,
//         "SIGNALING_FAILED",
//         payload.reason ?? "client reported failure",
//       );
//     } catch (err) {
//       this.error(socket, err);
//     }
//   }

//   // ============================== Presence sweep ==============================

//   // Safety net for crash / force-quit / lost-network: if a live user stops
//   // heartbeating for heartbeat.timeoutSeconds (default 45s), expire them,
//   // cancel any active search, and broadcast the updated list.
//   @Cron(CronExpression.EVERY_10_SECONDS, { name: "presence-sweep" })
//   async sweepPresence(): Promise<void> {
//     try {
//       const timeoutMs =
//         this.config.get<number>("heartbeat.timeoutSeconds", 45) * 1000;
//       const liveIds = await this.presence.listLiveUserIds();
//       const now = Date.now();

//       const expired: string[] = [];
//       for (const id of liveIds) {
//         const p = await this.presence.get(id);
//         if (!p || now - p.lastHeartbeat > timeoutMs) expired.push(id);
//       }

//       if (expired.length === 0) return;

//       for (const id of expired) {
//         this.logger.log(`[LIVE] user expired user=${id}`);
//         const p = await this.presence.get(id);
//         if (p?.status === PresenceStatus.SEARCHING) {
//           await this.matchmaking.cancelByDisconnect(id).catch(() => {
//             /* search already gone */
//           });
//         }
//         await this.presence.setOffline(id);
//       }
//     } catch (err) {
//       this.logger.error(
//         `[LIVE] presence sweep failed: ${err instanceof Error ? err.message : String(err)}`,
//       );
//     }
//   }

//   // ============================== Helpers ==============================

//   private async relaySignaling(
//     socket: Socket,
//     payload: { callId: string; data: unknown },
//     signalType: "CALL_OFFER" | "CALL_ANSWER" | "ICE_CANDIDATE",
//   ): Promise<void> {
//     const userId = this.requireUser(socket);
//     try {
//       if (!payload?.callId || !payload?.data) {
//         socket.emit("ERROR", {
//           code: "INVALID_SIGNAL",
//           message: "callId and data are required",
//         });
//         return;
//       }
//       await this.calls.relaySignaling(
//         payload.callId,
//         userId,
//         signalType,
//         payload.data,
//       );
//     } catch (err) {
//       this.error(socket, err);
//     }
//   }

//   private requireUser(socket: Socket): string {
//     const userId = this.events.getUserId(socket.id);
//     if (!userId) {
//       throw new ApiException("UNAUTHORIZED", "Not authenticated", 401);
//     }
//     return userId;
//   }

//   private error(socket: Socket, err: unknown): void {
//     if (err instanceof ApiException) {
//       socket.emit("ERROR", { code: err.code, message: err.message });
//       return;
//     }
//     this.logger.warn(`WS handler error: ${(err as Error).message}`);
//     socket.emit("ERROR", {
//       code: "INTERNAL_ERROR",
//       message: "Unexpected error",
//     });
//   }

//   private extractToken(socket: Socket): string | null {
//     const auth = socket.handshake.auth as { token?: string } | undefined;
//     if (auth?.token) return auth.token;
//     const header = socket.handshake.headers?.authorization;
//     if (header && header.startsWith("Bearer ")) return header.slice(7);
//     return null;
//   }
// }



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
    OnGatewayDisconnect
{
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
  ) {}

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

          heartbeatIntervalSeconds:
            this.config.get<number>(
              "heartbeat.intervalSeconds",
              15,
            ),
        },
      );

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