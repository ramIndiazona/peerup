import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn, IsString, IsUrl, Matches } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { SubscriptionService } from './subscriptions.service';
import { UsageService } from './usage.service';


class VerifyPaymentDto {
  @IsString()
  @Matches(/^order_[A-Za-z0-9]+$/)
  razorpay_order_id!: string;

  @IsString()
  @Matches(/^pay_[A-Za-z0-9]+$/)
  razorpay_payment_id!: string;

  @IsString()
  @Matches(/^[a-fA-F0-9]{64}$/)
  razorpay_signature!: string;
}

class PurchaseSubscriptionDto {
  @IsString()
  @IsIn(['monthly', 'yearly'], { message: 'plan must be monthly or yearly' })
  plan!: 'monthly' | 'yearly';
}

@ApiTags('subscriptions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('subscriptions')
export class SubscriptionsController {
  constructor(
    private readonly subscriptions: SubscriptionService,
    private readonly usage: UsageService,
  ) { }

  @Get('me')
  @ApiOperation({ summary: 'My subscription plan and entitlements' })
  async me(@CurrentUser('id') userId: string) {
    return { success: true, ...(await this.subscriptions.status(userId)) };
  }

  @Get('usage')
  @ApiOperation({ summary: 'My daily usage counters and limits' })
  async myUsage(@CurrentUser('id') userId: string) {
    return { success: true, ...(await this.usage.getUsage(userId)) };
  }

  @Post('purchase')
  @HttpCode(200)
  @ApiOperation({ summary: 'Create a Razorpay Premium payment order' })
  purchase(
    @CurrentUser('id') userId: string,
    @Body() dto: PurchaseSubscriptionDto,
  ) {
    return this.subscriptions.purchasePremium(userId, dto.plan);
  }
  @Post('verify-payment')
  @HttpCode(200)
  @ApiOperation({ summary: 'Verify payment and activate Premium' })
  verifyPayment(
    @CurrentUser('id') userId: string,
    @Body() dto: VerifyPaymentDto,
  ) {
    return this.subscriptions.verifyPayment(userId, dto);
  }

  @Post('cancel')
  @HttpCode(200)
  @ApiOperation({ summary: 'Cancel premium plan' })
  cancel(@CurrentUser('id') userId: string) {
    return this.subscriptions.cancelPlan(userId);
  }
}