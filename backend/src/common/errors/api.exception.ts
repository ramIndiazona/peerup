/**
 * Standard application error. Every service error thrown toward the API layer
 * should be an ApiException (or a subclass) so the global filter can render a
 * consistent response envelope.
 */
export class ApiException extends Error {
  readonly code: string;
  readonly statusCode: number;
  readonly details?: unknown;

  constructor(
    code: string,
    message: string,
    statusCode = 400,
    details?: unknown,
  ) {
    super(message);
    this.name = 'ApiException';
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
  }
}

// ---------- convenience constructors ----------

export const unauthorized = (code = 'UNAUTHORIZED', message = 'Unauthorized') =>
  new ApiException(code, message, 401);

export const forbidden = (code = 'FORBIDDEN', message = 'Forbidden') =>
  new ApiException(code, message, 403);

export const notFound = (code = 'NOT_FOUND', message = 'Not found') =>
  new ApiException(code, message, 404);

export const conflict = (code = 'CONFLICT', message = 'Conflict') =>
  new ApiException(code, message, 409);

export const validation = (message = 'Validation failed', details?: unknown) =>
  new ApiException('VALIDATION_ERROR', message, 400, details);

export const tooManyRequests = (
  message = 'Too many requests',
  details?: unknown,
) => new ApiException('RATE_LIMITED', message, 429, details);

export const internal = (message = 'Internal server error') =>
  new ApiException('INTERNAL_ERROR', message, 500);