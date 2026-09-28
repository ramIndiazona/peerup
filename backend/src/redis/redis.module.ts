import { Global, Module, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import { RedisService } from './redis.service';
import { REDIS_CLIENT } from './redis.constants';

@Global()
@Module({
  providers: [
    {
      provide: REDIS_CLIENT,
      inject: [ConfigService],
      useFactory: (config: ConfigService): Redis => {
        return new Redis(config.getOrThrow<string>('redis.url'), {
          lazyConnect: false,
          maxRetriesPerRequest: 5,
          enableReadyCheck: true,
          retryStrategy: (times) => Math.min(times * 200, 2000),
        });
      },
    },
    RedisService,
  ],
  exports: [RedisService],
})
export class RedisModule implements OnModuleInit, OnModuleDestroy {
  constructor(private readonly redis: RedisService) {}

  onModuleInit(): void {}

  async onModuleDestroy(): Promise<void> {
    await this.redis.quit();
  }
}