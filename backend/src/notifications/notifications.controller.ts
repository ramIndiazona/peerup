import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

class DeviceTokenDto {
  @IsString()
  token!: string;

  @IsOptional()
  @IsIn(['ios', 'android', 'web'])
  platform?: string;
}

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post('device-token')
  @HttpCode(201)
  @ApiOperation({ summary: 'Register a device token for push' })
  registerDevice(@CurrentUser('id') userId: string, @Body() dto: DeviceTokenDto) {
    return this.notifications.registerDeviceToken(userId, dto.token, dto.platform ?? 'ios');
  }

  @Get()
  @ApiOperation({ summary: 'List my notifications' })
  list(
    @CurrentUser('id') userId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.notifications.listMine(userId, Number(page ?? 1), Math.min(Number(limit ?? 20), 50));
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark notification as read' })
  async read(@CurrentUser('id') userId: string, @Param('id') id: string) {
    await this.notifications.markRead(userId, id);
    return { success: true };
  }
}