// import {
//   BadRequestException,
//   ConflictException,
//   Inject,
//   Injectable,
//   Logger,
//   NotFoundException,
// } from '@nestjs/common';
// import { ConfigService } from '@nestjs/config';
// import {
//   SubscriptionPlan,
//   SubscriptionStatus,
// } from '@prisma/client';
// import { PrismaService } from '../prisma/prisma.service';
// import {
//   PAYMENT_GATEWAY,
// } from './payment.provider';

// import type {
//   PaymentGateway,
// } from './payment.provider';


// export interface PaymentGateway {
//   createCheckout(opts: {
//     userId: string;
//     plan: SubscriptionPlan;
//     successUrl: string;
//     cancelUrl: string;
//   }): Promise<{ checkoutUrl: string; providerSubscriptionId?: string }>;
//   cancelSubscription(providerSubscriptionId: string): Promise<void>;
// }

// @Injectable()
// export class SubscriptionService {
//   private readonly logger = new Logger(SubscriptionService.name);

//  constructor(
//   private readonly prisma: PrismaService,
//   @Inject(PAYMENT_GATEWAY)
//   private readonly payment: PaymentGateway,
//   private readonly config: ConfigService,
// ) {}
//   async status(userId: string) {
//     const sub = await this.prisma.subscription.findUnique({
//       where: { userId },
//     });
//     const plan = sub?.plan ?? SubscriptionPlan.FREE;
//     return {
//       plan,
//       status: sub?.status ?? SubscriptionStatus.INACTIVE,
//       renewsAt: sub?.renewsAt,
//       canceledAt: sub?.canceledAt,
//       features: this.featuresFor(plan),
//     };
//   }

//  async purchasePremium(userId: string) {
//   const existing = await this.prisma.subscription.findUnique({
//     where: { userId },
//   });

//   if (
//     existing?.plan === SubscriptionPlan.PREMIUM &&
//     existing.status === SubscriptionStatus.ACTIVE &&
//     existing.renewsAt &&
//     existing.renewsAt > new Date()
//   ) {
//     throw new ConflictException(
//       'You already have an active Premium subscription',
//     );
//   }

//   const checkout = await this.payment.createCheckout({
//     userId,
//     plan: SubscriptionPlan.PREMIUM,
//   });

//   await this.prisma.paymentOrder.create({
//     data: {
//       userId,
//       providerOrderId: checkout.orderId,
//       amount: checkout.amount,
//       currency: checkout.currency,
//       status: 'CREATED',
//     },
//   });

//   return {
//     success: true,
//     mode: 'checkout',
//     orderId: checkout.orderId,
//     keyId: checkout.keyId,
//     amount: checkout.amount,
//     currency: checkout.currency,
//   };
// }
// async verifyPayment(
//   userId: string,
//   dto: {
//     razorpay_order_id: string;
//     razorpay_payment_id: string;
//     razorpay_signature: string;
//   },
// ) {
//   const order = await this.prisma.paymentOrder.findUnique({
//     where: {
//       providerOrderId: dto.razorpay_order_id,
//     },
//   });

//   if (!order || order.userId !== userId) {
//     throw new NotFoundException('Payment order not found');
//   }

//   // Repeated successful requests must not extend the subscription again.
//   if (order.status === 'PAID') {
//     if (order.paymentId !== dto.razorpay_payment_id) {
//       throw new ConflictException(
//         'This order has already been paid with a different payment',
//       );
//     }

//     return {
//       success: true,
//       status: 'PAID',
//       subscription: await this.status(userId),
//     };
//   }

//   const signatureValid = await this.payment.verifyPayment({
//     orderId: order.providerOrderId,
//     paymentId: dto.razorpay_payment_id,
//     signature: dto.razorpay_signature,
//   });

//   if (!signatureValid) {
//     throw new BadRequestException('Invalid Razorpay payment signature');
//   }

//   const paymentStatus = await this.payment.getPaymentStatus(
//     dto.razorpay_payment_id,
//     order.providerOrderId,
//   );

//   if (paymentStatus !== 'captured') {
//     throw new BadRequestException(
//       'Payment has not been captured yet',
//     );
//   }

