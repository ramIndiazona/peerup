import { Module } from '@nestjs/common';
import { RealtimeGateway } from './realtime.gateway';
import { MatchmakingModule } from '../matchmaking/matchmaking.module';
import { CallsModule } from '../calls/calls.module';

@Module({
  imports: [MatchmakingModule, CallsModule],
  providers: [RealtimeGateway],
  exports: [RealtimeGateway],
})
export class GatewayModule {}