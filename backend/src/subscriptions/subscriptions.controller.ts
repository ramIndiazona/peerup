import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsString, IsUrl } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { SubscriptionService } from './subscriptions.service';
import { UsageService } from './usage.service';

class PurchaseDto {
  @IsUrl({ require_tld: false })
  successUrl!: string;

  @IsUrl({ require_tld: false })
  cancelUrl!: string;
}

@ApiTags('subscriptions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('subscriptions')
export class SubscriptionsController {
  constructor(
    private readonly subscriptions: SubscriptionService,
    private readonly usage: UsageService,
  ) {}

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
  @ApiOperation({ summary: 'Begin premium purchase flow (returns checkout or trial)' })
  purchase(@CurrentUser('id') userId: string, @Body() dto: PurchaseDto) {
    return this.subscriptions.purchasePremium(userId, dto);
  }

  @Post('cancel')
  @HttpCode(200)
  @ApiOperation({ summary: 'Cancel premium plan' })
  cancel(@CurrentUser('id') userId: string) {
    return this.subscriptions.cancelPlan(userId);
  }
}