import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';
import { createHmac, timingSafeEqual } from 'crypto';

export const PAYMENT_GATEWAY = 'PAYMENT_GATEWAY';

/**
 * Billing plan selected by the user. The price for each plan is controlled
 * entirely by the backend configuration; the client only chooses the plan.
 */
export type SubscriptionBillingPlan = 'monthly' | 'yearly';

/**
 * Payment details returned by Razorpay.
 */
export interface VerifiedPaymentDetails {
  status: string;
  amount: number;
  currency: string;
}

/**
 * Common interface for payment gateway implementations.
 */
export interface PaymentGateway {
  createCheckout(opts: {
    userId: string;
    plan: SubscriptionBillingPlan;
  }): Promise<{
    orderId: string;
    keyId: string;
    amount: number;
    currency: string;
  }>;

  verifyPayment(opts: {
    orderId: string;
    paymentId: string;
    signature: string;
  }): Promise<boolean>;

  getPaymentStatus(
    paymentId: string,
    expectedOrderId: string,
  ): Promise<VerifiedPaymentDetails>;
}

@Injectable()
export class RazorpayPaymentGateway implements PaymentGateway {
  private readonly razorpay: Razorpay;
  private readonly keyId: string;
  private readonly secret: string;
  private readonly monthlyPrice: number;
  private readonly yearlyPrice: number;

  constructor(private readonly config: ConfigService) {
    const keyId = this.config.get<string>(
      'payment.razorpayKeyId',
    );

    const secret = this.config.get<string>(
      'payment.razorpayKeySecret',
    );

    const monthlyPriceRaw = this.config.get<number>(
      'payment.monthlyPricePaise',
    );
    const yearlyPriceRaw = this.config.get<number>(
      'payment.yearlyPricePaise',
    );

    const monthlyPrice = Number(monthlyPriceRaw);
    const yearlyPrice = Number(yearlyPriceRaw);

    if (!keyId || !secret) {
      throw new Error(
        'Razorpay API credentials are not configured',
      );
    }

    if (
      !Number.isFinite(monthlyPrice) ||
      !Number.isSafeInteger(monthlyPrice) ||
      monthlyPrice <= 0
    ) {
      throw new Error(
        'Invalid Premium monthlyPricePaise',
      );
    }

    if (
      !Number.isFinite(yearlyPrice) ||
      !Number.isSafeInteger(yearlyPrice) ||
      yearlyPrice <= 0
    ) {
      throw new Error(
        'Invalid Premium yearlyPricePaise',
      );
    }

    this.keyId = keyId;
    this.secret = secret;
    this.monthlyPrice = monthlyPrice;
    this.yearlyPrice = yearlyPrice;

    this.razorpay = new Razorpay({
      key_id: this.keyId,
      key_secret: this.secret,
    });
  }

  /**
   * Returns the server-controlled amount (paise) for the selected plan.
   * Never accept the subscription price from the client.
   */
  private amountForPlan(plan: SubscriptionBillingPlan): number {
    return plan === 'yearly' ? this.yearlyPrice : this.monthlyPrice;
  }

  /**
   * Creates a Razorpay order for a Premium subscription.
   *
   * The amount is configured on the backend based on the plan.
   * Never accept the subscription price from the client.
   */
  async createCheckout(opts: {
    userId: string;
    plan: SubscriptionBillingPlan;
  }): Promise<{
    orderId: string;
    keyId: string;
    amount: number;
    currency: string;
  }> {
    if (!opts.userId) {
      throw new BadRequestException(
        'User ID is required',
      );
    }

    const amount = this.amountForPlan(opts.plan);

    const order = await this.razorpay.orders.create({
      amount,
      currency: 'INR',
      receipt: `premium_${Date.now()}`,
      notes: {
        userId: opts.userId,
        plan: opts.plan,
      },
    });

    return {
      orderId: order.id,
      keyId: this.keyId,
      amount: Number(order.amount),
      currency: order.currency,
    };
  }

  /**
   * Verifies the Razorpay checkout signature.
   *
   * Expected signature:
   * HMAC_SHA256(orderId + "|" + paymentId, keySecret)
   */
 async verifyPayment(opts: {
  orderId: string;
  paymentId: string;
  signature: string;
}): Promise<boolean> {
  if (
    !opts.orderId ||
    !opts.paymentId ||
    !opts.signature ||
    !/^[a-f0-9]{64}$/i.test(opts.signature)
  ) {
    return false;
  }

  const expected = createHmac('sha256', this.secret)
    .update(`${opts.orderId}|${opts.paymentId}`)
    .digest();

  const received = Buffer.from(opts.signature, 'hex');

  if (received.length !== expected.length) {
    return false;
  }

  return timingSafeEqual(expected, received);
}
  /**
   * Fetches payment details directly from Razorpay.
   *
   * Verifies that the payment belongs to the expected order.
   * The subscription service must additionally verify
   * the status, amount, and currency before granting access.
   */
  async getPaymentStatus(
    paymentId: string,
    expectedOrderId: string,
  ): Promise<VerifiedPaymentDetails> {
    if (!paymentId || !expectedOrderId) {
      throw new BadRequestException(
        'Payment ID and order ID are required',
      );
    }

    try {
      const payment =
        await this.razorpay.payments.fetch(paymentId);

      if (payment.order_id !== expectedOrderId) {
        throw new BadRequestException(
          'PAYMENT_ORDER_MISMATCH',
        );
      }

      return {
        status: payment.status,
        amount: Number(payment.amount),
        currency: payment.currency,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new InternalServerErrorException(
        'Unable to verify payment status with Razorpay',
      );
    }
  }
}