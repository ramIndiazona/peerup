import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, JwtSignOptions } from '@nestjs/jwt';
import { RedisService } from '../redis/redis.service';

const REFRESH_VERSION_KEY = 'auth:refresh:version:';

export interface AccessTokenPayload {
  sub: string;
  email: string;
  role: string;
  isBanned: boolean;
}

export interface RefreshTokenPayload {
  sub: string;
  version: number;
  type: 'refresh';
}

@Injectable()
export class TokenService {
  private readonly accessSecret: string;
  private readonly refreshSecret: string;
  private readonly accessExpiresIn: string;
  private readonly refreshExpiresIn: number;
  private readonly issuer: string;

  constructor(
    private readonly jwt: JwtService,
    private readonly redis: RedisService,
    config: ConfigService,
  ) {
    this.accessSecret = config.getOrThrow<string>('jwt.secret');
    this.refreshSecret = config.getOrThrow<string>('jwt.refreshSecret');
    this.accessExpiresIn = config.get<string>('jwt.expiresIn', '15m');
    this.refreshExpiresIn = this.parseDuration(
      config.get<string>('jwt.refreshExpiresIn', '30d'),
    );
    this.issuer = config.get<string>('jwt.issuer', 'peerup');
  }

  private parseDuration(value: string): number {
    const match = /^(\d+)([smhd])$/.exec(value.trim());
    if (!match) return 30 * 24 * 60 * 60;
    const mult = { s: 1, m: 60, h: 3600, d: 86400 }[match[2] as 's'];
    return parseInt(match[1], 10) * mult;
  }

  signAccess(payload: AccessTokenPayload): string {
    return this.jwt.sign(payload, {
      secret: this.accessSecret,
      expiresIn: this.accessExpiresIn as JwtSignOptions['expiresIn'],
      issuer: this.issuer,
    });
  }

  signRefresh(payload: RefreshTokenPayload): string {
    return this.jwt.sign(payload, {
      secret: this.refreshSecret,
      expiresIn: this.refreshExpiresIn,
      issuer: this.issuer,
    });
  }

  verifyAccess(token: string): AccessTokenPayload {
    try {
      return this.jwt.verify<AccessTokenPayload>(token, {
        secret: this.accessSecret,
        issuer: this.issuer,
      });
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }

  async verifyRefresh(token: string): Promise<RefreshTokenPayload> {
    let payload: RefreshTokenPayload;
    try {
      payload = this.jwt.verify<RefreshTokenPayload>(token, {
        secret: this.refreshSecret,
        issuer: this.issuer,
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
    const version = await this.getRefreshVersion(payload.sub);
    if (version !== payload.version) {
      throw new UnauthorizedException('Refresh token revoked');
    }
    return payload;
  }

  getAccessExpirySeconds(): number {
    const match = /^(\d+)([smhd])$/.exec(this.accessExpiresIn);
    if (!match) return 900;
    const mult = { s: 1, m: 60, h: 3600, d: 86400 }[match[2] as 's'];
    return parseInt(match[1], 10) * mult;
  }

  getRefreshExpirySeconds(): number {
    return this.refreshExpiresIn;
  }

  async resetSessionVersion(userId: string): Promise<{ version: number }> {
    const version = await this.getRefreshVersion(userId);
    const next = version + 1;
    await this.redis.set(
      `${REFRESH_VERSION_KEY}${userId}`,
      String(next),
      this.refreshExpiresIn + 86400,
    );
    return { version: next };
  }

  async currentVersion(userId: string): Promise<number> {
    return this.getRefreshVersion(userId);
  }

  private async getRefreshVersion(userId: string): Promise<number> {
    const raw = await this.redis.get(`${REFRESH_VERSION_KEY}${userId}`);
    return raw ? parseInt(raw, 10) : 0;
  }
}