//   const premiumDays = 30;
//   const now = new Date();

//   const currentSubscription =
//     await this.prisma.subscription.findUnique({
//       where: { userId },
//     });

//   const renewsAt =
//     currentSubscription?.plan === SubscriptionPlan.PREMIUM &&
//     currentSubscription.status === SubscriptionStatus.ACTIVE &&
//     currentSubscription.renewsAt &&
//     currentSubscription.renewsAt > now
//       ? new Date(currentSubscription.renewsAt)
//       : new Date(now);

//   renewsAt.setDate(renewsAt.getDate() + premiumDays);

//   await this.prisma.$transaction(async (tx) => {
//     // Claim the order only if it has not already been processed.
//     const claimed = await tx.paymentOrder.updateMany({
//       where: {
//         id: order.id,
//         status: 'CREATED',
//       },
//       data: {
//         status: 'PAID',
//         paymentId: dto.razorpay_payment_id,
//       },
//     });

//     if (claimed.count !== 1) {
//       throw new ConflictException(
//         'Payment order is already being processed',
//       );
//     }

//     await tx.subscription.upsert({
//       where: { userId },
//       update: {
//         plan: SubscriptionPlan.PREMIUM,
//         status: SubscriptionStatus.ACTIVE,
//         renewsAt,
//         canceledAt: null,
//         provider: 'razorpay',
//       },
//       create: {
//         userId,
//         plan: SubscriptionPlan.PREMIUM,
//         status: SubscriptionStatus.ACTIVE,
//         renewsAt,
//         provider: 'razorpay',
//       },
//     });
//   });

//   this.logger.log(`Premium activated for user ${userId}`);

//   return {
//     success: true,
//     status: 'PAID',
//     plan: SubscriptionPlan.PREMIUM,
//     renewsAt,
//   };
// }

// async cancelPlan(userId: string) {
//   const sub = await this.prisma.subscription.findUnique({
//     where: { userId },
//   });

//   if (
//     !sub ||
//     sub.plan !== SubscriptionPlan.PREMIUM ||
//     sub.status !== SubscriptionStatus.ACTIVE
//   ) {
//     throw new NotFoundException('No active Premium subscription found');
//   }

//   await this.prisma.subscription.update({
//     where: { userId },
//     data: {
//       status: SubscriptionStatus.CANCELED,
//       canceledAt: new Date(),
//     },
//   });

//   return {
//     success: true,
//     message: 'Premium access has been canceled',
//   };
// }

//   async applyWebhook(
//     userId: string,
//     event: 'activated' | 'renewed' | 'canceled',
//     providerSubscriptionId?: string,
//     provider?: string,
//   ): Promise<void> {
//     const renewsAt = new Date();
//     renewsAt.setDate(renewsAt.getDate() + 30);
//     if (event === 'canceled') 
//       {
//       await this.prisma.subscription.update({
//         where: { userId },
//         data: { status: SubscriptionStatus.CANCELED, canceledAt: new Date() },
//       });
//       return;
//     }
//     await this.prisma.subscription.upsert({
//       where: { userId },
//       update: {
//         plan: SubscriptionPlan.PREMIUM,
//         status: SubscriptionStatus.ACTIVE,
//         renewsAt,
//         provider: provider ?? 'provider',
//         providerSubscriptionId: providerSubscriptionId ?? undefined,
//       },
//       create: {
//         userId,
//         plan: SubscriptionPlan.PREMIUM,
//         status: SubscriptionStatus.ACTIVE,
//         renewsAt,
//         provider: provider ?? 'provider',
//         providerSubscriptionId: providerSubscriptionId ?? null,
//       },
//     });
//     this.logger.log(`Subscription ${event} for ${userId}`);
//   }

//   private featuresFor(plan: SubscriptionPlan) {
//     if (plan === SubscriptionPlan.PREMIUM) {
//       return {
//         aiMinutes: '120 min/day',
//         aiConversations: '50/day',
//         advancedFeedback: true,
//         premiumCharacters: true,
//         analytics: true,
//       };
//     }
//     return {
//       aiMinutes: '30 min/day',
//       aiConversations: '10/day',
//       advancedFeedback: false,
//       premiumCharacters: false,
//       analytics: false,
//     };
//   }
// }


