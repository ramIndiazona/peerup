// import { Injectable, Logger } from "@nestjs/common";
// import { ConfigService } from "@nestjs/config";
// import { RedisService } from "../redis/redis.service";
// import { RealtimeEventsService } from "../realtime/realtime-events.service";
// import { PrismaService } from "../prisma/prisma.service";

// export enum PresenceStatus {
//   OFFLINE = "OFFLINE",
//   AVAILABLE = "AVAILABLE",
//   SEARCHING = "SEARCHING",
//   MATCHED = "MATCHED",
//   CONNECTING = "CONNECTING",
//   IN_CALL = "IN_CALL",
//   ENDING = "ENDING",
// }

// export interface Presence {
//   userId: string;
//   status: PresenceStatus;
//   socketId: string;
//   lastHeartbeat: number;
//   availableSince: number | null;
//   currentCallId: string | null;
//   lastActiveAt: number;
// }

// const PRESENCE_KEY_PREFIX = "presence:user:";
// const LIVE_SET = "live:users";
// const LIVE_COUNT_KEY = "live:count";

// /**
//  * Single source of truth for presence.
//  *
//  * State lives in Redis (through RedisService) so multiple backend instances
//  * agree on who is live. Whenever the live set membership changes we broadcast
//  * the current LIVE_USERS snapshot so every connected client updates without
//  * polling.
//  */
// @Injectable()
// export class PresenceService {
//   private readonly logger = new Logger(PresenceService.name);
//   private readonly heartbeatTimeoutSeconds: number;

//   constructor(
//     private readonly redis: RedisService,
//     config: ConfigService,
//     private readonly events: RealtimeEventsService,
//     private readonly prisma: PrismaService,
//   ) {
//     this.heartbeatTimeoutSeconds = config.get<number>(
//       "heartbeat.timeoutSeconds",
//       45,
//     );
//   }

//   private presenceKey(userId: string): string {
//     return `${PRESENCE_KEY_PREFIX}${userId}`;
//   }

//   private presenceTtl(): number {
//     return this.heartbeatTimeoutSeconds * 4;
//   }

//   private isLiveStatus(status: PresenceStatus | undefined): boolean {
//     return (
//       status === PresenceStatus.AVAILABLE || status === PresenceStatus.SEARCHING
//     );
//   }

//   async upsert(userId: string, data: Partial<Presence>): Promise<Presence> {
//     const existing = (await this.redis.getJson<Presence>(
//       this.presenceKey(userId),
//     )) ?? {
//       userId,
//       status: PresenceStatus.OFFLINE,
//       socketId: "",
//       lastHeartbeat: 0,
//       availableSince: null,
//       currentCallId: null,
//       lastActiveAt: Date.now(),
//     };

//     const next: Presence = {
//       ...existing,
//       ...data,
//       userId,
//       lastHeartbeat: Date.now(),
//       lastActiveAt: Date.now(),
//     };

//     await this.redis.setJson(
//       this.presenceKey(userId),
//       next,
//       this.presenceTtl(),
//     );

//     // Keep the "live users" set in sync with availability.
//     const isLive = this.isLiveStatus(next.status);
//     const wasLive = this.isLiveStatus(existing.status);

//     if (isLive && !wasLive) {
//       const added = await this.redis.sadd(LIVE_SET, userId);
//       if (added === 1) await this.redis.incr(LIVE_COUNT_KEY);
//       void this.broadcastLiveUsers();
//     } else if (!isLive && wasLive) {
//       const removed = await this.redis.srem(LIVE_SET, userId);
//       if (removed === 1) await this.redis.decr(LIVE_COUNT_KEY);
//       void this.broadcastLiveUsers();
//     }

//     return next;
//   }

//   async availability(
//     userId: string,
//     available: boolean,
//     socketId = "",
//   ): Promise<Presence> {
//     return this.upsert(userId, {
//       socketId,
//       status: available ? PresenceStatus.AVAILABLE : PresenceStatus.OFFLINE,
//       availableSince: available ? Date.now() : null,
//       currentCallId: null,
//     });
//   }

//   async get(userId: string): Promise<Presence | null> {
//     return this.redis.getJson<Presence>(this.presenceKey(userId));
//   }

//   async require(userId: string): Promise<Presence> {
//     const p = await this.get(userId);
//     if (!p) {
//       throw new Error(`NO_PRESENCE:${userId}`);
//     }
//     return p;
//   }

//   async getLiveCount(): Promise<number> {
//     const raw = await this.redis.get(LIVE_COUNT_KEY);
//     return raw ? parseInt(raw, 10) : 0;
//   }

