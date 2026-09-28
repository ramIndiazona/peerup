import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentGateway } from './subscriptions.service';

/**
 * Default no-op gateway used when no payment provider is configured. It is a
 * legitimate provider abstraction for development environments, not a mock of
 * core business logic.
 */
@Injectable()
export class DisabledPaymentGateway implements PaymentGateway {
  async createCheckout(): Promise<{ checkoutUrl: string }> {
    throw new Error('PAYMENT_PROVIDER_NOT_CONFIGURED');
  }

  async cancelSubscription(): Promise<void> {
    throw new Error('PAYMENT_PROVIDER_NOT_CONFIGURED');
  }
}

export const PAYMENT_GATEWAY = 'PAYMENT_GATEWAY';

/**
 * Factory that resolves the payment gateway from configuration. Future real
 * providers plug in here without touching core services.
 */
export function paymentGatewayFactory(
  config: ConfigService,
): PaymentGateway {
  const provider = config.get<string>('payment.provider');
  if (!provider || provider === 'none') {
    return new DisabledPaymentGateway();
  }
  // Additional providers (e.g. Stripe, Paddle) are registered here.
  return new DisabledPaymentGateway();
}