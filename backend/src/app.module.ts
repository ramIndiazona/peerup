import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';

import configuration from './config/configuration';

import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { PresenceModule } from './presence/presence.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { LiveModule } from './live/live.module';
import { MatchmakingModule } from './matchmaking/matchmaking.module';
import { CallsModule } from './calls/calls.module';
import { BlocksModule } from './blocks/blocks.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { AIModule } from './ai/ai.module';
import { AdminModule } from './admin/admin.module';
import { NotificationsModule } from './notifications/notifications.module';
import { StorageModule } from './storage/storage.module';
import { HealthModule } from './health/health.module';
import { MetricsModule } from './metrics/metrics.module';
import { EventsModule } from './realtime/events.module';
import { GatewayModule } from './realtime/gateway.module';

import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      envFilePath: ['.env', '.env.local'],
    }),

    ScheduleModule.forRoot(),

    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: () => ({
        throttlers: [
          {
            name: 'default',
            ttl: 60_000,
            limit: 120,
          },
          {
            name: 'auth',
            ttl: 60_000,
            limit: 20,
          },
        ],
      }),
    }),

    // Serve files from:
    // backend/public/
   

      ServeStaticModule.forRoot({
      rootPath: join(process.cwd(), 'public'),
      serveRoot: '/',
    }),

    PrismaModule,
    RedisModule,
    EventsModule,
    PresenceModule,
    AuthModule,
    UsersModule,
    LiveModule,
    MatchmakingModule,
    CallsModule,
    BlocksModule,
    SubscriptionsModule,
    AIModule,
    AdminModule,
    NotificationsModule,
    StorageModule,
    HealthModule,
    MetricsModule,
    GatewayModule,
  ],

  providers: [
    {
      provide: APP_FILTER,
      useClass: AllExceptionsFilter,
    },
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}