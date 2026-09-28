import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SubscriptionPlan, SubscriptionStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PAYMENT_GATEWAY } from './payment.provider';

/**
 * PaymentGateway is the boundary to a payment provider. No provider-specific
 * logic may leak into core services; wiring a real provider only requires an
 * implementation of this interface plus a module import.
 */
export interface PaymentGateway {
  createCheckout(opts: {
    userId: string;
    plan: SubscriptionPlan;
    successUrl: string;
    cancelUrl: string;
  }): Promise<{ checkoutUrl: string; providerSubscriptionId?: string }>;
  cancelSubscription(providerSubscriptionId: string): Promise<void>;
}

@Injectable()
export class SubscriptionService {
  private readonly logger = new Logger(SubscriptionService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(PAYMENT_GATEWAY) private readonly payment: PaymentGateway | null,
    private readonly config: ConfigService,
  ) {}

  async status(userId: string) {
    const sub = await this.prisma.subscription.findUnique({
      where: { userId },
    });
    const plan = sub?.plan ?? SubscriptionPlan.FREE;
    return {
      plan,
      status: sub?.status ?? SubscriptionStatus.INACTIVE,
      renewsAt: sub?.renewsAt,
      canceledAt: sub?.canceledAt,
      features: this.featuresFor(plan),
    };
  }

  async purchasePremium(
    userId: string,
    opts: { successUrl: string; cancelUrl: string },
  ) {
    if (!this.payment) {
      // Provider not configured (dev/local). Grant a premium trial.
      this.logger.warn(`Payment provider not configured - granting trial premium for ${userId}`);
      const expires = new Date();
      expires.setDate(expires.getDate() + 7);
      await this.prisma.subscription.upsert({
        where: { userId },
        update: { plan: SubscriptionPlan.PREMIUM, status: SubscriptionStatus.ACTIVE, renewsAt: expires },
        create: {
          userId,
          plan: SubscriptionPlan.PREMIUM,
          status: SubscriptionStatus.ACTIVE,
          renewsAt: expires,
          provider: 'trial',
        },
      });
      return {
        mode: 'trial' as const,
        premiumDays: 7,
        expiresAt: expires,
      };
    }

    const checkout = await this.payment.createCheckout({
      userId,
      plan: SubscriptionPlan.PREMIUM,
      successUrl: opts.successUrl,
      cancelUrl: opts.cancelUrl,
    });
    return { mode: 'checkout' as const, checkoutUrl: checkout.checkoutUrl };
  }

  async cancelPlan(userId: string) {
    const sub = await this.prisma.subscription.findUnique({ where: { userId } });
    if (sub?.providerSubscriptionId) {
      await this.payment?.cancelSubscription(sub.providerSubscriptionId);
    }
    await this.prisma.subscription.update({
      where: { userId },
      data: { status: SubscriptionStatus.CANCELED, canceledAt: new Date() },
    });
    return { success: true };
  }

  async applyWebhook(
    userId: string,
    event: 'activated' | 'renewed' | 'canceled',
    providerSubscriptionId?: string,
    provider?: string,
  ): Promise<void> {
    const renewsAt = new Date();
    renewsAt.setDate(renewsAt.getDate() + 30);
    if (event === 'canceled') {
      await this.prisma.subscription.update({
        where: { userId },
        data: { status: SubscriptionStatus.CANCELED, canceledAt: new Date() },
      });
      return;
    }
    await this.prisma.subscription.upsert({
      where: { userId },
      update: {
        plan: SubscriptionPlan.PREMIUM,
        status: SubscriptionStatus.ACTIVE,
        renewsAt,
        provider: provider ?? 'provider',
        providerSubscriptionId: providerSubscriptionId ?? undefined,
      },
      create: {
        userId,
        plan: SubscriptionPlan.PREMIUM,
        status: SubscriptionStatus.ACTIVE,
        renewsAt,
        provider: provider ?? 'provider',
        providerSubscriptionId: providerSubscriptionId ?? null,
      },
    });
    this.logger.log(`Subscription ${event} for ${userId}`);
  }

  private featuresFor(plan: SubscriptionPlan) {
    if (plan === SubscriptionPlan.PREMIUM) {
      return {
        aiMinutes: '120 min/day',
        aiConversations: '50/day',
        advancedFeedback: true,
        premiumCharacters: true,
        analytics: true,
      };
    }
    return {
      aiMinutes: '30 min/day',
      aiConversations: '10/day',
      advancedFeedback: false,
      premiumCharacters: false,
      analytics: false,
    };
  }
}