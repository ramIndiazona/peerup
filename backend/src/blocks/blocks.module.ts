import { Module } from '@nestjs/common';
import { BlocksController } from './blocks.controller';
import { BlocksService } from './blocks.service';
import { ReportsService } from '../reports/reports.service';

@Module({
  controllers: [BlocksController],
  providers: [BlocksService, ReportsService],
  exports: [BlocksService, ReportsService],
})
export class BlocksModule {}