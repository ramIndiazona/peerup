import { Module } from '@nestjs/common';
import { CallsController } from './calls.controller';
import { CallsService } from './calls.service';
import { ReportsService } from '../reports/reports.service';

@Module({
  controllers: [CallsController],
  providers: [CallsService, ReportsService],
  exports: [CallsService],
})
export class CallsModule {}