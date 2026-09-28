

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CallStatus, MatchType } from '@prisma/client';
import { Cron, CronExpression } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import {
  PresenceService,
  PresenceStatus,
} from '../presence/presence.service';
import { RealtimeEventsService } from '../realtime/realtime-events.service';
import { CallsService } from '../calls/calls.service';

import {
  ApiException,
  conflict,
} from '../common/errors/api.exception';

import {
  CandidateProfile,
  filterCandidate,
  MatchFilters,
  scoreCandidate,
  selectWeightedRandom,
  ScoredCandidate,
} from './scoring';

const SEARCH_KEY_PREFIX = 'matchmaking:search:';
const QUEUE_KEY_PREFIX = 'matchmaking:queue:';
const SKIP_KEY_PREFIX = 'matchmaking:skip:';
const MATCH_LOCK_PREFIX = 'match:user:';
const START_RATE_KEY = 'rate:matchmaking:start:';

const MATCH_LOCK_TTL_SECONDS = 30;
const SKIP_TTL_SECONDS = 30;

interface SearchRecord {
  userId: string;
  filters: MatchFilters;
  enqueuedAt: number;
  queues: string[];
}

export interface MatchFoundPayload {
  callId: string;
  role: 'caller' | 'callee';

  peer: {
    id: string;
    name: string;
    avatar: string | null;
    englishLevel: string;
    nativeLanguage: string;
    country: string | null;
    interests: string[];
  };
}

@Injectable()
export class MatchmakingService {
  private readonly logger = new Logger(MatchmakingService.name);

  private readonly matchTimeoutSeconds: number;
  private readonly maxCandidates: number;
  private readonly cooldownHours: number;

