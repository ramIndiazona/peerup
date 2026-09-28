import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SubscriptionsController } from './subscriptions.controller';
import { SubscriptionService } from './subscriptions.service';
import { UsageService } from './usage.service';
import { PAYMENT_GATEWAY, paymentGatewayFactory } from './payment.provider';

@Module({
  controllers: [SubscriptionsController],
  providers: [
    SubscriptionService,
    UsageService,
    {
      provide: PAYMENT_GATEWAY,
      inject: [ConfigService],
      useFactory: paymentGatewayFactory,
    },
  ],
  exports: [SubscriptionService, UsageService],
})
export class SubscriptionsModule {}