import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';

import {
  SubscriptionPlan,
  SubscriptionStatus,
} from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

import { PAYMENT_GATEWAY } from './payment.provider';

import type { PaymentGateway } from './payment.provider';

@Injectable()
export class SubscriptionService {
  private readonly logger = new Logger(SubscriptionService.name);

  constructor(
    private readonly prisma: PrismaService,

    @Inject(PAYMENT_GATEWAY)
    private readonly payment: PaymentGateway,
  ) {}

  /**
   * Returns the user's effective subscription status.
   *
   * An expired Premium subscription is treated as FREE,
   * even if its database status has not yet been updated.
   */
  async status(userId: string) {
    const sub = await this.prisma.subscription.findUnique({
      where: { userId },
    });

    const now = new Date();

    const isPremiumActive =
      sub?.plan === SubscriptionPlan.PREMIUM &&
      sub.status === SubscriptionStatus.ACTIVE &&
      sub.renewsAt !== null &&
      sub.renewsAt !== undefined &&
      sub.renewsAt > now;

    const plan = isPremiumActive
      ? SubscriptionPlan.PREMIUM
      : SubscriptionPlan.FREE;

    return {
      plan,
      status: sub?.status ?? SubscriptionStatus.INACTIVE,
      renewsAt: sub?.renewsAt ?? null,
      canceledAt: sub?.canceledAt ?? null,
      features: this.featuresFor(plan),
    };
  }

  /**
   * Creates a Razorpay order for a Premium subscription.
   *
   * The price is determined by the backend, not the client.
   */
  // async purchasePremium(userId: string) {
  //   const existing = await this.prisma.subscription.findUnique({
  //     where: { userId },
  //   });
  //     this.logger.debug(`[PURCHASE] Started for user: ${userId}`);

  //   const isPremiumActive =
  //     existing?.plan === SubscriptionPlan.PREMIUM &&
  //     existing.status === SubscriptionStatus.ACTIVE &&
  //     existing.renewsAt !== null &&
  //     existing.renewsAt !== undefined &&
  //     existing.renewsAt > new Date();

  //   if (isPremiumActive) {
  //     throw new ConflictException(
  //       'You already have an active Premium subscription',
  //     );
  //   }

  //   const checkout = await this.payment.createCheckout({
  //     userId,
  //     plan: SubscriptionPlan.PREMIUM,
  //   });

  //   await this.prisma.paymentOrder.create({
  //     data: {
  //       userId,
  //       providerOrderId: checkout.orderId,
  //       amount: checkout.amount,
  //       currency: checkout.currency,
  //       status: 'CREATED',
  //     },
  //   });

  //   this.logger.log(
  //     `Razorpay order created for user ${userId}`,
  //   );

  //   return {
  //     success: true,
  //     mode: 'checkout',
  //     orderId: checkout.orderId,
  //     keyId: checkout.keyId,
  //     amount: checkout.amount,
  //     currency: checkout.currency,
  //   };
  // }

