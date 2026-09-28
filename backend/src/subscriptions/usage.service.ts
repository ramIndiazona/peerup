import { Injectable, Logger } from '@nestjs/common';
import { SubscriptionPlan, UsageKind, User } from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { ApiException } from '../common/errors/api.exception';

const USAGE_KEY = 'usage:';
const USAGE_LOCK = 'usage:lock:';

export interface UsageLimits {
  dailyVoiceCalls: number;
  dailyAIConversations: number;
  dailyAISeconds: number;
}

@Injectable()
export class UsageService {
  private readonly logger = new Logger(UsageService.name);
  private readonly freeLimits: UsageLimits;
  private readonly premiumLimits: UsageLimits;

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    config: ConfigService,
  ) {
    this.freeLimits = {
      dailyVoiceCalls: config.get<number>('limits.dailyVoiceCalls', 20),
      dailyAIConversations: config.get<number>('limits.dailyAIConversations', 100),
      dailyAISeconds: config.get<number>('limits.dailyAISeconds', 1800),
    };
    this.premiumLimits = {
      dailyVoiceCalls: this.freeLimits.dailyVoiceCalls,
      dailyAIConversations: config.get<number>('limits.premiumDailyAIConversations', 50),
      dailyAISeconds: config.get<number>('limits.premiumDailyAISeconds', 7200),
    };
  }

  async getPlan(userId: string): Promise<SubscriptionPlan> {
    const sub = await this.prisma.subscription.findUnique({ where: { userId } });
    if (sub && sub.plan === SubscriptionPlan.PREMIUM && sub.status === 'ACTIVE') {
      return SubscriptionPlan.PREMIUM;
    }
    return SubscriptionPlan.FREE;
  }

  async getUserTz(userId: string): Promise<string> {
    const profile = await this.prisma.profile.findUnique({
      where: { userId },
      select: { timeZone: true },
    });
    return profile?.timeZone ?? 'UTC';
  }

  private todayForTz(tz: string): string {
    // date-fns style formatting kept dependency free
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: tz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date());
    const map: Record<string, string> = {};
    for (const p of parts) map[p.type] = p.value;
    return `${map.year}-${map.month}-${map.day}`;
  }

  private usageKey(userId: string, kind: UsageKind, date: string): string {
    return `${USAGE_KEY}${userId}:${kind}:${date}`;
  }

  private limitsFor(plan: SubscriptionPlan): UsageLimits {
    return plan === SubscriptionPlan.PREMIUM ? this.premiumLimits : this.freeLimits;
  }

  private limitFor(plan: SubscriptionPlan, kind: UsageKind): number {
    const limits = this.limitsFor(plan);
    if (kind === UsageKind.VOICE_CALL) return limits.dailyVoiceCalls;
    if (kind === UsageKind.AI_CONVERSATION) return limits.dailyAIConversations;
    return limits.dailyAISeconds;
  }

  async checkAndIncrement(
    userId: string,
    kind: UsageKind,
    amount = 1,
  ): Promise<{ allowed: boolean; used: number; limit: number; remaining: number }> {
    const plan = await this.getPlan(userId);
    const limit = this.limitFor(plan, kind);
    const date = this.todayForTz(await this.getUserTz(userId));
    const key = this.usageKey(userId, kind, date);

    // Atomic increment under lock avoids double-counting concurrent calls.
    const lock = await this.redis.acquireLock(`${USAGE_LOCK}${key}`, 10);
    try {
      const used = await this.redis.incrBy(key, amount);
      if (used === amount) {
        // First use today: expire at ~72h so the key self-cleans.
        await this.redis.expire(key, 72 * 3600);
      }
      const allowed = used <= limit;
      // Persist to PG asynchronously for analytics (best effort).
      void this.persistUsage(userId, key, kind, date, used).catch((err) =>
        this.logger.warn(`usage persist failed: ${(err as Error).message}`),
      );
      return {
        allowed,
        used,
        limit,
        remaining: Math.max(0, limit - used),
      };
    } finally {
      if (lock) await lock();
    }
  }

  async getUsage(userId: string) {
    const plan = await this.getPlan(userId);
    const tz = await this.getUserTz(userId);
    const date = this.todayForTz(tz);
    const kinds = Object.values(UsageKind);
    const rows = await Promise.all(
      kinds.map(async (kind) => {
        const limit = this.limitFor(plan, kind);
        const raw = await this.redis.get(this.usageKey(userId, kind, date));
        const used = raw ? parseInt(raw, 10) : 0;
        return { kind, used, limit, remaining: Math.max(0, limit - used) };
      }),
    );
    return { plan, date: { value: date, timeZone: tz }, limits: rows };
  }

  private async persistUsage(
    userId: string,
    _key: string,
    kind: UsageKind,
    date: string,
    value: number,
  ): Promise<void> {
    await this.prisma.usage.upsert({
      where: { userId_date_kind: { userId, date, kind } },
      update: { value },
      create: { userId, date, kind, value },
    });
  }
}