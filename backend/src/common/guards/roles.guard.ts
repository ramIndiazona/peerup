import {
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';
import { ApiException } from '../errors/api.exception';
import { ROLES_KEY } from '../decorators/roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredRoles || requiredRoles.length === 0) return true;

    const req = context.switchToHttp().getRequest<{ user?: { role?: UserRole; isBanned?: boolean } }>();
    const user = req.user;

    if (!user) {
      throw new ApiException('UNAUTHORIZED', 'Unauthorized', 401);
    }
    if (user.isBanned) {
      throw new ApiException('ACCOUNT_BANNED', 'Account is suspended', 403);
    }
    if (!requiredRoles.includes(user.role as UserRole)) {
      throw new ApiException('FORBIDDEN', 'Insufficient permissions', 403);
    }
    return true;
  }
}