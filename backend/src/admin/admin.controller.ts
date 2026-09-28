import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { IsIn, IsInt, IsObject, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { AdminService } from './admin.service';
import { ReportsService } from '../reports/reports.service';

class UserStatusDto {
  @IsIn(['ban', 'unban', 'suspend', 'unsuspend'])
  action!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  days?: number;
}

class ReportReviewDto {
  @IsIn(['REVIEWED', 'RESOLVED', 'DISMISSED'])
  status!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

class SettingsDto {
  @IsObject()
  patch!: Record<string, unknown>;
}

@ApiTags('admin')
@ApiBearerAuth()
@Roles(UserRole.ADMIN, UserRole.MODERATOR)
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly reports: ReportsService,
  ) {}

  @Get('dashboard')
  @ApiOperation({ summary: 'Platform dashboard metrics' })
  dashboard() {
    return this.admin.dashboard();
  }

  @Get('users')
  @ApiOperation({ summary: 'List users with filters' })
  users(
    @Query('q') q?: string,
    @Query('status') status?: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.admin.listUsers({ q, status, page, limit });
  }

  @Get('users/:id')
  @ApiOperation({ summary: 'Full user detail' })
  user(@Param('id') id: string) {
    return this.admin.getUser(id);
  }

  @Post('users/:id/status')
  @HttpCode(200)
  @ApiOperation({ summary: 'Ban, unban, suspend, or unsuspend a user' })
  setStatus(
    @CurrentUser('id') adminId: string,
    @Param('id') id: string,
    @Body() dto: UserStatusDto,
  ) {
    return this.admin.setUserStatus(adminId, id, dto.action as any, {
      reason: dto.reason,
      days: dto.days,
    });
  }

  @Get('calls')
  @ApiOperation({ summary: 'List call sessions' })
  calls(@Query('status') status?: string, @Query('page') page?: number, @Query('limit') limit?: number) {
    return this.admin.listCalls({ status, page, limit });
  }

  @Get('reports')
  @ApiOperation({ summary: 'List reports' })
  listReports(@Query('status') status?: string, @Query('page') page?: number, @Query('limit') limit?: number) {
    return this.reports.findAll({ status, page, limit });
  }

  @Post('reports/:id/review')
  @HttpCode(200)
  @ApiOperation({ summary: 'Review a report' })
  review(@CurrentUser('id') adminId: string, @Param('id') id: string, @Body() dto: ReportReviewDto) {
    return this.reports.review(id, adminId, dto.status as any, dto.note);
  }

  @Get('analytics')
  @ApiOperation({ summary: 'Platform analytics (30d)' })
  analytics() {
    return this.admin.analytics();
  }

  @Get('settings')
  @ApiOperation({ summary: 'Get runtime matchmaking settings' })
  settings() {
    return this.admin.matchmakingSettings();
  }

  @Post('settings')
  @HttpCode(200)
  @ApiOperation({ summary: 'Update runtime matchmaking settings (stored in Redis)' })
  updateSettings(@Body() dto: SettingsDto) {
    return this.admin.updateMatchmakingSettings(dto.patch);
  }
}