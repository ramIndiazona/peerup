import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PresenceService, PresenceStatus } from '../presence/presence.service';
import { RedisService } from '../redis/redis.service';
import { notFound } from '../common/errors/api.exception';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly presence: PresenceService,
    private readonly redis: RedisService,
  ) {}

  async dashboard() {
    const now = new Date();
    const todayStart = new Date(now);
    todayStart.setHours(0, 0, 0, 0);
    const last24h = new Date(now.getTime() - 24 * 3600_000);

    const [
      totalUsers,
      active24h,
      liveUsers,
      activeCalls,
      callsToday,
      aiToday,
      reportsPending,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { lastSeenAt: { gte: last24h } } }),
      this.presence.listLiveUserIds().then((ids) => ids.length),
      this.prisma.callSession.count({
        where: { status: { in: ['MATCHED', 'SIGNALING', 'CONNECTING', 'CONNECTED'] } },
      }),
      this.prisma.callSession.count({ where: { startedAt: { gte: todayStart } } }),
      this.prisma.aISession.count({ where: { createdAt: { gte: todayStart } } }),
      this.prisma.report.count({ where: { status: 'PENDING' } }),
    ]);

    const avgDuration = await this.prisma.callSession.aggregate({
      where: { status: 'ENDED', duration: { not: null } },
      _avg: { duration: true },
    });

    return {
      totalUsers,
      active24h,
      liveUsers,
      activeCalls,
      callsToday,
      averageCallDurationSeconds: Math.round(avgDuration._avg.duration ?? 0),
      aiConversationsToday: aiToday,
      reportsPending,
    };
  }

  async listUsers(query: { q?: string; status?: string; page?: number; limit?: number }) {
    const where: Prisma.UserWhereInput = {};
    if (query.status) {
      const statusMap: Record<string, Prisma.UserWhereInput> = {
        banned: { isBanned: true },
        live: { status: { in: ['AVAILABLE', 'SEARCHING', 'IN_CALL'] } },
        suspended: { suspendedUntil: { gt: new Date() } },
      };
      Object.assign(where, statusMap[query.status]);
    }
    if (query.q) {
      where.OR = [
        { email: { contains: query.q, mode: 'insensitive' } },
        { profile: { name: { contains: query.q, mode: 'insensitive' } } },
      ];
    }
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, 100);
    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: { profile: { select: { name: true, avatar: true, englishLevel: true, country: true } } },
      }),
      this.prisma.user.count({ where }),
    ]);
    return { items, total, page, limit };
  }

  async getUser(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: {
        profile: { include: { userInterests: { include: { interest: true } } } },
        subscriptions: true,
        callsAsA: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
    if (!user) throw notFound('USER_NOT_FOUND', 'User not found');
    return user;
  }

  async setUserStatus(
    adminId: string,
    userId: string,
    action: 'ban' | 'unban' | 'suspend' | 'unsuspend',
    opts?: { reason?: string; days?: number },
  ) {
    const target = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!target) throw notFound('USER_NOT_FOUND', 'User not found');

    if (action === 'ban') {
      await this.prisma.user.update({
        where: { id: userId },
        data: { isBanned: true, banReason: opts?.reason ?? 'Banned by admin' },
      });
      await this.presence.setOffline(userId);
    } else if (action === 'unban') {
      await this.prisma.user.update({
        where: { id: userId },
        data: { isBanned: false, banReason: null },
      });
    } else if (action === 'suspend') {
      const until = new Date();
      until.setDate(until.getDate() + (opts?.days ?? 7));
      await this.prisma.user.update({
        where: { id: userId },
        data: { suspendedUntil: until },
      });
      await this.presence.setOffline(userId);
    } else {
      await this.prisma.user.update({
        where: { id: userId },
        data: { suspendedUntil: null },
      });
    }

    await this.prisma.report.updateMany({
      where: { reportedUserId: userId, status: 'PENDING' },
      data: { status: 'RESOLVED', resolvedBy: adminId, resolvedAt: new Date() },
    });

    return { success: true, action, userId };
  }

  async listCalls(query: { status?: string; page?: number; limit?: number }) {
    const where: Prisma.CallSessionWhereInput = query.status
      ? { status: query.status as any }
      : {};
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, 100);
    const [items, total] = await Promise.all([
      this.prisma.callSession.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          userA: { select: { id: true, email: true, profile: { select: { name: true } } } },
          userB: { select: { id: true, email: true, profile: { select: { name: true } } } },
        },
      }),
      this.prisma.callSession.count({ where }),
    ]);
    return { items, total, page, limit };
  }

  async analytics() {
    const now = new Date();
    const since = new Date(now.getTime() - 30 * 24 * 3600_000);

    const callsByDay = await this.prisma.callSession.groupBy({
      by: ['createdAt'],
      where: { createdAt: { gte: since } },
      _count: { id: true },
      orderBy: { createdAt: 'asc' },
      take: 30,
    });

    const calls = await this.prisma.callSession.findMany({
      where: { createdAt: { gte: since }, status: 'ENDED' },
      select: { duration: true, endReason: true },
    });

    const failuresByReason = new Map<string, number>();
    let totalDuration = 0;
    let connected = 0;
    for (const c of calls) {
      if (c.duration) totalDuration += c.duration;
      if ((c.duration ?? 0) > 0) connected += 1;
      if (c.endReason) failuresByReason.set(c.endReason, (failuresByReason.get(c.endReason) ?? 0) + 1);
    }

    const aiSessions = await this.prisma.aISession.count({ where: { createdAt: { gte: since } } });

    return {
      callsByDay,
      connectedCalls: connected,
      totalCalls: calls.length,
      avgDurationSeconds: calls.length ? Math.round(totalDuration / calls.length) : 0,
      endReasonBreakdown: Object.fromEntries(failuresByReason),
      aiSessions,
    };
  }

  async matchmakingSettings(): Promise<Record<string, unknown>> {
    return (await this.redis.getJson<Record<string, unknown>>('admin:matchmaking:settings')) ?? {};
  }

  async updateMatchmakingSettings(patch: Record<string, unknown>) {
    const existing = (await this.redis.getJson<Record<string, unknown>>('admin:matchmaking:settings')) ?? {};
    const next = { ...existing, ...patch };
    await this.redis.setJson('admin:matchmaking:settings', next);
    return next;
  }
}