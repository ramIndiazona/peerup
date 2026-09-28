import { ApiException } from '../errors/api.exception';

/**
 * Throws a valid signed JWT payload error used by the JwtAuthGuard.
 */
export const buildAuthException = (): ApiException => {
  const err = new ApiException('UNAUTHORIZED', 'Unauthorized', 401);
  return err;
};