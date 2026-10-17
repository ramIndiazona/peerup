
import { Module } from '@nestjs/common';

import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';

import { PrismaModule } from '../prisma/prisma.module';
import { EventsModule } from '../realtime/events.module';

@Module({
  imports: [PrismaModule, EventsModule],
  controllers: [ConversationsController],
  providers: [ConversationsService],
  exports: [ConversationsService],
})
export class ConversationsModule {}
