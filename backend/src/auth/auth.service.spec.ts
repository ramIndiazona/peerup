import { AuthService } from './auth.service';
import * as bcrypt from 'bcrypt';

jest.mock('bcrypt', () => ({ hash: jest.fn().mockResolvedValue('hash'), compare: jest.fn().mockResolvedValue(true) }));

describe('AuthService avatar persistence', () => {
  const identity = { id: 'user', email: 'alex@example.com', role: 'USER', isBanned: false, passwordHash: 'hash', profile: { name: 'Alex', avatar: 'avatar_03', onboardingCompleted: false } };
  const prisma = { user: {
    findFirst: jest.fn().mockResolvedValue(null),
    create: jest.fn().mockResolvedValue(identity),
    findUnique: jest.fn().mockResolvedValue(identity),
    findUniqueOrThrow: jest.fn().mockResolvedValue(identity),
  } };
  const tokens = {
    resetSessionVersion: jest.fn(), currentVersion: jest.fn().mockResolvedValue(1),
    signAccess: jest.fn().mockReturnValue('access'), signRefresh: jest.fn().mockReturnValue('refresh'),
    getAccessExpirySeconds: jest.fn().mockReturnValue(900),
  };
  const redis = { rateLimit: jest.fn().mockResolvedValue({ allowed: true }) };
  const service = new AuthService(prisma as any, tokens as any, redis as any);

  it('writes the ID in the existing nested profile creation and returns it with tokens', async () => {
    const result = await service.register({ email: identity.email, password: 'Secret123', name: 'Alex', avatar: 'avatar_03' }, {});
    expect(prisma.user.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ profile: { create: expect.objectContaining({ avatar: 'avatar_03' }) } }),
    }));
    expect(result.user.avatar).toBe('avatar_03');
    expect(result.accessToken).toBe('access');
    expect(result.refreshToken).toBe('refresh');
  });

  it('login returns the saved avatar without changing password verification', async () => {
    const result = await service.login({ email: identity.email, password: 'Secret123' }, {});
    expect(bcrypt.compare).toHaveBeenCalledWith('Secret123', 'hash');
    expect(result.user.avatar).toBe('avatar_03');
  });
});
