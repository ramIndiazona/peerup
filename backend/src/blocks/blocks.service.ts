import { Injectable } from '@nestjs/common';
import { BlockSource } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { conflict, notFound } from '../common/errors/api.exception';

@Injectable()
export class BlocksService {
  constructor(private readonly prisma: PrismaService) {}

  async block(blockerId: string, blockedId: string, source: BlockSource = 'PROFILE') {
    if (blockerId === blockedId) {
      throw conflict('CANNOT_BLOCK_SELF', 'You cannot block yourself');
    }
    const target = await this.prisma.user.findUnique({
      where: { id: blockedId },
      select: { id: true },
    });
    if (!target) throw notFound('USER_NOT_FOUND', 'User not found');

    const existing = await this.prisma.block.findUnique({
      where: { blockerId_blockedId: { blockerId, blockedId } },
    });
    if (existing) return { success: true, alreadyBlocked: true };

    await this.prisma.block.create({
      data: { blockerId, blockedId, source },
    });
    return { success: true };
  }

  async unblock(blockerId: string, blockedId: string) {
    await this.prisma.block.deleteMany({
      where: { blockerId, blockedId },
    });
    return { success: true };
  }

  async list(blockerId: string) {
    const blocks = await this.prisma.block.findMany({
      where: { blockerId },
      orderBy: { createdAt: 'desc' },
      include: {
        blocked: {
          select: {
            id: true,
            profile: { select: { name: true, avatar: true, englishLevel: true } },
          },
        },
      },
    });
    return blocks;
  }

  async isBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    const count = await this.prisma.block.count({
      where: { blockerId, blockedId },
    });
    return count > 0;
  }
}