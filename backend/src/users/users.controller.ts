import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UpdateProfileDto } from './dto/profile.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Current user profile' })
  async getMe(@CurrentUser('id') userId: string) {
    return { success: true, user: await this.users.getMe(userId) };
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update current user profile' })
  async updateMe(@CurrentUser('id') userId: string, @Body() dto: UpdateProfileDto) {
    return { success: true, user: await this.users.updateProfile(userId, dto) };
  }

  @Get('interests')
  @ApiOperation({ summary: 'Available interest tags' })
  interests() {
    return this.users.listAvailableInterests();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Public profile of another user' })
  async getById(@CurrentUser('id') viewer: string, @Param('id') id: string) {
    return { success: true, profile: await this.users.getPublicProfile(viewer, id) };
  }
}