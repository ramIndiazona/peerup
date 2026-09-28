import { Injectable, Module, OnModuleDestroy } from '@nestjs/common';
import { Registry, collectDefaultMetrics } from 'prom-client';
import { PresenceService } from '../presence/presence.service';
import { RedisService } from '../redis/redis.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MetricsService implements OnModuleDestroy {
  private readonly registry: Registry;
  constructor(
    private readonly presence: PresenceService,
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
  ) {
    this.registry = new Registry();
    this.registry.setDefaultLabels({ app: 'peerup-backend' });
    collectDefaultMetrics({ register: this.registry });
  }

  get registryRef() {
    return this.registry;
  }

  async collect(): Promise<string> {
    const liveUsers = await this.presence.getLiveCount().catch(() => 0);
    const queueSizes = await this.redis.raw
      .keys('matchmaking:queue:*')
      .then((keys) =>
        Promise.all(keys.map(async (k) => ({ key: k, size: await this.redis.zcard(k) }))),
      )
      .catch(() => []);

    const callsToday = await this.prisma.callSession
      .count({ where: { createdAt: { gte: new Date(Date.now() - 86400_000) } } })
      .catch(() => 0);

    return this.registry.metrics() +
      `\n# HELP peerup_live_users Number of live users\n# TYPE peerup_live_users gauge\npeerup_live_users ${liveUsers}\n` +
      `# HELP peerup_calls_today Calls created today\n# TYPE peerup_calls_today gauge\npeerup_calls_today ${callsToday}\n` +
      queueSizes
        .map((q) => `peerup_matchmaking_queue{queue="${q.key.replace('matchmaking:queue:', '')}"} ${q.size}`)
        .join('\n');
  }

  onModuleDestroy(): void {
    this.registry.clear();
  }
}

@Injectable()
export class MetricsController {
  constructor(private readonly metricsService: MetricsService) {}

  collect() {
    return this.metricsService.collect();
  }
}

@Module({
  providers: [MetricsService, MetricsController],
  exports: [MetricsService],
})
export class MetricsModule {}