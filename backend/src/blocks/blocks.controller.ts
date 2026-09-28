import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { BlockSource, ReportReason } from '@prisma/client';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { BlocksService } from './blocks.service';
import { ReportsService } from '../reports/reports.service';
import { RedisService } from '../redis/redis.service';
import { ApiException } from '../common/errors/api.exception';

class BlockDto {
  @IsOptional()
  @IsIn(['PROFILE', 'DURING_CALL'])
  source?: BlockSource;
}

class ReportUserDto {
  @IsIn(['HARASSMENT', 'ABUSIVE_LANGUAGE', 'SPAM', 'INAPPROPRIATE_BEHAVIOR', 'FAKE_PROFILE', 'OTHER'])
  reason!: ReportReason;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;
}

const REPORT_RATE_KEY = 'rate:report:';

@ApiTags('blocks')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('blocks')
export class BlocksController {
  constructor(
    private readonly blocks: BlocksService,
    private readonly reports: ReportsService,
    private readonly redis: RedisService,
  ) {}

  @Post(':userId')
  @HttpCode(201)
  @ApiOperation({ summary: 'Block a user. Immediately excluded from matchmaking.' })
  async block(@CurrentUser('id') me: string, @Param('userId') userId: string, @Body() dto?: BlockDto) {
    await this.blocks.block(me, userId, dto?.source ?? 'PROFILE');
    return { success: true };
  }

  @Delete(':userId')
  @HttpCode(200)
  async unblock(@CurrentUser('id') me: string, @Param('userId') userId: string) {
    await this.blocks.unblock(me, userId);
    return { success: true };
  }

  @Get()
  @ApiOperation({ summary: 'List users you blocked' })
  async list(@CurrentUser('id') me: string) {
    return { success: true, blocks: await this.blocks.list(me) };
  }

  @Post(':userId/report')
  @HttpCode(201)
  @ApiOperation({ summary: 'Report a user (independent of a call)' })
  async report(
    @CurrentUser('id') me: string,
    @Param('userId') userId: string,
    @Body() dto: ReportUserDto,
  ) {
    const rate = await this.redis.rateLimit(`${REPORT_RATE_KEY}${me}`, 10, 3600);
    if (!rate.allowed) {
      throw new ApiException('RATE_LIMITED', 'Too many reports, please wait', 429);
    }
    const report = await this.reports.create({
      reporterId: me,
      reportedUserId: userId,
      reason: dto.reason,
      description: dto.description,
    });
    // Auto-block on severe reports is a product decision; here we do NOT auto-block.
    return { success: true, report };
  }

  @Get('reports/mine')
  @ApiOperation({ summary: 'My report history' })
  myReports(@CurrentUser('id') me: string) {
    return this.reports.listMine(me);
  }
}