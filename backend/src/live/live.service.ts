import { Injectable } from '@nestjs/common';
import { PresenceService } from '../presence/presence.service';

@Injectable()
export class LiveService {
  constructor(private readonly presence: PresenceService) {}

  async getLiveCount(): Promise<{ count: number }> {
    const count = await this.presence.getLiveCount();
    return { count };
  }

  async start(userId: string, socketId?: string): Promise<{ live: boolean; count: number }> {
    await this.presence.availability(userId, true, socketId);
    const count = await this.presence.getLiveCount();
    return { live: true, count };
  }

  async stop(userId: string): Promise<{ live: boolean; count: number }> {
    await this.presence.setOffline(userId);
    const count = await this.presence.getLiveCount();
    return { live: false, count };
  }
}