  private readonly matchTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly presence: PresenceService,
    private readonly events: RealtimeEventsService,
    private readonly calls: CallsService,
    config: ConfigService,
  ) {
    this.matchTimeoutSeconds = config.get<number>(
      'matchmaking.matchTimeoutSeconds',
      20,
    );

    this.maxCandidates = config.get<number>(
      'matchmaking.maxCandidatesPerScan',
      50,
    );

    this.cooldownHours = config.get<number>(
      'limits.recentPairCooldownHours',
      2,
    );
  }

  // ============================================================
  // START SEARCH
  // ============================================================

  async start(
    userId: string,
    filters: MatchFilters,
  ): Promise<{ searching: true }> {
    // ----------------------------------------------------------
    // Rate limit
    // ----------------------------------------------------------

    const rate = await this.redis.rateLimit(
      `${START_RATE_KEY}${userId}`,
      20,
      60,
    );

    if (!rate.allowed) {
      throw new ApiException(
        'RATE_LIMITED',
        'Too many matchmaking attempts',
        429,
      );
    }

    // ----------------------------------------------------------
    // Check presence
    // ----------------------------------------------------------

    const presence = await this.presence.get(userId);

    this.logger.log(
      `[MATCH] START user=${userId} status=${presence?.status ?? 'OFFLINE'}`,
    );

    if (!presence) {
      throw conflict(
        'NOT_LIVE',
        'You must be live before searching',
      );
    }

    // User already searching/matched/in call
    if (
      presence.status === PresenceStatus.SEARCHING ||
      presence.status === PresenceStatus.MATCHED ||
      presence.status === PresenceStatus.IN_CALL
    ) {
      throw conflict(
        'ALREADY_SEARCHING',
        'You are already searching or in a call',
      );
    }

    // User must be AVAILABLE before clicking Start
    if (presence.status !== PresenceStatus.AVAILABLE) {
      throw conflict(
        'NOT_AVAILABLE',
        'You are not currently available',
      );
    }

    // ----------------------------------------------------------
    // Normalize filters
    // ----------------------------------------------------------

    const normalizedFilters: MatchFilters = {
      ...filters,

      language:
        filters.language?.trim() || undefined,

      level:
        filters.level?.trim().toUpperCase() || undefined,

      interests:
        filters.interests
          ?.map((item) => item.trim())
          .filter(Boolean),

      goal:
        filters.goal?.trim() || undefined,

      matchType:
        filters.matchType || 'random',
    };

    // ----------------------------------------------------------
    // Add user to SEARCHING queue
    // ----------------------------------------------------------

    await this.enqueueUser(
      userId,
      normalizedFilters,
    );

    // IMPORTANT:
    //
    // AVAILABLE -> SEARCHING
    //
    // A user becomes eligible for matching ONLY after
    // pressing Start.
    await this.presence.upsert(userId, {
      status: PresenceStatus.SEARCHING,
      availableSince:
        presence.availableSince ?? Date.now(),
    });

    this.scheduleMatchTimeout(userId);

    this.logger.log(
      `[MATCH] SEARCHING user=${userId}`,
    );

    // ----------------------------------------------------------
    // Immediately try to match
    // ----------------------------------------------------------

    void this.processSearch(
      userId,
      new Set<string>(),
    )
      .then((matched) => {
        if (matched) {
          this.logger.log(
            `[MATCH] INITIAL_MATCH user=${userId}`,
          );
        }
      })
      .catch((error) => {
        this.logger.error(
          `[MATCH] INITIAL_SEARCH_ERROR user=${userId}`,
          error instanceof Error
            ? error.stack
            : String(error),
        );
      });

    return {
      searching: true,
    };
  }

  // ============================================================
  // CANCEL SEARCH
  // ============================================================

  async cancel(
    userId: string,
  ): Promise<{ searching: false }> {
    return this.dequeueUser(
      userId,
      false,
    );
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  async cancelByDisconnect(
    userId: string,
  ): Promise<void> {
    await this.dequeueUser(
      userId,
      true,
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  async getStatus(userId: string) {
    const presence =
      await this.presence.get(userId);

    const search =
      await this.redis.getJson<SearchRecord>(
        `${SEARCH_KEY_PREFIX}${userId}`,
      );

    const status =
      presence?.status ??
      PresenceStatus.OFFLINE;

    const result: Record<string, unknown> = {
      status,

      searching:
        status === PresenceStatus.SEARCHING,

      filters:
        search?.filters,

      queuePosition:
        undefined as number | undefined,
    };

    // ----------------------------------------------------------
    // Recover active call
    // ----------------------------------------------------------

    const callId =
      presence?.currentCallId;

    if (
      callId &&
      (
        status === PresenceStatus.MATCHED ||
        status === PresenceStatus.CONNECTING ||
        status === PresenceStatus.IN_CALL
      )
    ) {
      const call =
        await this.prisma.callSession.findUnique({
          where: {
            id: callId,
          },
          select: {
            id: true,
            userAId: true,
            userBId: true,
            status: true,
          },
        });

      const isParticipant =
        call &&
        (
          call.userAId === userId ||
          call.userBId === userId
        );

      const callActive =
        call &&
        call.status !== CallStatus.ENDED &&
        call.status !== CallStatus.CANCELLED;

      if (
        isParticipant &&
        callActive
      ) {
        const peerId =
          call.userAId === userId
            ? call.userBId
            : call.userAId;

        result.callId = call.id;

        result.role =
          call.userAId === userId
            ? 'caller'
            : 'callee';

        result.peer =
          await this.buildPeerProfile(
            userId,
            peerId,
          );
      }
    }

    return result;
  }

  // ============================================================
  // QUEUE
  // ============================================================

  private async enqueueUser(
    userId: string,
    filters: MatchFilters,
  ): Promise<SearchRecord> {
    const levelKey =
      filters.level?.toUpperCase() ??
      'ANY';

    const languageKey =
      filters.language?.toLowerCase() ??
      'english';

    const primaryQueue =
      `${QUEUE_KEY_PREFIX}${languageKey}:${levelKey}`;

    const queues = [
      primaryQueue,
    ];

    // Preferred level range queue
    if (
      filters.preferredLevel?.min &&
      filters.preferredLevel?.max
    ) {
      queues.push(
        `${QUEUE_KEY_PREFIX}${languageKey}:` +
        `${filters.preferredLevel.min.toUpperCase()}-` +
        `${filters.preferredLevel.max.toUpperCase()}`,
      );
    }

    const now = Date.now();

    const search: SearchRecord = {
      userId,
      filters,
      enqueuedAt: now,
      queues,
    };

    // Search record
    await this.redis.setJson(
      `${SEARCH_KEY_PREFIX}${userId}`,
      search,
      this.matchTimeoutSeconds + 60,
    );

    // Sorted queues
    await Promise.all(
      queues.map((queue) =>
        this.redis.zadd(
          queue,
          now,
          userId,
        ),
      ),
    );

    return search;
  }

  // ============================================================
  // REMOVE SEARCH
  // ============================================================

  private async removeSearch(
    userId: string,
  ): Promise<void> {
    const search =
      await this.redis.getJson<SearchRecord>(
        `${SEARCH_KEY_PREFIX}${userId}`,
      );

    // Remove from sorted queues
    if (search?.queues?.length) {
      await Promise.all(
        search.queues.map((queue) =>
          this.redis.zrem(
            queue,
            userId,
          ),
        ),
      );
    }

    // Remove search record
    await this.redis.del(
      `${SEARCH_KEY_PREFIX}${userId}`,
    );

    // Remove user's own skip base key
    await this.redis.del(
      `${SKIP_KEY_PREFIX}${userId}`,
    );
  }

  // ============================================================
  // DEQUEUE
  // ============================================================

  private async dequeueUser(
    userId: string,
    disconnected: boolean,
  ): Promise<{ searching: false }> {
    // ----------------------------------------------------------
    // IMPORTANT:
    //
    // Cancellation/disconnect must use the SAME per-user lock as
    // tryReserve().
    //
    // Otherwise this race is possible:
    //
    // A starts matching B
    //   -> tryReserve() reads B as SEARCHING
    // B cancels at the same time
    //   -> B becomes AVAILABLE
    // A continues
    //   -> B gets matched even though B already cancelled
    //
    // The lock makes cancellation and reservation mutually exclusive.
    // ----------------------------------------------------------
    const releaseLock =
      await this.redis.acquireLock(
        `${MATCH_LOCK_PREFIX}${userId}`,
        MATCH_LOCK_TTL_SECONDS,
      );

    if (!releaseLock) {
      // A match reservation is currently in progress.
      //
      // Do not mutate presence outside the lock. The reservation
      // will either finish the match or release the lock, after which
      // the caller can retry cancellation.
      this.logger.debug(
        `[MATCH] DEQUEUE_LOCK_BUSY user=${userId}`,
      );

      return {
        searching: false,
      };
    }

    try {
      const presence =
        await this.presence.get(userId);

      // --------------------------------------------------------
      // If the user has already been matched/called, do NOT
      // convert that state back to AVAILABLE/OFFLINE.
      // --------------------------------------------------------
      if (
        !presence ||
        presence.status !==
          PresenceStatus.SEARCHING
      ) {
        this.clearMatchTimer(userId);

        if (!disconnected) {
          await this.events.sendToUser(
            userId,
            'MATCH_CANCELLED',
            {
              searching: false,
            },
          );
        }

        return {
          searching: false,
        };
      }

      // Remove search while the same lock is held.
      await this.removeSearch(userId);

      this.clearMatchTimer(userId);

      // SEARCHING -> AVAILABLE/OFFLINE.
      await this.presence.upsert(
        userId,
        {
          status: disconnected
            ? PresenceStatus.OFFLINE
            : PresenceStatus.AVAILABLE,

          availableSince:
            disconnected
              ? null
              : Date.now(),

          currentCallId: null,
        },
      );

      if (!disconnected) {
        await this.events.sendToUser(
          userId,
          'MATCH_CANCELLED',
          {
            searching: false,
          },
        );
      }

      this.logger.debug(
        `[MATCH] SEARCH_REMOVED user=${userId}`,
      );

      return {
        searching: false,
      };
    } finally {
      await releaseLock();
    }
  }

  // ============================================================
  // MATCHMAKING SWEEP
  // ============================================================

  @Cron(
    CronExpression.EVERY_5_SECONDS,
    {
      name: 'matchmaking-sweep',
    },
  )
  async sweep(): Promise<void> {
    const keys =
      await this.redis.raw.keys(
        `${SEARCH_KEY_PREFIX}*`,
      );

    if (
      !keys ||
      keys.length === 0
    ) {
      return;
    }

    await Promise.all(
      keys
        .slice(0, 100)
        .map(async (key) => {
          const userId =
            key.split(':').pop();

          if (!userId) {
            return;
          }

          const search =
            await this.redis.getJson<SearchRecord>(
              key,
            );

          if (!search) {
            return;
          }

          const elapsed =
            Date.now() -
            search.enqueuedAt;

          if (
            elapsed <
            this.matchTimeoutSeconds * 1000
          ) {
            await this.processSearch(
              userId,
              new Set<string>(),
            ).catch((error) => {
              this.logger.error(
                `[MATCH] SWEEP_ERROR user=${userId}`,
                error instanceof Error
                  ? error.stack
                  : String(error),
              );
            });
          }
        }),
    );
  }

  // ============================================================
  // PROCESS SEARCH
  // ============================================================

  async processSearch(
    userId: string,
    excluded: Set<string>,
  ): Promise<boolean> {
    // ----------------------------------------------------------
    // User MUST still be SEARCHING
    // ----------------------------------------------------------

    const presence =
      await this.presence.get(userId);

    if (
      !presence ||
      presence.status !==
        PresenceStatus.SEARCHING
    ) {
      return false;
    }

    // ----------------------------------------------------------
    // User MUST have a search record
    // ----------------------------------------------------------

    const search =
      await this.redis.getJson<SearchRecord>(
        `${SEARCH_KEY_PREFIX}${userId}`,
      );

    if (!search) {
      return false;
    }

    // ----------------------------------------------------------
    // Load ONLY SEARCHING candidates
    // ----------------------------------------------------------

    this.logger.debug(
      `[MATCH][TRACE] PROCESS user=${userId} filters=${JSON.stringify(search.filters)}`,
    );

    const loadResult =
      await this.loadCandidates(
        userId,
        search.filters,
        excluded,
      );

    this.logger.debug(
      `[MATCH][TRACE] LOAD_RESULT user=${userId} candidates=${loadResult.length} ids=${loadResult.map((x) => x.candidate.userId).join(',') || 'NONE'}`,
    );

    if (
      loadResult.length === 0
    ) {
      await this.events.sendToUser(
        userId,
        'MATCH_SEARCHING',
        {
          hint: 'warming',
          count: 0,
        },
      );

      return false;
    }

    // ----------------------------------------------------------
    // Score candidates
    // ----------------------------------------------------------

    const scored: ScoredCandidate[] =
      loadResult.map(
        ({
          candidate,
          history,
        }) =>
          scoreCandidate(
            candidate,
            search.filters,
            history,
          ),
      );

    // ----------------------------------------------------------
    // Try candidates
    // ----------------------------------------------------------

    let attempts = 0;

    while (
      attempts < this.maxCandidates
    ) {
      const chosen =
        selectWeightedRandom(
          scored,
          5,
        );

      if (!chosen) {
        break;
      }

      attempts++;

      // Remove candidate from this scan
      const index =
        scored.indexOf(chosen);

      if (index >= 0) {
        scored.splice(
          index,
          1,
        );
      }

      this.logger.debug(
        `[MATCH][TRACE] TRY user=${userId} candidate=${chosen.candidate.userId}`,
      );

      const resolved =
        await this.tryReserve(
          userId,
          chosen.candidate.userId,
          search.filters,
        );

      this.logger.debug(
        `[MATCH][TRACE] TRY_RESULT user=${userId} candidate=${chosen.candidate.userId} result=${resolved}`,
      );

      if (
        resolved === 'reserved'
      ) {
        return true;
      }

      excluded.add(
        chosen.candidate.userId,
      );

      // Temporarily skip this pair
      await this.redis.set(
        `${SKIP_KEY_PREFIX}${userId}:${chosen.candidate.userId}`,
        String(Date.now()),
        SKIP_TTL_SECONDS,
      );
    }

    return false;
  }

  // ============================================================
  // ATOMIC RESERVATION
  // ============================================================

  private async tryReserve(
    userId: string,
    candidateId: string,
    filters: MatchFilters,
  ): Promise<
    'reserved' | 'retry' | 'skip'
  > {
    // ----------------------------------------------------------
    // IMPORTANT:
    //
    // Always lock users in deterministic order.
    //
    // This prevents:
    //
    // User A -> locks A -> waits B
    // User B -> locks B -> waits A
    //
    // ----------------------------------------------------------

    const [firstId, secondId] =
      [userId, candidateId].sort();

    const lockFirst =
      await this.redis.acquireLock(
        `${MATCH_LOCK_PREFIX}${firstId}`,
        MATCH_LOCK_TTL_SECONDS,
      );

    if (!lockFirst) {
      this.logger.debug(`[MATCH][TRACE] RESERVE_SKIP_LOCK_FIRST user=${userId} candidate=${candidateId}`);
      return 'skip';
    }

    try {
      const lockSecond =
        await this.redis.acquireLock(
          `${MATCH_LOCK_PREFIX}${secondId}`,
          MATCH_LOCK_TTL_SECONDS,
        );

      if (!lockSecond) {
        this.logger.debug(`[MATCH][TRACE] RESERVE_RETRY_LOCK_SECOND user=${userId} candidate=${candidateId}`);
        return 'retry';
      }

      try {
        // ------------------------------------------------------
        // Re-read presence while BOTH users are locked
        // ------------------------------------------------------

        const [
          self,
          other,
        ] = await Promise.all([
          this.presence.get(userId),
          this.presence.get(candidateId),
        ]);

        // ------------------------------------------------------
        // USER MUST STILL BE SEARCHING
        // ------------------------------------------------------

        if (
          !self ||
          self.status !==
            PresenceStatus.SEARCHING
        ) {
          this.logger.debug(`[MATCH][TRACE] REJECT_SELF_NOT_SEARCHING user=${userId} status=${self?.status ?? 'NONE'}`);
          return 'skip';
        }

        // ------------------------------------------------------
        // CANDIDATE MUST ALSO BE SEARCHING
        //
        // THIS IS THE IMPORTANT FLOW CHANGE.
        //
        // AVAILABLE users are NEVER automatically matched.
        // ------------------------------------------------------

        if (
          !other ||
          other.status !==
            PresenceStatus.SEARCHING
        ) {
          this.logger.debug(`[MATCH][TRACE] REJECT_CANDIDATE_NOT_SEARCHING user=${userId} candidate=${candidateId} status=${other?.status ?? 'NONE'}`);
          return 'retry';
        }

        // ------------------------------------------------------
        // Neither user can already have a call
        // ------------------------------------------------------

        if (
          self.currentCallId ||
          other.currentCallId
        ) {
          this.logger.debug(`[MATCH][TRACE] REJECT_CALL_EXISTS user=${userId} candidate=${candidateId} selfCall=${self.currentCallId ?? 'NONE'} candidateCall=${other.currentCallId ?? 'NONE'}`);
          return 'retry';
        }

        // ------------------------------------------------------
        // Candidate MUST have an active search record
        //
        // This protects against stale SEARCHING presence.
        // ------------------------------------------------------

        const candidateSearch =
          await this.redis.getJson<SearchRecord>(
            `${SEARCH_KEY_PREFIX}${candidateId}`,
          );

        if (!candidateSearch) {
          this.logger.debug(
            `[MATCH] CANDIDATE_SEARCH_MISSING candidate=${candidateId}`,
          );

          return 'retry';
        }

        // ------------------------------------------------------
        // Candidate search record must also belong to candidate
        // ------------------------------------------------------

        this.logger.debug(`[MATCH][TRACE] CANDIDATE_SEARCH_OK candidate=${candidateId}`);

        if (
          candidateSearch.userId !==
          candidateId
        ) {
          this.logger.warn(
            `[MATCH] INVALID_SEARCH_RECORD candidate=${candidateId}`,
          );

          return 'retry';
        }

        // ------------------------------------------------------
        // DOUBLE-CHECK BLOCKS
        // ------------------------------------------------------

        const blocked =
          await this.prisma.block.findFirst({
            where: {
              OR: [
                {
                  blockerId: userId,
                  blockedId: candidateId,
                },
                {
                  blockerId: candidateId,
                  blockedId: userId,
                },
              ],
            },
            select: {
              id: true,
            },
          });

        if (blocked) {
          this.logger.debug(`[MATCH][TRACE] REJECT_BLOCKED user=${userId} candidate=${candidateId}`);
          return 'retry';
        }

        // ------------------------------------------------------
        // DOUBLE-CHECK BAN
        // ------------------------------------------------------

        const candidateUser =
          await this.prisma.user.findUnique({
            where: {
              id: candidateId,
            },
            select: {
              isBanned: true,
            },
          });

        if (
          !candidateUser ||
          candidateUser.isBanned
        ) {
          this.logger.debug(`[MATCH][TRACE] REJECT_BANNED user=${userId} candidate=${candidateId}`);
          return 'retry';
        }

        // ------------------------------------------------------
        // RECENT MATCH COOLDOWN
        // ------------------------------------------------------

        const recent =
          await this.prisma.match.findFirst({
            where: {
              OR: [
                {
                  userAId: userId,
                  userBId: candidateId,
                },
                {
                  userAId: candidateId,
                  userBId: userId,
                },
              ],

              matchedAt: {
                gte:
                  new Date(
                    Date.now() -
                      this.cooldownHours *
                        3600_000,
                  ),
              },
            },

            select: {
              id: true,
            },
          });

        if (recent) {
          this.logger.debug(`[MATCH][TRACE] REJECT_RECENT_MATCH user=${userId} candidate=${candidateId}`);
          return 'retry';
        }

        // ------------------------------------------------------
        // CREATE MATCH + CALL SESSION
        // ------------------------------------------------------

        const session =
          await this.createMatch(
            userId,
            candidateId,
            filters,
          );

        // ------------------------------------------------------
        // Register call in signaling layer
        // ------------------------------------------------------

        await this.calls.registerCall(
          session.callId,
          [
            userId,
            candidateId,
          ],
          CallStatus.MATCHED,
        );

        // ------------------------------------------------------
        // Connect timeout
        // ------------------------------------------------------

        try {
          this.calls.scheduleConnectTimeout(
            session.callId,
          );
        } catch (error) {
          this.logger.error(
            `[MATCH] CONNECT_TIMEOUT_SCHEDULE_FAILED call=${session.callId}`,
            error instanceof Error
              ? error.stack
              : String(error),
          );
        }

        // ------------------------------------------------------
        // BOTH USERS:
        //
        // SEARCHING -> MATCHED
        //
        // Also remove BOTH search records.
        // ------------------------------------------------------

        await Promise.all([
          this.presence.upsert(
            userId,
            {
              status:
                PresenceStatus.MATCHED,

              currentCallId:
                session.callId,

              socketId:
                self.socketId,
            },
          ),

          this.presence.upsert(
            candidateId,
            {
              status:
                PresenceStatus.MATCHED,

              currentCallId:
                session.callId,

              socketId:
                other.socketId,
            },
          ),

          this.removeSearch(
            userId,
          ),

          this.removeSearch(
            candidateId,
          ),
        ]);

        // ------------------------------------------------------
        // Clear timers for BOTH users
        // ------------------------------------------------------

        this.clearMatchTimer(
          userId,
        );

        this.clearMatchTimer(
          candidateId,
        );

        // ------------------------------------------------------
        // Build peer profiles
        // ------------------------------------------------------

        const [
          peerForSelf,
          peerForOther,
        ] = await Promise.all([
          this.buildPeerProfile(
            userId,
            candidateId,
          ),

          this.buildPeerProfile(
            candidateId,
            userId,
          ),
        ]);

        // ------------------------------------------------------
        // MATCH_FOUND
        // ------------------------------------------------------

        await Promise.all([
          this.events.sendToUser(
            userId,
            'MATCH_FOUND',
            {
              callId:
                session.callId,

              role: 'caller',

              peer:
                peerForSelf,
            } satisfies MatchFoundPayload as unknown as Record<
              string,
              unknown
            >,
          ),

          this.events.sendToUser(
            candidateId,
            'MATCH_FOUND',
            {
              callId:
                session.callId,

              role: 'callee',

              peer:
                peerForOther,
            } satisfies MatchFoundPayload as unknown as Record<
              string,
              unknown
            >,
          ),
        ]);

        this.logger.log(
          `[MATCH] MATCH_FOUND user=${userId} candidate=${candidateId} call=${session.callId}`,
        );

        return 'reserved';
      } finally {
        await lockSecond();
      }
    } finally {
      await lockFirst();
    }
  }

  // ============================================================
  // CREATE MATCH
  // ============================================================

  private async createMatch(
    userId: string,
    candidateId: string,
    filters: MatchFilters,
  ): Promise<{
    callId: string;
    matchId: string;
  }> {
    const matchType =
      this.resolveMatchType(
        filters.matchType,
      );

    return this.prisma.$transaction(
      async (tx) => {
        const now =
          new Date();

        // ------------------------------------------------------
        // Call session
        // ------------------------------------------------------

        const call =
          await tx.callSession.create({
            data: {
              userAId: userId,
              userBId: candidateId,

              status:
                CallStatus.MATCHED,

              startedAt: now,

              region:
                filters.language,
            },

            select: {
              id: true,
            },
          });

        // ------------------------------------------------------
        // Match
        // ------------------------------------------------------

        const match =
          await tx.match.create({
            data: {
              userAId: userId,
              userBId: candidateId,

              matchType,

              matchedAt: now,

              callSessionId:
                call.id,
            },

            select: {
              id: true,
            },
          });

        // ------------------------------------------------------
        // DB user status
        // ------------------------------------------------------

        await tx.user.updateMany({
          where: {
            id: {
              in: [
                userId,
                candidateId,
              ],
            },
          },

          data: {
            status:
              'MATCHED' as any,

            lastSeenAt:
              now,
          },
        });

        return {
          callId: call.id,
          matchId: match.id,
        };
      },
    );
  }

  // ============================================================
  // MATCH TYPE
  // ============================================================

  private resolveMatchType(
    type?: string,
  ): MatchType {
    const map: Record<
      string,
      MatchType
    > = {
      random:
        MatchType.RANDOM,

      level:
        MatchType.SIMILAR_LEVEL,

      interview:
        MatchType.INTERVIEW,

      business:
        MatchType.BUSINESS,

      casual:
        MatchType.CASUAL,
    };

    return (
      map[type ?? 'random'] ??
      MatchType.RANDOM
    );
  }

  // ============================================================
  // LOAD CANDIDATES
  // ============================================================

  private async loadCandidates(
    userId: string,
    filters: MatchFilters,
    excluded: Set<string>,
  ): Promise<
    {
      candidate: CandidateProfile;
      history: {
        lastMatchedMinutesAgo:
          | number
          | null;

        timesMatchedToday:
          number;
      };
    }[]
  > {
    // ----------------------------------------------------------
    // Get live users
    // ----------------------------------------------------------

    const liveIds =
      await this.presence.listLiveUserIds();

    this.logger.debug(`[MATCH][TRACE] LIVE_IDS user=${userId} count=${liveIds.length} ids=${liveIds.join(',') || 'NONE'}`);

    if (
      liveIds.length === 0
    ) {
      return [];
    }

    // ----------------------------------------------------------
    // IMPORTANT:
    //
    // Do NOT slice before checking presence.
    //
    // We first find SEARCHING users and ONLY THEN apply
    // maxCandidates.
    //
    // Otherwise AVAILABLE users could consume the candidate
    // slots and prevent real SEARCHING users from being found.
    // ----------------------------------------------------------

    const possibleIds =
      liveIds.filter(
        (id) =>
          id !== userId &&
          !excluded.has(id),
      );

    this.logger.debug(`[MATCH][TRACE] POSSIBLE user=${userId} count=${possibleIds.length} ids=${possibleIds.join(',') || 'NONE'}`);

    if (
      possibleIds.length === 0
    ) {
      return [];
    }

    // ----------------------------------------------------------
    // Read presence
    // ----------------------------------------------------------

    const presenceById =
      new Map<
        string,
        Awaited<
          ReturnType<
            PresenceService['get']
          >
        >
      >();

    await Promise.all(
      possibleIds.map(
        async (id) => {
          const p =
            await this.presence.get(
              id,
            );

          if (p) {
            presenceById.set(
              id,
              p,
            );
          }
        },
      ),
    );

    // ----------------------------------------------------------
    // ONLY SEARCHING USERS
    //
    // AVAILABLE users are intentionally excluded.
    // ----------------------------------------------------------

    const searchingPool =
      possibleIds.filter(
        (id) => {
          const p =
            presenceById.get(id);

          return (
            p?.status ===
              PresenceStatus.SEARCHING &&
            !p.currentCallId
          );
        },
      );

    this.logger.debug(`[MATCH][TRACE] SEARCHING_POOL user=${userId} count=${searchingPool.length} ids=${searchingPool.join(',') || 'NONE'}`);

    if (
      searchingPool.length === 0
    ) {
      return [];
    }

    // ----------------------------------------------------------
    // Apply candidate cap AFTER status filtering
    // ----------------------------------------------------------

    const healthyPool =
      searchingPool.slice(
        0,
        this.maxCandidates,
      );

    // ----------------------------------------------------------
    // Database candidate data
    // ----------------------------------------------------------

    const [
      blocks,
      candidates,
    ] = await Promise.all([
      this.prisma.block.findMany({
        where: {
          OR: [
            {
              blockerId: userId,
              blockedId: {
                in: healthyPool,
              },
            },

            {
              blockedId: userId,
              blockerId: {
                in: healthyPool,
              },
            },
          ],
        },

        select: {
          blockerId: true,
          blockedId: true,
        },
      }),

      this.prisma.user.findMany({
        where: {
          id: {
            in: healthyPool,
          },

          isBanned: false,
        },

        include: {
          profile: {
            include: {
              userInterests: {
                include: {
                  interest: true,
                },
              },
            },
          },
        },
      }),
    ]);

    this.logger.debug(`[MATCH][TRACE] DB_CANDIDATES user=${userId} healthyPool=${healthyPool.length} candidates=${candidates.length} blocks=${blocks.length}`);

    // ----------------------------------------------------------
    // Blocked users
    // ----------------------------------------------------------

    const blockedSet =
      new Set<string>();

    for (const block of blocks) {
      if (
        block.blockerId === userId
      ) {
        blockedSet.add(
          block.blockedId,
        );
      }

      if (
        block.blockedId === userId
      ) {
        blockedSet.add(
          block.blockerId,
        );
      }
    }

    // ----------------------------------------------------------
    // Skip recently attempted pairs
    // ----------------------------------------------------------

    const skipped =
      new Set<string>();

    const now =
      Date.now();

    await Promise.all(
      healthyPool.map(
        async (id) => {
          const when =
            await this.redis.get(
              `${SKIP_KEY_PREFIX}${userId}:${id}`,
            );

          if (
            when &&
            now -
              parseInt(
                when,
                10,
              ) <
              120_000
          ) {
            skipped.add(id);
          }
        },
      ),
    );

    // ----------------------------------------------------------
    // Recent matches
    // ----------------------------------------------------------

    const recentMatches =
      await this.prisma.match.findMany({
        where: {
          OR: [
            {
              userAId: userId,
            },

            {
              userBId: userId,
            },
          ],

          matchedAt: {
            gte:
              new Date(
                now -
                  7 *
                    24 *
                    3600_000,
              ),
          },
        },

        select: {
          userAId: true,
          userBId: true,
          matchedAt: true,
        },
      });

    const lastMatchByPeer =
      new Map<
        string,
        Date
      >();

    const today =
      new Date(now);

    today.setHours(
      0,
      0,
      0,
      0,
    );

    const matchesTodayByPeer =
      new Map<
        string,
        number
      >();

    for (
      const match of recentMatches
    ) {
      const peer =
        match.userAId === userId
          ? match.userBId
          : match.userAId;

      const previous =
        lastMatchByPeer.get(
          peer,
        );

      if (
        !previous ||
        match.matchedAt >
          previous
      ) {
        lastMatchByPeer.set(
          peer,
          match.matchedAt,
        );
      }

      if (
        match.matchedAt >=
        today
      ) {
        matchesTodayByPeer.set(
          peer,
          (
            matchesTodayByPeer.get(
              peer,
            ) ?? 0
          ) + 1,
        );
      }
    }

    // ----------------------------------------------------------
    // Build final candidates
    // ----------------------------------------------------------

    let rejectedBlocked = 0;
    let rejectedSkipped = 0;
    let rejectedNoProfile = 0;
    let rejectedPresence = 0;
    let rejectedFilter = 0;

    const result: {
      candidate: CandidateProfile;
      history: {
        lastMatchedMinutesAgo:
          | number
          | null;

        timesMatchedToday:
          number;
      };
    }[] = [];

    for (
      const candidateUser of candidates
    ) {
      const id =
        candidateUser.id;

      // Blocked
      if (
        blockedSet.has(id)
      ) {
        rejectedBlocked++;
        this.logger.debug(`[MATCH][TRACE] FILTER_BLOCKED user=${userId} candidate=${id}`);
        continue;
      }

      // Recently skipped
      if (
        skipped.has(id)
      ) {
        rejectedSkipped++;
        this.logger.debug(`[MATCH][TRACE] FILTER_SKIPPED user=${userId} candidate=${id}`);
        continue;
      }

      // Banned
      if (
        candidateUser.isBanned
      ) {
        continue;
      }

      // Profile required
      const profile =
        candidateUser.profile;

      if (!profile) {
        rejectedNoProfile++;
        this.logger.debug(`[MATCH][TRACE] FILTER_NO_PROFILE user=${userId} candidate=${id}`);
        continue;
      }

      // --------------------------------------------------------
      // IMPORTANT SECONDARY SAFETY CHECK
      //
      // Presence could have changed after our first read.
      // loadCandidates only selects SEARCHING, but tryReserve
      // performs the final authoritative check under locks.
      // --------------------------------------------------------

      const presence =
        presenceById.get(id);

      if (
        !presence ||
        presence.status !==
          PresenceStatus.SEARCHING ||
        presence.currentCallId
      ) {
        rejectedPresence++;
        this.logger.debug(`[MATCH][TRACE] FILTER_PRESENCE user=${userId} candidate=${id} status=${presence?.status ?? 'NONE'} call=${presence?.currentCallId ?? 'NONE'}`);
        continue;
      }

      const age =
        profile.dateOfBirth &&
        profile.showAge
          ? this.ageFrom(
              new Date(
                profile.dateOfBirth,
              ),
            )
          : null;

      const candidate:
        CandidateProfile = {
        userId: id,

        nativeLanguage:
          profile.nativeLanguage,

        learningLanguage:
          profile.learningLanguage,

        englishLevel:
          profile.englishLevel,

        interests:
          profile.userInterests?.map(
            (ui: any) =>
              ui.interest.name,
          ) ?? [],

        conversationGoals:
          profile.conversationGoals ??
          [],

        gender:
          profile.showGender
            ? profile.gender
            : undefined,

        yearsOld:
          age,

        isBanned:
          candidateUser.isBanned,

        availableSeconds:
          presence.availableSince
            ? (
                Date.now() -
                presence.availableSince
              ) / 1000
            : 0,

        blockedMe: false,

        iBlocked: false,
      };

      const lastMatched =
        lastMatchByPeer.get(
          id,
        );

      const history = {
        lastMatchedMinutesAgo:
          lastMatched
            ? Math.round(
                (
                  Date.now() -
                  lastMatched.getTime()
                ) /
                  60000,
              )
            : null,

        timesMatchedToday:
          matchesTodayByPeer.get(
            id,
          ) ?? 0,
      };

      // --------------------------------------------------------
      // Apply matching filters
      // --------------------------------------------------------

      const filtered =
        filterCandidate(
          candidate,
          filters,
        );

      if (
        !filtered.pass
      ) {
        rejectedFilter++;
        this.logger.debug(`[MATCH][TRACE] FILTER_RULE user=${userId} candidate=${id} result=${JSON.stringify(filtered)}`);
        continue;
      }

      result.push({
        candidate,
        history,
      });
    }

    this.logger.debug(
      `[MATCH][TRACE] FINAL user=${userId} total=${result.length} ids=${result.map((x) => x.candidate.userId).join(',') || 'NONE'} rejected={blocked:${rejectedBlocked},skipped:${rejectedSkipped},noProfile:${rejectedNoProfile},presence:${rejectedPresence},filter:${rejectedFilter}}`,
    );

    return result;
  }

  // ============================================================
  // PEER PROFILE
  // ============================================================

  private async buildPeerProfile(
    _fromUserId: string,
    targetUserId: string,
  ) {
    const target =
      await this.prisma.user.findUnique({
        where: {
          id: targetUserId,
        },

        include: {
          profile: {
            include: {
              userInterests: {
                include: {
                  interest: true,
                },
              },
            },
          },
        },
      });

    const profile =
      target?.profile;

    return {
      id: targetUserId,

      name:
        profile?.name ??
        'Conversation Partner',

      avatar:
        profile?.avatar ??
        null,

      englishLevel:
        profile?.englishLevel ??
        'B1',

      nativeLanguage:
        profile?.nativeLanguage ??
        'Unknown',

      country:
        profile?.country ??
        null,

      interests:
        profile?.userInterests?.map(
          (ui: any) =>
            ui.interest.name,
        ) ?? [],
    };
  }

  // ============================================================
  // AGE
  // ============================================================

  private ageFrom(
    dob: Date,
  ): number {
    const now =
      new Date();

    let age =
      now.getFullYear() -
      dob.getFullYear();

    if (
      now.getMonth() <
        dob.getMonth() ||
      (
        now.getMonth() ===
          dob.getMonth() &&
        now.getDate() <
          dob.getDate()
      )
    ) {
      age--;
    }

    return age;
  }

  // ============================================================
  // MATCH TIMEOUT
  // ============================================================

  private scheduleMatchTimeout(
    userId: string,
  ): void {
    this.clearMatchTimer(
      userId,
    );

    const timer =
      setTimeout(
        async () => {
          // --------------------------------------------------------
          // IMPORTANT:
          //
          // Timeout must use the same per-user lock as tryReserve()
          // and cancel().
          //
          // Without this lock, a timeout can race with a successful
          // reservation and incorrectly move a matched user back to
          // AVAILABLE.
          // --------------------------------------------------------
          const releaseLock =
            await this.redis.acquireLock(
              `${MATCH_LOCK_PREFIX}${userId}`,
              MATCH_LOCK_TTL_SECONDS,
            );

          if (!releaseLock) {
            this.logger.debug(
              `[MATCH] TIMEOUT_LOCK_BUSY user=${userId}`,
            );

            // The reservation/cancellation currently owns the lock.
            // Leave the timer cleared; the competing operation owns
            // the final state.
            this.matchTimers.delete(userId);
            return;
          }

          try {
            const presence =
              await this.presence.get(
                userId,
              );

            // Only timeout an active SEARCHING user.
            if (
              !presence ||
              presence.status !==
                PresenceStatus.SEARCHING
            ) {
              this.matchTimers.delete(userId);
              return;
            }

            // ------------------------------------------------------
            // Remove from matchmaking while the lock is held.
            // ------------------------------------------------------

            await this.removeSearch(
              userId,
            );

            this.matchTimers.delete(
              userId,
            );

            // ------------------------------------------------------
            // SEARCHING -> AVAILABLE
            // ------------------------------------------------------

            await this.presence.upsert(
              userId,
              {
                status:
                  PresenceStatus.AVAILABLE,

                currentCallId:
                  null,

                availableSince:
                  Date.now(),
              },
            );

            await this.events.sendToUser(
              userId,
              'MATCH_TIMEOUT',
              {
                message:
                  'No conversation partner found. Try again in a minute.',
              },
            );

            this.logger.log(
              `[MATCH] TIMEOUT user=${userId} SEARCHING->AVAILABLE`,
            );
          } catch (error) {
            this.logger.error(
              `[MATCH] TIMEOUT_ERROR user=${userId}`,
              error instanceof Error
                ? error.stack
                : String(error),
            );
          } finally {
            await releaseLock();
          }
        },
        this.matchTimeoutSeconds *
          1000,
      );

    timer.unref?.();

    this.matchTimers.set(
      userId,
      timer,
    );
  }

  // ============================================================
  // CLEAR MATCH TIMER
  // ============================================================

  private clearMatchTimer(
    userId: string,
  ): void {
    const existing =
      this.matchTimers.get(
        userId,
      );

    if (existing) {
      clearTimeout(
        existing,
      );

      this.matchTimers.delete(
        userId,
      );
    }
  }
}