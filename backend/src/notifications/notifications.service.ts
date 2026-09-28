import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Push delivery wrapper. Uses firebase-admin messaging when FIREBASE_ENABLED.
 * Always persists an in-app Notification row.
 */
@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly enabled: boolean;
  private admin: any = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    this.enabled = this.config.get<boolean>('firebase.enabled', false);
  }

  async onModuleInit(): Promise<void> {
    if (!this.enabled) {
      this.logger.warn('FCM disabled. Set FIREBASE_ENABLED=true to enable push.');
      return;
    }
    try {
      const admin = await import('firebase-admin');
      if (!admin.apps?.length) {
        admin.initializeApp({
          credential: admin.credential.cert({
            projectId: this.config.get<string>('firebase.projectId'),
            clientEmail: this.config.get<string>('firebase.clientEmail'),
            privateKey: this.config
              .get<string>('firebase.privateKey')
              ?.replace(/\\n/g, '\n'),
          }),
        });
      }
      this.admin = admin;
      this.logger.log('FCM initialized');
    } catch (err) {
      this.logger.error(`FCM init failed: ${(err as Error).message}`);
    }
  }

  async registerDeviceToken(userId: string, token: string, platform: string) {
    const device = await this.prisma.deviceToken.upsert({
      where: { token },
      update: { userId, platform },
      create: { userId, token, platform },
    });
    return device;
  }

  async notify(
    userId: string,
    opts: {
      type: NotificationType;
      title: string;
      body: string;
      data?: Record<string, unknown>;
    },
  ): Promise<void> {
    await this.prisma.notification.create({
      data: {
        userId,
        type: opts.type,
        title: opts.title,
        body: opts.body,
        data: (opts.data ?? undefined) as Prisma.InputJsonValue | undefined,
      },
    });

    if (!this.enabled || !this.admin) return;
    try {
      const devices = await this.prisma.deviceToken.findMany({
        where: { userId },
        select: { token: true, platform: true },
      });
      await Promise.all(
        devices.map(async (d) => {
          const message = {
            token: d.token,
            notification: { title: opts.title, body: opts.body },
            data: this.flattenData(opts.data ?? {}),
            android: { priority: 'high' as const },
            apns: { headers: { 'apns-priority': '10' } },
          };
          await this.admin.messaging().send(message);
        }),
      );
    } catch (err) {
      this.logger.warn(`FCM send failed: ${(err as Error).message}`);
    }
  }

  async listMine(userId: string, page = 1, limit = 20) {
    const [items, total] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.notification.count({ where: { userId } }),
    ]);
    return { items, total };
  }

  async markRead(userId: string, id: string) {
    return this.prisma.notification.updateMany({
      where: { id, userId },
      data: { readAt: new Date() },
    });
  }

  private flattenData(data: Record<string, unknown>): Record<string, string> {
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(data)) {
      out[k] = typeof v === 'string' ? v : JSON.stringify(v);
    }
    return out;
  }
}