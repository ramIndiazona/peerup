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
import { IsInt, IsMimeType, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AISessionsService } from './ai-sessions.service';
import { AICharactersService } from './ai-characters.service';

class StartSessionDto {
  @IsOptional()
  @IsString()
  characterId?: string;

  @IsOptional()
  @IsString()
  scenario?: string;
}

class MessageDto {
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  text?: string;

  @IsOptional()
  @IsString()
  audioBase64?: string;

  @IsOptional()
  @IsMimeType()
  mime?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(7200)
  durationSeconds?: number;
}

@ApiTags('ai')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('ai')
export class AIController {
  constructor(
    private readonly sessions: AISessionsService,
    private readonly characters: AICharactersService,
  ) { }

  // @Get('characters')
  // @ApiOperation({ summary: 'List AI characters (premium hidden unless subscribed)' })
  // async charactersList(@CurrentUser('id') _userId: string, @Query('premium') premium?: string) 
  // {
  //   const includePremium = premium === 'true';
  //   return { success: true, characters: await this.characters.list(includePremium)

  //    };
  // }


  @Get('characters')
  @ApiOperation({ summary: 'List all AI characters' })
  async charactersList(@CurrentUser('id') _userId: string) {
    return {
      success: true,
      characters: await this.characters.list(),
    };
  }
  // @Get('scenarios')
  // @ApiOperation({ summary: 'AI scenario categories' })
  // scenarios() {
  //   return { success: true, scenarios: this.characters.scenarios() };
  // }

  @Get('scenarios')
  @ApiOperation({ summary: 'AI scenario categories' })
  async scenarios() {
    return {
      success: true,
      scenarios: await this.characters.scenarios(),
    };
  }

  @Post('sessions')
  @HttpCode(201)
  @ApiOperation({ summary: 'Start an AI conversation session' })
  start(@CurrentUser('id') userId: string, @Body() dto: StartSessionDto) {
    return this.sessions.start(userId, dto);
  }

  @Post('sessions/:id/message')
  @HttpCode(200)
  @ApiOperation({ summary: 'Send a message to the AI (text or audio)' })
  message(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: MessageDto,
  ) {
    return this.sessions.message(userId, id, dto);
  }

  @Post('sessions/:id/end')
  @HttpCode(200)
  @ApiOperation({ summary: 'End an AI session' })
  end(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.sessions.end(userId, id);
  }

  @Get('sessions/:id/feedback')
  @ApiOperation({ summary: 'Get learning feedback for a finished AI session' })
  feedback(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.sessions.feedback(userId, id);
  }
}