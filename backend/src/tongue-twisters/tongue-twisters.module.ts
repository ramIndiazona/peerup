import { Module } from '@nestjs/common';

import { TongueTwistersController } from './tongue-twisters.controller';
import { TongueTwistersService } from './tongue-twisters.service';
import { PrismaService } from '../prisma/prisma.service';

@Module({
  controllers: [TongueTwistersController],
  providers: [TongueTwistersService, PrismaService],
})
export class TongueTwistersModule {}