//   async listLiveUserIds(): Promise<string[]> {
//     return this.redis.smembers(LIVE_SET);
//   }

//   async isHealthy(userId: string): Promise<boolean> {
//     const p = await this.get(userId);
//     if (!p) return false;
//     return Date.now() - p.lastHeartbeat <= this.heartbeatTimeoutSeconds * 1000;
//   }

//   async heartbeat(userId: string, socketId: string): Promise<Presence | null> {
//     return this.upsert(userId, { socketId });
//   }

//   async setCall(userId: string, callId: string | null): Promise<void> {
//     await this.upsert(userId, {
//       currentCallId: callId,
//       status: callId ? PresenceStatus.IN_CALL : PresenceStatus.AVAILABLE,
//       availableSince: callId ? null : Date.now(),
//     });
//   }

//   async setEnding(userId: string): Promise<void> {
//     await this.upsert(userId, { status: PresenceStatus.ENDING });
//   }

//   /**
//    * Remove a user from presence entirely.
//    *
//    * Always attempts to remove the user from the live set, which is safe when
//    * the membership is a ghost (presence key already expired): SREM returns 0
//    * and we do not touch the counter when the member was not present.
//    */
//   async setOffline(userId: string): Promise<void> {
//     const p = await this.get(userId);
//     const wasLive = this.isLiveStatus(p?.status);
//     const removed = await this.redis.srem(LIVE_SET, userId);
//     if (removed === 1) await this.redis.decr(LIVE_COUNT_KEY);
//     await this.redis.del(this.presenceKey(userId));
//     if (removed === 1 || wasLive) {
//       void this.broadcastLiveUsers();
//     }
//   }

//   async sweepStale(): Promise<string[]> {
//     // Honorary: prune any live membership whose presence has expired.
//     const liveIds = await this.listLiveUserIds();
//     let removed: string[] = [];
//     await Promise.all(
//       liveIds.map(async (id) => {
//         const p = await this.get(id);
//         if (
//           !p ||
//           Date.now() - p.lastHeartbeat > this.heartbeatTimeoutSeconds * 1000
//         ) {
//           await this.setOffline(id);
//           removed.push(id);
//         }
//       }),
//     );
//     if (removed.length > 0) {
//       this.logger.log(`Swept stale presence for ${removed.length} user(s)`);
//     }
//     return removed;
//   }

//   // Recompute the cached live count from the canonical set after drift.
//   async reconcileLiveCount(): Promise<number> {
//     const count = await this.redis.scard(LIVE_SET);
//     await this.redis.set(LIVE_COUNT_KEY, String(count));
//     return count;
//   }

//   /**
//    * Build the LIVE_USERS snapshot and push it to every connected client.
//    *
//    * count is the TOTAL number of live users; the Flutter client subtracts
//    * itself when it knows it is part of the list.
//    */
//   async broadcastLiveUsers(): Promise<void> {
//     try {
//       const liveIds = await this.listLiveUserIds();

//       if (liveIds.length === 0) {
//         await this.redis.set(LIVE_COUNT_KEY, "0");
//         this.logger.log("[LIVE] broadcasting LIVE_USERS count=0");
//         await this.events.broadcastLiveUsers(0, []);
//         return;
//       }

//       const [users, presences] = await Promise.all([
//         this.prisma.user.findMany({
//           where: { id: { in: liveIds } },
//           select: {
//             id: true,
//             profile: {
//               select: {
//                 name: true,
//                 avatar: true,
//                 englishLevel: true,
//                 nativeLanguage: true,
//                 learningLanguage: true,
//                 userInterests: {
//                   select: { interest: { select: { name: true } } },
//                 },
//               },
//             },
//           },
//         }),
//         Promise.all(liveIds.map((id) => this.get(id))),
//       ]);

//       const statusById = new Map<string, PresenceStatus>();
//       for (const p of presences) {
//         if (p) statusById.set(p.userId, p.status);
//       }

//       // Only expose users that still have a live presence record. Banned
//       // accounts are dropped automatically because banned users cannot be
//       // in a connected session.
//       const exposed = users
//         .filter((u) => statusById.has(u.id))
//         .map((u) => ({
//           id: u.id,
//           name: u.profile?.name ?? "Conversation Partner",
//           avatar: u.profile?.avatar ?? null,
//           englishLevel: u.profile?.englishLevel ?? ("B1" as const),
//           nativeLanguage: u.profile?.nativeLanguage ?? "English",
//           learningLanguage: u.profile?.learningLanguage ?? "English",
//           interests:
//             u.profile?.userInterests?.map((ui) => ui.interest.name) ?? [],
//           status: (statusById.get(u.id) ?? PresenceStatus.AVAILABLE) as string,
//         }));

