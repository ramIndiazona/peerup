import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CallEndReason, ReportReason } from '@prisma/client';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CallsService } from './calls.service';
import { ReportsService } from '../reports/reports.service';

class EndCallDto {
  @IsOptional()
  @IsIn(['USER_HANGUP'])
  reason?: string;
}

class ReportCallDto {
  @IsIn(Object.values(ReportReason))
  reason!: ReportReason;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;
}

@ApiTags('calls')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('calls')
export class CallsController {
  constructor(
    private readonly calls: CallsService,
    private readonly reports: ReportsService,
  ) {}

  @Get(':id')
  @ApiOperation({ summary: 'Get current call session (participants only)' })
  get(@Param('id') id: string, @CurrentUser('id') userId: string) {
    return this.calls.getCall(id, userId);
  }

  @Post(':id/end')
  @HttpCode(200)
  @ApiOperation({ summary: 'End this call (participants only)' })
  async end(@Param('id') id: string, @CurrentUser('id') userId: string) {
    await this.calls.endCall(id, userId);
    return { success: true, callId: id };
  }

  @Post(':id/report')
  @HttpCode(201)
  @ApiOperation({ summary: 'Report the peer of this call' })
  async report(
    @Param('id') callId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: ReportCallDto,
  ) {
    const call = await this.calls.getCall(callId, userId);
    const report = await this.reports.create({
      reporterId: userId,
      reportedUserId: call.peerId as string,
      callId,
      reason: dto.reason,
      description: dto.description,
    });
    return { success: true, report };
  }
}