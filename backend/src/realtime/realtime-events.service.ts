// import { Injectable, Logger } from "@nestjs/common";
// import { Socket } from "socket.io";

// /**
//  * In-process socket registry + fan-out broker.
//  *
//  * The WebSocket gateway owns the raw Socket objects. Every other service
//  * (matchmaking, calls, presence) talks to RealtimeEventsService, never to
//  * the gateway, which keeps module dependencies acyclic.
//  */
// @Injectable()
// export class RealtimeEventsService {
//   private readonly logger = new Logger(RealtimeEventsService.name);
//   private readonly socketToUser = new Map<string, string>();
//   private readonly userToSocket = new Map<string, Socket>();

//   register(socketId: string, userId: string, socket: Socket): void {
//     this.socketToUser.set(socketId, userId);
//     const previous = this.userToSocket.get(userId);
//     if (previous && previous.id !== socketId) {
//       this.logger.warn(
//         `Multiple sockets for user ${userId}; evicting ${previous.id}`,
//       );
//       previous.emit("ERROR", {
//         code: "MULTIPLE_DEVICE",
//         message: "Session replaced on another device",
//       });
//       previous.disconnect(true);
//     }
//     this.userToSocket.set(userId, socket);
//   }

//   unregister(socketId: string): { userId: string | null } {
//     const userId = this.socketToUser.get(socketId) ?? null;
//     if (userId && this.userToSocket.get(userId)?.id === socketId) {
//       this.userToSocket.delete(userId);
//     }
//     this.socketToUser.delete(socketId);
//     return { userId };
//   }

//   getSocket(userId: string): Socket | undefined {
//     return this.userToSocket.get(userId);
//   }

//   getUserId(socketId: string): string | null {
//     return this.socketToUser.get(socketId) ?? null;
//   }

//   isConnected(userId: string): boolean {
//     return this.userToSocket.has(userId);
//   }

//   async sendToUser(
//     userId: string,
//     event: string,
//     payload: Record<string, unknown>,
//   ): Promise<boolean> {
//     const socket = this.userToSocket.get(userId);
//     if (!socket || !socket.connected) return false;
//     socket.emit(event, payload);
//     return true;
//   }

//   async sendToCall(
//     callId: string,
//     participants: string[],
//     event: string,
//     payload: Record<string, unknown>,
//   ): Promise<void> {
//     await Promise.all(
//       participants.map((uid) =>
//         this.sendToUser(uid, event, { ...payload, callId }),
//       ),
//     );
//   }

//   async broadcastLiveCount(count: number): Promise<void> {
//     for (const [, socket] of this.userToSocket) {
//       if (socket.connected) {
//         socket.emit("LIVE_COUNT_UPDATED", { count });
//       }
//     }
//   }

//   /**
//    * Broadcast the full live-presence snapshot to every connected and
//    * authenticated socket.
//    *
//    * `count` is the TOTAL number of live users (the client subtracts itself
//    * when it knows it is one of them). `users` only contains safe public
//    * profile fields — never credentials or private account data.
//    */
//   async broadcastLiveUsers(count: number, users: unknown[]): Promise<void> {
//     const payload = { count, users };
//     for (const [, socket] of this.userToSocket) {
//       if (socket.connected) {
//         socket.emit("LIVE_USERS", payload);
//         socket.emit("LIVE_COUNT_UPDATED", { count });
//       }
//     }
//   }

//   connectedUserCount(): number {
//     return this.userToSocket.size;
//   }
// }


import { Injectable, Logger } from "@nestjs/common";
import { Socket } from "socket.io";

/**
 * In-process socket registry + fan-out broker.
 *
 * The WebSocket gateway owns the raw Socket objects.
 * Other services communicate through this service instead of directly
 * depending on the gateway.
 *
 * IMPORTANT:
 * This registry is process-local.
 * If you run multiple NestJS instances, use a Socket.IO adapter /
 * Redis adapter and a distributed event mechanism.
 */
@Injectable()
export class RealtimeEventsService {
  private readonly logger = new Logger(RealtimeEventsService.name);

  /**
   * socketId -> userId
   */
  private readonly socketToUser = new Map<string, string>();

  /**
   * userId -> current socket
   *
   * We intentionally keep only ONE active socket per user.
   */
  private readonly userToSocket = new Map<string, Socket>();

  /**
   * Register an authenticated socket for a user.
   *
   * If the user already has another socket connected, the previous
   * socket is evicted.
   */
  register(
    socketId: string,
    userId: string,
    socket: Socket,
  ): void {
    // Remove any stale mapping for this socket first.
    const previousUserId = this.socketToUser.get(socketId);

    if (
      previousUserId &&
      previousUserId !== userId
    ) {
      const previousSocket =
        this.userToSocket.get(previousUserId);

      if (
        previousSocket &&
        previousSocket.id === socketId
      ) {
        this.userToSocket.delete(previousUserId);
      }
    }

    this.socketToUser.set(socketId, userId);

    const previousSocket =
      this.userToSocket.get(userId);

    /**
     * Same socket registering again.
     */
    if (
      previousSocket &&
      previousSocket.id === socketId
    ) {
      this.userToSocket.set(userId, socket);
      return;
    }

    /**
     * Another device/socket already belongs to this user.
     */
    if (
      previousSocket &&
      previousSocket.id !== socketId
    ) {
      this.logger.warn(
        `Multiple sockets for user ${userId}; ` +
          `evicting ${previousSocket.id} in favor of ${socketId}`,
      );

      try {
        previousSocket.emit("ERROR", {
          code: "MULTIPLE_DEVICE",
          message: "Session replaced on another device",
        });
      } catch (err) {
        this.logger.debug(
          `Failed to notify previous socket ${previousSocket.id}: ${
            err instanceof Error ? err.message : String(err)
          }`,
        );
      }

      try {
        previousSocket.disconnect(true);
      } catch (err) {
        this.logger.debug(
          `Failed to disconnect previous socket ${previousSocket.id}: ${
            err instanceof Error ? err.message : String(err)
          }`,
        );
      }
    }

    this.userToSocket.set(userId, socket);

    this.logger.log(
      `Socket registered user=${userId} socket=${socketId}`,
    );
  }

