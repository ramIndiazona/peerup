import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { notFound } from '../common/errors/api.exception';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: Prisma.ReportUncheckedCreateInput) {
    const reportedUser = await this.prisma.user.findUnique({
      where: { id: data.reportedUserId },
      select: { id: true },
    });
    if (!reportedUser) throw notFound('USER_NOT_FOUND', 'Reported user not found');

    // Rate-limit reports per reporter (max 10 / hour tracked in Redis by caller).
    return this.prisma.report.create({
      data: {
        reporterId: data.reporterId,
        reportedUserId: data.reportedUserId,
        callId: data.callId ?? null,
        reason: data.reason,
        description: data.description,
      },
    });
  }

  async listMine(reporterId: string) {
    return this.prisma.report.findMany({
      where: { reporterId },
      orderBy: { createdAt: 'desc' },
      include: { call: { select: { id: true, status: true, duration: true } } },
    });
  }

  async review(reportId: string, moderatorId: string, status: 'REVIEWED' | 'RESOLVED' | 'DISMISSED', note?: string) {
    return this.prisma.report.update({
      where: { id: reportId },
      data: {
        status,
        moderationNote: note,
        resolvedBy: moderatorId,
        resolvedAt: new Date(),
      },
    });
  }

  async findAll(query: { status?: string; page?: number; limit?: number }) {
    const where: Prisma.ReportWhereInput = query.status
      ? { status: query.status as any }
      : {};
    const page = query.page ?? 1;
    const limit = Math.min(query.limit ?? 20, 100);
    const [items, total] = await Promise.all([
      this.prisma.report.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          reporter: { select: { id: true, email: true, profile: { select: { name: true } } } },
          reportedUser: { select: { id: true, email: true, profile: { select: { name: true } } } },
          call: { select: { id: true, status: true, duration: true, startedAt: true } },
        },
      }),
      this.prisma.report.count({ where }),
    ]);
    return { items, total, page, limit };
  }
}