import {
  Body,
  Controller,
  HttpCode,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { StorageService } from './storage.service';

class UploadAvatarDto {
  contentType!: string;
}

@ApiTags('storage')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('storage')
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  @Post('avatar')
  @HttpCode(200)
  @ApiOperation({ summary: 'Upload an avatar (raw body bytes / base64 JSON below)' })
  async avatar(@CurrentUser('id') userId: string, @Body() dto: { contentType?: string; base64?: string }) {
    if (!dto.base64) {
      return { success: false, message: 'Provide base64 image data' };
    }
    const buffer = Buffer.from(dto.base64, 'base64');
    if (buffer.byteLength > 5 * 1024 * 1024) {
      return { success: false, message: 'Image too large (max 5MB)' };
    }
    const { url, key } = await this.storage.upload(
      `users/${userId}/avatar`,
      buffer,
      dto.contentType ?? 'image/jpeg',
    );
    return { success: true, url, key };
  }
}