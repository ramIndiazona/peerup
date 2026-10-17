
import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Post,
  Query,
  DefaultValuePipe,
} from '@nestjs/common';

import { ConversationsService } from './conversations.service';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { SendMessageDto } from './dto/send-message.dto';

import { UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from 'src/common/guards/jwt-auth.guard';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';

@Controller('conversations')
@UseGuards(JwtAuthGuard)
export class ConversationsController {
  constructor(
    private readonly conversationsService: ConversationsService,
  ) {}

  /**
   * Create a conversation with an accepted friend,
   * or return the existing conversation.
   *
   * POST /conversations
   * Body: { "friendId": "UUID" }
   */
  @Post()
  createConversation(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateConversationDto,
  ) {
    return this.conversationsService.createConversation(
      userId,
      dto.friendId,
    );
  }

  /**
   * Get all conversations for the logged-in user.
   *
   * GET /conversations
   */
  @Get()
  listConversations(@CurrentUser('id') userId: string) {
    return this.conversationsService.listConversations(userId);
  }

  /**
   * Send a message in an existing conversation.
   *
   * POST /conversations/:conversationId/messages
   * Body: { "content": "Hello!" }
   */
  @Post(':conversationId/messages')
  sendMessage(
    @CurrentUser('id') userId: string,
    @Param('conversationId', ParseUUIDPipe)
    conversationId: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.conversationsService.sendMessage(
      userId,
      conversationId,
      dto.content,
    );
  }

  /**
   * Retrieve persisted chat history.
   *
   * GET /conversations/:conversationId/messages?limit=50&before=ISO_DATE
   */
  @Get(':conversationId/messages')
  getMessages(
    @CurrentUser('id') userId: string,
    @Param('conversationId', ParseUUIDPipe)
    conversationId: string,
    @Query('limit', new DefaultValuePipe(50), ParseIntPipe)
    limit: number,
    @Query('before')
    before?: string,
  ) {
    return this.conversationsService.getMessages(
      userId,
      conversationId,
      limit,
      before,
    );
  }
}
