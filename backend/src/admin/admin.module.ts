import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { ReportsService } from '../reports/reports.service';

@Module({
  controllers: [AdminController],
  providers: [AdminService, ReportsService],
})
export class AdminModule {}