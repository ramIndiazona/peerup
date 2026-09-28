import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export type AuthedUser = {
  id: string;
  sub: string;
  email: string;
  role: string;
  isBanned?: boolean;
};

export const CurrentUser = createParamDecorator(
  (data: keyof AuthedUser | undefined, ctx: ExecutionContext) => {
    const req = ctx.switchToHttp().getRequest<{ user: AuthedUser }>();
    const user = req.user;
    return data ? user?.[data] : user;
  },
);

export type AuthedRequestUser = AuthedUser;