  /**
   * Remove a socket.
   *
   * IMPORTANT:
   * We only delete userToSocket if that socket is still the
   * current socket for that user.
   *
   * This protects against:
   *
   * old socket disconnect
   *        ↓
   * new socket already connected
   *        ↓
   * old socket must NOT remove new socket mapping
   */
  unregister(
    socketId: string,
  ): { userId: string | null } {
    const userId =
      this.socketToUser.get(socketId) ?? null;

    if (!userId) {
      return {
        userId: null,
      };
    }

    const currentSocket =
      this.userToSocket.get(userId);

    if (
      currentSocket &&
      currentSocket.id === socketId
    ) {
      this.userToSocket.delete(userId);

      this.logger.log(
        `Current socket unregistered user=${userId} socket=${socketId}`,
      );
    } else {
      this.logger.debug(
        `Ignoring stale socket unregister user=${userId} socket=${socketId}`,
      );
    }

    this.socketToUser.delete(socketId);

    return {
      userId,
    };
  }

  /**
   * Check whether a particular socket is currently the active
   * socket for a user.
   */
  isCurrentSocket(
    userId: string,
    socketId: string,
  ): boolean {
    return (
      this.userToSocket.get(userId)?.id === socketId
    );
  }

  /**
   * Get the active socket for a user.
   */
  getSocket(
    userId: string,
  ): Socket | undefined {
    const socket =
      this.userToSocket.get(userId);

    if (!socket) {
      return undefined;
    }

    if (!socket.connected) {
      return undefined;
    }

    return socket;
  }

  /**
   * Get the user associated with a socket.
   */
  getUserId(
    socketId: string,
  ): string | null {
    return (
      this.socketToUser.get(socketId) ?? null
    );
  }

  /**
   * Check whether a user currently has a connected socket.
   */
  isConnected(
    userId: string,
  ): boolean {
    const socket =
      this.userToSocket.get(userId);

    return Boolean(
      socket &&
        socket.connected,
    );
  }

  /**
   * Send an event to one user.
   */
  async sendToUser(
    userId: string,
    event: string,
    payload: Record<string, unknown>,
  ): Promise<boolean> {
    const socket =
      this.getSocket(userId);

    if (!socket) {
      this.logger.debug(
        `sendToUser skipped: user=${userId} not connected`,
      );

      return false;
    }

    try {
      socket.emit(event, payload);
      return true;
    } catch (err) {
      this.logger.error(
        `sendToUser failed user=${userId} event=${event}: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );

      return false;
    }
  }

  /**
   * Send an event to every participant of a call.
   */
  async sendToCall(
    callId: string,
    participants: string[],
    event: string,
    payload: Record<string, unknown>,
  ): Promise<void> {
    await Promise.all(
      participants.map((userId) =>
        this.sendToUser(
          userId,
          event,
          {
            ...payload,
            callId,
          },
        ),
      ),
    );
  }

  /**
   * Broadcast only the live count.
   */
  async broadcastLiveCount(
    count: number,
  ): Promise<void> {
    for (
      const [, socket] of this.userToSocket
    ) {
      if (!socket.connected) {
        continue;
      }

      try {
        socket.emit(
          "LIVE_COUNT_UPDATED",
          {
            count,
          },
        );
      } catch (err) {
        this.logger.debug(
          `LIVE_COUNT_UPDATED failed for socket=${socket.id}: ${
            err instanceof Error ? err.message : String(err)
          }`,
        );
      }
    }
  }

  /**
   * Broadcast the full live-presence snapshot.
   *
   * count = TOTAL live users.
   *
   * Flutter can subtract its own user if necessary.
   */
  async broadcastLiveUsers(
    count: number,
    users: unknown[],
  ): Promise<void> {
    const payload = {
      count,
      users,
    };

    for (
      const [, socket] of this.userToSocket
    ) {
      if (!socket.connected) {
        continue;
      }

      try {
        socket.emit(
          "LIVE_USERS",
          payload,
        );

        socket.emit(
          "LIVE_COUNT_UPDATED",
          {
            count,
          },
        );
      } catch (err) {
        this.logger.debug(
          `LIVE_USERS broadcast failed socket=${socket.id}: ${
            err instanceof Error ? err.message : String(err)
          }`,
        );
      }
    }
  }

  /**
   * Number of users currently represented by an active socket.
   */
  connectedUserCount(): number {
    let count = 0;

    for (
      const [, socket] of this.userToSocket
    ) {
      if (socket.connected) {
        count++;
      }
    }

    return count;
  }

  /**
   * Optional debugging helper.
   */
  getSnapshot(): {
    users: string[];
    sockets: string[];
  } {
    return {
      users: Array.from(
        this.userToSocket.keys(),
      ),
      sockets: Array.from(
        this.socketToUser.keys(),
      ),
    };
  }
}
