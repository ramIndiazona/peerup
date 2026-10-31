// import { Module } from '@nestjs/common';
// import { ConfigService } from '@nestjs/config';
// import { SubscriptionsController } from './subscriptions.controller';
// import { SubscriptionService } from './subscriptions.service';
// import { UsageService } from './usage.service';
// import { PAYMENT_GATEWAY, paymentGatewayFactory } from './payment.provider';

// @Module({
//   controllers: [SubscriptionsController],
//   providers: [
//     SubscriptionService,
//     UsageService,
//     {
//       provide: PAYMENT_GATEWAY,
//       inject: [ConfigService],
//       useFactory: paymentGatewayFactory,
//     },
//   ],
//   exports: [SubscriptionService, UsageService],
// })
// export class SubscriptionsModule {}

import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SubscriptionsController } from './subscriptions.controller';
import { SubscriptionService } from './subscriptions.service';
import { UsageService } from './usage.service';
import {
  PAYMENT_GATEWAY,
  RazorpayPaymentGateway,
} from './payment.provider';

@Module({
  controllers: [SubscriptionsController],
  providers: [
    SubscriptionService,
    UsageService,
    {
      provide: PAYMENT_GATEWAY,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const provider = config.get<string>('payment.provider');

        if (provider !== 'razorpay') {
          throw new Error(
            `Unsupported payment provider: ${provider ?? 'none'}`,
          );
        }

        return new RazorpayPaymentGateway(config);
      },
    },
  ],
  exports: [SubscriptionService, UsageService],
})
export class SubscriptionsModule {}