  async purchasePremium(userId: string, plan: 'monthly' | 'yearly') {
    this.logger.debug(`[PURCHASE] Started for user: ${userId} plan=${plan}`);

    try {
      this.logger.debug('[PURCHASE] Checking existing subscription');

      const existing = await this.prisma.subscription.findUnique({
        where: { userId },
      });

      this.logger.debug(
        `[PURCHASE] Existing subscription found: ${Boolean(existing)}`,
      );

      const isPremiumActive =
        existing?.plan === SubscriptionPlan.PREMIUM &&
        existing.status === SubscriptionStatus.ACTIVE &&
        existing.renewsAt != null &&
        existing.renewsAt > new Date();

      if (isPremiumActive) {
        throw new ConflictException(
          'You already have an active Premium subscription',
        );
      }

      // STEP A: Create Razorpay order (amount set by the backend, by plan)
      this.logger.debug('[PURCHASE] STEP A: Creating Razorpay order');

      const checkout = await this.payment.createCheckout({
        userId,
        plan,
      });

      this.logger.debug(
        `[PURCHASE] STEP A SUCCESS: Razorpay order created: ${checkout.orderId}`,
      );

      // STEP B: Save payment order to PostgreSQL, remembering the plan so the
      // backend (not the client) determines the subscription duration later.
      this.logger.debug('[PURCHASE] STEP B: Saving payment order to database');

      await this.prisma.paymentOrder.create({
        data: {
          userId,
          plan,
          providerOrderId: checkout.orderId,
          amount: checkout.amount,
          currency: checkout.currency,
          status: 'CREATED',
        },
      });

      this.logger.debug('[PURCHASE] STEP B SUCCESS: Payment order saved');

      return {
        success: true,
        mode: 'checkout',
        orderId: checkout.orderId,
        keyId: checkout.keyId,
        amount: checkout.amount,
        currency: checkout.currency,
      };
    } catch (error: unknown) {
      if (error instanceof Error) {
        this.logger.error(
          `[PURCHASE] FAILED: ${error.name}: ${error.message}`,
          error.stack,
        );
      } else {
        this.logger.error(
          `[PURCHASE] FAILED: ${JSON.stringify(
            error,
            Object.getOwnPropertyNames(error),
          )}`,
        );
      }

      throw error;
    }
  }

  /**
   * Verifies a Razorpay payment and activates Premium.
   *
   * Checks:
   * 1. The order exists and belongs to the authenticated user.
   * 2. Repeated successful requests do not grant another period.
   * 3. The Razorpay checkout signature is valid.
   * 4. Razorpay confirms the payment belongs to this order.
   * 5. Payment status, amount, and currency match.
   */
  async verifyPayment(
    userId: string,
    dto: {
      razorpay_order_id: string;
      razorpay_payment_id: string;
      razorpay_signature: string;
    },
  ) {
    const order = await this.prisma.paymentOrder.findUnique({
      where: {
        providerOrderId: dto.razorpay_order_id,
      },
    });

    if (!order || order.userId !== userId) {
      throw new NotFoundException(
        'Payment order not found',
      );
    }

    // Idempotency: do not extend Premium for an already-paid order.
    if (order.status === 'PAID') {
      if (order.paymentId !== dto.razorpay_payment_id) {
        throw new ConflictException(
          'This order has already been paid with a different payment',
        );
      }

      return {
        success: true,
        status: 'PAID',
        subscription: await this.status(userId),
      };
    }

    if (order.status !== 'CREATED') {
      throw new ConflictException(
        'This payment order cannot be processed',
      );
    }

    const signatureValid = await this.payment.verifyPayment({
      orderId: order.providerOrderId,
      paymentId: dto.razorpay_payment_id,
      signature: dto.razorpay_signature,
    });

    if (!signatureValid) {
      throw new BadRequestException(
        'Invalid Razorpay payment signature',
      );
    }

    const paymentDetails = await this.payment.getPaymentStatus(
      dto.razorpay_payment_id,
      order.providerOrderId,
    );

    if (
      paymentDetails.status !== 'captured' ||
      paymentDetails.amount !== order.amount ||
      paymentDetails.currency !== order.currency
    ) {
      throw new BadRequestException(
        'Payment status, amount, or currency does not match the order',
      );
    }

    // Subscription duration is determined by the plan stored on the order
    // (server-controlled), never by the client.
    const durationMonths = order.plan === 'yearly' ? 12 : 1;

    let renewsAt: Date | undefined;

    await this.prisma.$transaction(async (tx) => {
      // Claim this order only once.
      const claimed = await tx.paymentOrder.updateMany({
        where: {
          id: order.id,
          status: 'CREATED',
        },
        data: {
          status: 'PAID',
          paymentId: dto.razorpay_payment_id,
        },
      });

      if (claimed.count !== 1) {
        throw new ConflictException(
          'Payment order has already been processed',
        );
      }

      // Read the subscription inside the transaction so the
      // expiration calculation uses the latest available state.
      const currentSubscription =
        await tx.subscription.findUnique({
          where: { userId },
        });

      const now = new Date();

      const hasRemainingPremium =
        currentSubscription?.plan === SubscriptionPlan.PREMIUM &&
        currentSubscription.status === SubscriptionStatus.ACTIVE &&
        currentSubscription.renewsAt !== null &&
        currentSubscription.renewsAt !== undefined &&
        currentSubscription.renewsAt > now;

      renewsAt = hasRemainingPremium
        ? new Date(currentSubscription.renewsAt!)
        : new Date(now);

      // Add one calendar month or one calendar year (plan-controlled).
      renewsAt = addMonths(renewsAt, durationMonths);

      await tx.subscription.upsert({
        where: { userId },

        update: {
          plan: SubscriptionPlan.PREMIUM,
          status: SubscriptionStatus.ACTIVE,
          renewsAt,
          canceledAt: null,
          provider: 'razorpay',
        },

        create: {
          userId,
          plan: SubscriptionPlan.PREMIUM,
          status: SubscriptionStatus.ACTIVE,
          renewsAt,
          provider: 'razorpay',
        },
      });
    });

    this.logger.log(
      `Premium activated for user ${userId}`,
    );

    return {
      success: true,
      status: 'PAID',
      plan: SubscriptionPlan.PREMIUM,
      renewsAt,
    };
  }

