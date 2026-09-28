import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { User } from '@prisma/client';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../prisma/prisma.service';
import { ApiException } from '../common/errors/api.exception';
import { AccessTokenPayload } from './token.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('jwt.secret'),
      issuer: config.get<string>('jwt.issuer', 'peerup'),
    });
  }

  async validate(payload: AccessTokenPayload): Promise<{ id: string; email: string; role: string; isBanned: boolean }> {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        id: true,
        email: true,
        role: true,
        isBanned: true,
        suspendedUntil: true,
        status: true,
      },
    });

    if (!user) {
      throw new ApiException('UNAUTHORIZED', 'Account no longer exists', 401);
    }

    const suspended = user.suspendedUntil && user.suspendedUntil > new Date();

    return {
      id: user.id,
      email: user.email,
      role: user.role,
      isBanned: user.isBanned || Boolean(suspended),
    };
  }
}