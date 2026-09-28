import { Injectable, Logger } from '@nestjs/common';
import { UserStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { ApiException, conflict, unauthorized } from '../common/errors/api.exception';
import { LoginDto, RegisterDto } from './dto/auth.dto';
import { TokenService } from './token.service';

const LOGIN_RATE_KEY = 'rate:login:';
const REGISTER_RATE_KEY = 'rate:register:';

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  expiresInSeconds: number;
  tokenType: 'Bearer';
  user: {
    id: string;
    email: string;
    name: string;
    role: string;
    onboardingCompleted: boolean;
    avatar: string | null;
  };
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    private readonly redis: RedisService,
  ) {}

  async register(dto: RegisterDto, meta: { ip?: string; userAgent?: string }): Promise<AuthResult> {
    const rate = await this.redis.rateLimit(
      `${REGISTER_RATE_KEY}${meta.ip ?? 'unknown'}`,
      10,
      3600,
    );
    if (!rate.allowed) {
      throw new ApiException('RATE_LIMITED', 'Too many registration attempts', 429);
    }

    const existing = await this.prisma.user.findFirst({
      where: { OR: [{ email: dto.email }, ...(dto.phone ? [{ phone: dto.phone }] : [])] },
      select: { id: true },
    });
    if (existing) {
      throw conflict('EMAIL_TAKEN', 'An account with this email already exists');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        phone: dto.phone ?? null,
        passwordHash,
        status: UserStatus.OFFLINE,
        profile: {
          create: {
            name: dto.name,
            avatar: dto.avatar ?? null,
            gender: dto.gender ?? 'PREFER_NOT_TO_SAY',
            englishLevel: dto.englishLevel ?? 'B1',
          },
        },
      },
      include: { profile: true },
    });

    return this.issueTokens(user.id, true);
  }

  async login(dto: LoginDto, meta: { ip?: string; userAgent?: string }): Promise<AuthResult> {
    const rate = await this.redis.rateLimit(
      `${LOGIN_RATE_KEY}${meta.ip ?? 'unknown'}:${dto.email}`,
      10,
      900,
    );
    if (!rate.allowed) {
      throw new ApiException('RATE_LIMITED', 'Too many login attempts, try later', 429);
    }

    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
      include: { profile: true },
    });
    if (!user) {
      throw unauthorized('INVALID_CREDENTIALS', 'Invalid email or password');
    }
    if (user.isBanned) {
      throw new ApiException('ACCOUNT_BANNED', 'This account is suspended', 403);
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw unauthorized('INVALID_CREDENTIALS', 'Invalid email or password');
    }

    return this.issueTokens(user.id, false);
  }

  async refresh(refreshToken: string): Promise<Pick<AuthResult, 'accessToken' | 'expiresInSeconds' | 'tokenType'>> {
    const payload = await this.tokens.verifyRefresh(refreshToken);
    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user) {
      throw unauthorized('ACCOUNT_NOT_FOUND', 'Account no longer exists');
    }
    if (user.isBanned) {
      throw new ApiException('ACCOUNT_BANNED', 'This account is suspended', 403);
    }
    const accessToken = this.tokens.signAccess({
      sub: user.id,
      email: user.email,
      role: user.role,
      isBanned: user.isBanned,
    });
    return {
      accessToken,
      expiresInSeconds: this.tokens.getAccessExpirySeconds(),
      tokenType: 'Bearer',
    };
  }

  async logout(userId: string, refreshToken?: string): Promise<{ success: true }> {
    if (refreshToken) {
      // Rotate device version so the presented refresh token is instantly dead.
      await this.tokens.resetSessionVersion(userId);
    }
    // Mark offline in presence if present.
    await this.prisma.user.update({
      where: { id: userId },
      data: { status: UserStatus.OFFLINE, lastSeenAt: new Date() },
    });
    return { success: true };
  }

  async silentUserForTests(): Promise<void> {
    // placeholder removed
  }

  private async issueTokens(userId: string, _initial: boolean): Promise<AuthResult> {
    await this.tokens.resetSessionVersion(userId);
    const version = await this.tokens.currentVersion(userId);

    const identity = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { profile: true },
    });

    const accessToken = this.tokens.signAccess({
      sub: identity.id,
      email: identity.email,
      role: identity.role,
      isBanned: identity.isBanned,
    });
    const refreshToken = this.tokens.signRefresh({
      sub: identity.id,
      version,
      type: 'refresh',
    });

    const result = {
      accessToken,
      refreshToken,
      expiresInSeconds: this.tokens.getAccessExpirySeconds(),
      tokenType: 'Bearer' as const,
      user: {
        id: identity.id,
        email: identity.email,
        name: identity.profile?.name ?? identity.email,
        avatar: identity.profile?.avatar ?? null,
        role: identity.role,
        onboardingCompleted: identity.profile?.onboardingCompleted ?? false,
      },
    };
    this.logger.debug(`Issued tokens for ${userId}`);
    return result;
  }
}