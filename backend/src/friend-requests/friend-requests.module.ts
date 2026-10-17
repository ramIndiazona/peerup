import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { EventsModule } from '../realtime/events.module';
import { FriendRequestsController } from './friend-requests.controller';
import { FriendRequestsService } from './friend-requests.service';

@Module({
  imports: [PrismaModule, EventsModule],
  controllers: [FriendRequestsController],
  providers: [FriendRequestsService],
  exports: [FriendRequestsService],
})
export class FriendRequestsModule {}