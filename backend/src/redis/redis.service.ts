import { Inject, Injectable, Logger } from '@nestjs/common';
import Redis, { Cluster } from 'ioredis';
import { REDIS_CLIENT } from './redis.constants';

export interface WithTtl<T> {
  value: T;
}

@Injectable()
export class RedisService {
  private readonly logger = new Logger(RedisService.name);
  constructor(@Inject(REDIS_CLIENT) private readonly client: Redis) {}

  get raw(): Redis {
    return this.client;
  }

  async ping(): Promise<string> {
    return this.client.ping();
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<'OK'> {
    if (ttlSeconds) {
      return this.client.set(key, value, 'EX', ttlSeconds);
    }
    return this.client.set(key, value);
  }

  async setJson(key: string, value: unknown, ttlSeconds?: number): Promise<'OK'> {
    return this.set(key, JSON.stringify(value), ttlSeconds);
  }

  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  async getJson<T>(key: string): Promise<T | null> {
    const raw = await this.get(key);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as T;
    } catch {
      this.logger.warn(`Invalid JSON in redis key ${key}`);
      return null;
    }
  }

  async del(...keys: string[]): Promise<number> {
    if (keys.length === 0) return 0;
    return this.client.del(...keys);
  }

  async expire(key: string, ttlSeconds: number): Promise<number> {
    return this.client.expire(key, ttlSeconds);
  }

  async ttl(key: string): Promise<number> {
    return this.client.ttl(key);
  }

  async incr(key: string): Promise<number> {
    return this.client.incr(key);
  }

  async incrBy(key: string, by: number): Promise<number> {
    return this.client.incrby(key, by);
  }

  async decr(key: string): Promise<number> {
    return this.client.decr(key);
  }

  // ===================== Sets =====================

  async sadd(key: string, ...members: string[]): Promise<number> {
    if (members.length === 0) return 0;
    return this.client.sadd(key, ...members);
  }

  async srem(key: string, ...members: string[]): Promise<number> {
    if (members.length === 0) return 0;
    return this.client.srem(key, ...members);
  }

  async sismember(key: string, member: string): Promise<number> {
    return this.client.sismember(key, member);
  }

  async smembers(key: string): Promise<string[]> {
    return this.client.smembers(key);
  }

  async scard(key: string): Promise<number> {
    return this.client.scard(key);
  }

  async spop(key: string, count = 1): Promise<string[]> {
    return this.client.spop(key, count);
  }

  // ===================== Sorted Sets =====================

  async zadd(key: string, score: number, member: string): Promise<number> {
    return this.client.zadd(key, score, member);
  }

  async zrem(key: string, ...members: string[]): Promise<number> {
    return this.client.zrem(key, ...members);
  }

  async zrange(
    key: string,
    start: number,
    stop: number,
  ): Promise<string[]> {
    return this.client.zrange(key, start, stop);
  }

  async zscore(key: string, member: string): Promise<string | null> {
    return this.client.zscore(key, member);
  }

  async zcard(key: string): Promise<number> {
    return this.client.zcard(key);
  }

  async zcount(key: string, min: number, max: number): Promise<number> {
    return this.client.zcount(key, min, max);
  }

  async zremrangebyscore(
    key: string,
    min: number,
    max: number,
  ): Promise<number> {
    return this.client.zremrangebyscore(key, min, max);
  }

  // ===================== Distributed lock =====================
  // Returns a release function, or null if the lock could not be acquired.

  async acquireLock(
    key: string,
    ttlSeconds = 30,
  ): Promise<(() => Promise<void>) | null> {
    const token = `${process.pid}-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 10)}`;
    const acquired = await this.client.set(
      `lock:${key}`,
      token,
      'EX',
      ttlSeconds,
      'NX',
    );
    if (acquired !== 'OK') return null;
    return async () => {
      // Only delete if we still hold the token (prevents deleting a lock that
      // expired and was re-acquired by someone else).
      const script = `
        if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
        else
          return 0
        end
      `;
      await this.client.eval(script, 1, `lock:${key}`, token);
    };
  }

  async withLock<T>(
    key: string,
    ttlSeconds: number,
    fn: () => Promise<T>,
  ): Promise<T> {
    const release = await this.acquireLock(key, ttlSeconds);
    if (!release) {
      throw new Error(`LOCK_ACQUIRE_FAILED:${key}`);
    }
    try {
      return await fn();
    } finally {
      await release();
    }
  }

  // ===================== Usage-style counters =====================

  async incrementCounter(key: string, ttlSeconds?: number): Promise<number> {
    const value = await this.client.incr(key);
    if (ttlSeconds && value === 1) {
      await this.client.expire(key, ttlSeconds);
    }
    return value;
  }

  // ===================== Rate limiting (sliding/fixed window) =====================

  async rateLimit(
    key: string,
    limit: number,
    windowSeconds: number,
  ): Promise<{ allowed: boolean; remaining: number; retryAfter: number }> {
    const now = Date.now();
    const windowStart = now - windowSeconds * 1000;
    const pipeline = this.client.pipeline();
    pipeline.zremrangebyscore(key, 0, windowStart);
    pipeline.zadd(key, now, `${now}-${Math.random().toString(36).slice(2, 8)}`);
    pipeline.zcard(key);
    pipeline.expire(key, windowSeconds);
    const results = await pipeline.exec();
    const count = (results?.[2]?.[1] as number) ?? 0;
    const allowed = count <= limit;
    return {
      allowed,
      remaining: Math.max(0, limit - count),
      retryAfter: Math.max(0, Math.ceil((windowStart + windowSeconds * 1000 - now) / 1000)),
    };
  }

  // Neighbor-safe atomic "reserve" for matchmaking candidate claiming.
  // Uses a distinct SET reserved candidate hashes that no lock is needed for.

  async quit(): Promise<void> {
    await this.client.quit();
  }
}