//       const count = exposed.length;
//       // Keep the cached counter aligned with the canonical list so the REST
//       // endpoint and the socket payload never disagree.
//       await this.redis.set(LIVE_COUNT_KEY, String(count));

//       this.logger.log(`[LIVE] broadcasting LIVE_USERS count=${count}`);
//       await this.events.broadcastLiveUsers(count, exposed);
//     } catch (err) {
//       this.logger.error(
//         `[LIVE] LIVE_USERS broadcast failed: ${
//           err instanceof Error ? err.message : String(err)
//         }`,
//       );
//     }
//   }
// }
import {
  Injectable,
  Logger,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { RedisService } from "../redis/redis.service";
import { RealtimeEventsService } from "../realtime/realtime-events.service";
import { PrismaService } from "../prisma/prisma.service";

export enum PresenceStatus {
  OFFLINE = "OFFLINE",
  AVAILABLE = "AVAILABLE",
  SEARCHING = "SEARCHING",
  MATCHED = "MATCHED",
  CONNECTING = "CONNECTING",
  IN_CALL = "IN_CALL",
  ENDING = "ENDING",
}

export interface Presence {
  userId: string;
  status: PresenceStatus;
  socketId: string;
  lastHeartbeat: number;
  availableSince: number | null;
  currentCallId: string | null;
  lastActiveAt: number;
}

const PRESENCE_KEY_PREFIX = "presence:user:";
const LIVE_SET = "live:users";
const LIVE_COUNT_KEY = "live:count";

@Injectable()
export class PresenceService {
  private readonly logger =
    new Logger(PresenceService.name);

  private readonly heartbeatTimeoutSeconds: number;

  constructor(
    private readonly redis: RedisService,
    config: ConfigService,
    private readonly events: RealtimeEventsService,
    private readonly prisma: PrismaService,
  ) {
    this.heartbeatTimeoutSeconds =
      config.get<number>(
        "heartbeat.timeoutSeconds",
        45,
      );
  }

  private presenceKey(
    userId: string,
  ): string {
    return `${PRESENCE_KEY_PREFIX}${userId}`;
  }

  private presenceTtl(): number {
    return (
      this.heartbeatTimeoutSeconds * 4
    );
  }

  private isLiveStatus(
    status: PresenceStatus | undefined,
  ): boolean {
    return (
      status ===
        PresenceStatus.AVAILABLE ||
      status ===
        PresenceStatus.SEARCHING
    );
  }

  /**
   * Create/update presence.
   */
  async upsert(
    userId: string,
    data: Partial<Presence>,
  ): Promise<Presence> {
    const existing =
      (await this.redis.getJson<Presence>(
        this.presenceKey(userId),
      )) ?? {
        userId,
        status: PresenceStatus.OFFLINE,
        socketId: "",
        lastHeartbeat: 0,
        availableSince: null,
        currentCallId: null,
        lastActiveAt: Date.now(),
      };

    const now = Date.now();

    const next: Presence = {
      ...existing,
      ...data,
      userId,
      lastHeartbeat: now,
      lastActiveAt: now,
    };

    await this.redis.setJson(
      this.presenceKey(userId),
      next,
      this.presenceTtl(),
    );

    const wasLive =
      this.isLiveStatus(
        existing.status,
      );

    const isLive =
      this.isLiveStatus(
        next.status,
      );

    /**
     * OFFLINE/MATCHED/etc -> AVAILABLE/SEARCHING
     */
    if (
      isLive &&
      !wasLive
    ) {
      const added =
        await this.redis.sadd(
          LIVE_SET,
          userId,
        );

      if (added === 1) {
        await this.incrementLiveCount();
      }

      void this.broadcastLiveUsers();
    }

    /**
     * AVAILABLE/SEARCHING -> non-live state
     */
    else if (
      !isLive &&
      wasLive
    ) {
      const removed =
        await this.redis.srem(
          LIVE_SET,
          userId,
        );

      if (removed === 1) {
        await this.decrementLiveCount();
      }

      void this.broadcastLiveUsers();
    }

    return next;
  }

  /**
   * Safely increment cached live count.
   *
   * LIVE_SET remains the canonical source.
   */
  private async incrementLiveCount(): Promise<void> {
    await this.redis.incr(
      LIVE_COUNT_KEY,
    );
  }

  /**
   * Safely decrement cached live count.
   *
   * Never allow negative values.
   */
  private async decrementLiveCount(): Promise<void> {
    const raw =
      await this.redis.get(
        LIVE_COUNT_KEY,
      );

    const current =
      raw ? parseInt(raw, 10) : 0;

    if (current <= 0) {
      await this.redis.set(
        LIVE_COUNT_KEY,
        "0",
      );
      return;
    }

    await this.redis.decr(
      LIVE_COUNT_KEY,
    );
  }

  /**
   * Mark user available/offline.
   *
   * IMPORTANT:
   * Do not use this to terminate an active call.
   * Call state should be managed by CallsService.
   */
  async availability(
    userId: string,
    available: boolean,
    socketId = "",
  ): Promise<Presence> {
    const existing =
      await this.get(userId);

    /**
     * Don't accidentally destroy an active call
     * because of a duplicate LIVE_START/LIVE_STOP.
     */
    if (
      existing &&
      (
        existing.status ===
          PresenceStatus.MATCHED ||
        existing.status ===
          PresenceStatus.CONNECTING ||
        existing.status ===
          PresenceStatus.IN_CALL ||
        existing.status ===
          PresenceStatus.ENDING
      )
    ) {
      return this.upsert(
        userId,
        {
          socketId:
            socketId ||
            existing.socketId,
        },
      );
    }

    return this.upsert(
      userId,
      {
        socketId,
        status: available
          ? PresenceStatus.AVAILABLE
          : PresenceStatus.OFFLINE,
        availableSince: available
          ? Date.now()
          : null,
        currentCallId:
          available
            ? null
            : existing?.currentCallId ??
              null,
      },
    );
  }

  async get(
    userId: string,
  ): Promise<Presence | null> {
    return this.redis.getJson<Presence>(
      this.presenceKey(userId),
    );
  }

  async require(
    userId: string,
  ): Promise<Presence> {
    const presence =
      await this.get(userId);

    if (!presence) {
      throw new Error(
        `NO_PRESENCE:${userId}`,
      );
    }

    return presence;
  }

  async getLiveCount(): Promise<number> {
    /**
     * LIVE_SET is canonical.
     *
     * This avoids returning a stale cached count.
     */
    return this.redis.scard(
      LIVE_SET,
    );
  }

  async listLiveUserIds(): Promise<string[]> {
    return this.redis.smembers(
      LIVE_SET,
    );
  }

  async isHealthy(
    userId: string,
  ): Promise<boolean> {
    const presence =
      await this.get(userId);

    if (!presence) {
      return false;
    }

    return (
      Date.now() -
        presence.lastHeartbeat <=
      this.heartbeatTimeoutSeconds *
        1000
    );
  }

  /**
   * Heartbeat must preserve the current state.
   *
   * Example:
   *
   * SEARCHING + heartbeat
   *     -> SEARCHING
   *
   * MATCHED + heartbeat
   *     -> MATCHED
   *
   * IN_CALL + heartbeat
   *     -> IN_CALL
   */
  async heartbeat(
    userId: string,
    socketId: string,
  ): Promise<Presence | null> {
    const existing =
      await this.get(userId);

    if (!existing) {
      return null;
    }

    /**
     * Ignore stale socket heartbeat.
     */
    if (
      existing.socketId &&
      existing.socketId !== socketId
    ) {
      this.logger.warn(
        `[PRESENCE] Ignoring heartbeat from stale socket user=${userId}`,
      );

      return existing;
    }

    return this.upsert(
      userId,
      {
        socketId,
      },
    );
  }

  /**
   * Associate a call with the user.
   */
  async setCall(
    userId: string,
    callId: string | null,
  ): Promise<void> {
    const existing =
      await this.get(userId);

    /**
     * Call started.
     */
    if (callId) {
      await this.upsert(
        userId,
        {
          currentCallId: callId,
          status:
            PresenceStatus.IN_CALL,
          availableSince: null,
        },
      );

      return;
    }

    /**
     * Call ended.
     *
     * Only return to AVAILABLE if the user
     * actually still has a live session.
     */
    if (
      existing &&
      existing.socketId &&
      this.events.isCurrentSocket(
        userId,
        existing.socketId,
      )
    ) {
      await this.upsert(
        userId,
        {
          currentCallId: null,
          status:
            PresenceStatus.AVAILABLE,
          availableSince: Date.now(),
        },
      );
    } else {
      await this.setOffline(
        userId,
      );
    }
  }

  async setEnding(
    userId: string,
  ): Promise<void> {
    await this.upsert(
      userId,
      {
        status:
          PresenceStatus.ENDING,
      },
    );
  }

  /**
   * Completely remove user from live presence.
   */
  async setOffline(
    userId: string,
  ): Promise<void> {
    const presence =
      await this.get(userId);

    const wasLive =
      this.isLiveStatus(
        presence?.status,
      );

    const removed =
      await this.redis.srem(
        LIVE_SET,
        userId,
      );

    /**
     * Prefer the actual set membership change.
     */
    if (removed === 1) {
      await this.decrementLiveCount();
    }

    await this.redis.del(
      this.presenceKey(userId),
    );

    if (
      removed === 1 ||
      wasLive
    ) {
      void this.broadcastLiveUsers();
    }
  }

  /**
   * Remove stale users.
   */
  async sweepStale(): Promise<string[]> {
    const liveIds =
      await this.listLiveUserIds();

    const removed: string[] = [];

    await Promise.all(
      liveIds.map(
        async (userId) => {
          const presence =
            await this.get(userId);

          if (
            !presence ||
            Date.now() -
              presence.lastHeartbeat >
              this.heartbeatTimeoutSeconds *
                1000
          ) {
            await this.setOffline(
              userId,
            );

            removed.push(
              userId,
            );
          }
        },
      ),
    );

    if (
      removed.length > 0
    ) {
      this.logger.log(
        `[PRESENCE] Swept stale presence for ${removed.length} user(s)`,
      );
    }

    return removed;
  }

  /**
   * Recompute cached count from canonical Redis set.
   */
  async reconcileLiveCount(): Promise<number> {
    const count =
      await this.redis.scard(
        LIVE_SET,
      );

    await this.redis.set(
      LIVE_COUNT_KEY,
      String(count),
    );

    return count;
  }

  /**
   * Build and broadcast the live-user snapshot.
   */
  async broadcastLiveUsers(): Promise<void> {
    try {
      const liveIds =
        await this.listLiveUserIds();

      if (
        liveIds.length === 0
      ) {
        await this.redis.set(
          LIVE_COUNT_KEY,
          "0",
        );

        this.logger.log(
          "[LIVE] broadcasting LIVE_USERS count=0",
        );

        await this.events.broadcastLiveUsers(
          0,
          [],
        );

        return;
      }

      const [
        users,
        presences,
      ] = await Promise.all([
        this.prisma.user.findMany({
          where: {
            id: {
              in: liveIds,
            },
          },
          select: {
            id: true,
            profile: {
              select: {
                name: true,
                avatar: true,
                englishLevel: true,
                nativeLanguage: true,
                learningLanguage: true,
                userInterests: {
                  select: {
                    interest: {
                      select: {
                        name: true,
                      },
                    },
                  },
                },
              },
            },
          },
        }),

        Promise.all(
          liveIds.map(
            (id) =>
              this.get(id),
          ),
        ),
      ]);

      const statusById =
        new Map<
          string,
          PresenceStatus
        >();

      for (
        const presence of presences
      ) {
        if (!presence) {
          continue;
        }

        /**
         * Only expose AVAILABLE/SEARCHING users.
         *
         * If someone moved to MATCHED or IN_CALL but Redis
         * membership hasn't been removed yet, don't expose
         * them as a live matchmaking candidate.
         */
        if (
          this.isLiveStatus(
            presence.status,
          )
        ) {
          statusById.set(
            presence.userId,
            presence.status,
          );
        }
      }

      const exposed =
        users
          .filter((user) =>
            statusById.has(
              user.id,
            ),
          )
          .map((user) => ({
            id: user.id,

            name:
              user.profile?.name ??
              "Conversation Partner",

            avatar:
              user.profile?.avatar ??
              null,

            englishLevel:
              user.profile
                ?.englishLevel ??
              ("B1" as const),

            nativeLanguage:
              user.profile
                ?.nativeLanguage ??
              "English",

            learningLanguage:
              user.profile
                ?.learningLanguage ??
              "English",

            interests:
              user.profile
                ?.userInterests
                ?.map(
                  (ui) =>
                    ui.interest.name,
                ) ?? [],

            status:
              statusById.get(
                user.id,
              ) ??
              PresenceStatus.AVAILABLE,
          }));

      const count =
        exposed.length;

      /**
       * Keep cached counter synchronized.
       */
      await this.redis.set(
        LIVE_COUNT_KEY,
        String(count),
      );

      this.logger.log(
        `[LIVE] broadcasting LIVE_USERS count=${count}`,
      );

      await this.events.broadcastLiveUsers(
        count,
        exposed,
      );
    } catch (err) {
      this.logger.error(
        `[LIVE] LIVE_USERS broadcast failed: ${
          err instanceof Error
            ? err.message
            : String(err)
        }`,
      );
    }
  }
}