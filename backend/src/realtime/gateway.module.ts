import { Module } from '@nestjs/common';
import { RealtimeGateway } from './realtime.gateway';
import { MatchmakingModule } from '../matchmaking/matchmaking.module';
import { CallsModule } from '../calls/calls.module';
import { ConversationsModule } from "../conversations/conversations.module";

@Module({
  imports: [MatchmakingModule, CallsModule, ConversationsModule],
  providers: [RealtimeGateway],
  exports: [RealtimeGateway],
})
export class GatewayModule {}