import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsBoolean, IsOptional } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { LiveService } from './live.service';

class StartLiveDto {
  @IsOptional()
  @IsBoolean()
  available?: boolean;
}

@ApiTags('live')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('live')
export class LiveController {
  constructor(private readonly live: LiveService) {}

  @Get('count')
  @HttpCode(200)
  @ApiOperation({ summary: 'Number of users currently live' })
  async count() {
    return { success: true, ...(await this.live.getLiveCount()) };
  }

  @Post('start')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mark the current user as available/live' })
  async start(@CurrentUser('id') userId: string, @Body() dto?: StartLiveDto) {
    return { success: true, ...(await this.live.start(userId)) };
  }

  @Post('stop')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mark the current user as offline' })
  async stop(@CurrentUser('id') userId: string) {
    return { success: true, ...(await this.live.stop(userId)) };
  }
}