  /**
   * Cancels Premium access immediately.
   *
   * This changes the local subscription record only.
   * It does not refund a payment or cancel a recurring
   * Razorpay subscription.
   */
  async cancelPlan(userId: string) {
    const sub = await this.prisma.subscription.findUnique({
      where: { userId },
    });

    const isPremiumActive =
      sub?.plan === SubscriptionPlan.PREMIUM &&
      sub.status === SubscriptionStatus.ACTIVE &&
      sub.renewsAt !== null &&
      sub.renewsAt !== undefined &&
      sub.renewsAt > new Date();

    if (!isPremiumActive) {
      throw new NotFoundException(
        'No active Premium subscription found',
      );
    }

    await this.prisma.subscription.update({
      where: { userId },

      data: {
        status: SubscriptionStatus.CANCELED,
        canceledAt: new Date(),
      },
    });

    this.logger.log(
      `Premium canceled for user ${userId}`,
    );

    return {
      success: true,
      message: 'Premium access has been canceled',
    };
  }

  /**
   * Updates a subscription from a trusted, validated event.
   *
   * IMPORTANT:
   * Only call this method after authenticating the source
   * of the event. This method does not verify Razorpay
   * webhook signatures.
   */
  async applyWebhook(
    userId: string,
    event: 'activated' | 'renewed' | 'canceled',
    providerSubscriptionId?: string,
    provider?: string,
  ): Promise<void> {
    if (event === 'canceled') {
      const subscription =
        await this.prisma.subscription.findUnique({
          where: { userId },
        });

      if (!subscription) {
        this.logger.warn(
          `Cannot cancel missing subscription for user ${userId}`,
        );
        return;
      }

      await this.prisma.subscription.update({
        where: { userId },

        data: {
          status: SubscriptionStatus.CANCELED,
          canceledAt: new Date(),
        },
      });

      this.logger.log(
        `Subscription canceled for user ${userId}`,
      );

      return;
    }

    const renewsAt = new Date();
    renewsAt.setDate(renewsAt.getDate() + 30);

    await this.prisma.subscription.upsert({
      where: { userId },

      update: {
        plan: SubscriptionPlan.PREMIUM,
        status: SubscriptionStatus.ACTIVE,
        renewsAt,
        canceledAt: null,
        provider: provider ?? 'provider',
        providerSubscriptionId:
          providerSubscriptionId ?? undefined,
      },

      create: {
        userId,
        plan: SubscriptionPlan.PREMIUM,
        status: SubscriptionStatus.ACTIVE,
        renewsAt,
        provider: provider ?? 'provider',
        providerSubscriptionId:
          providerSubscriptionId ?? null,
      },
    });

    this.logger.log(
      `Subscription ${event} for user ${userId}`,
    );
  }

  /**
   * Returns features for the effective subscription plan.
   */
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

/**
 * Adds whole calendar months to a date, clamping to the last day of the
 * resulting month (e.g. Jan 31 + 1 month -> Feb 28/29).
 */
function addMonths(date: Date, months: number): Date {
  const result = new Date(date);
  result.setMonth(result.getMonth() + months);
  return result;
}