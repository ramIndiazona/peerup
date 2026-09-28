import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';
import { ApiException } from '../errors/api.exception';

/**
 * Global exception filter producing the consistent error envelope:
 * { "success": false, "error": { "code", "message", ... } }
 * Stack traces are never exposed to clients.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<{ method: string; url: string }>();

    let statusCode: number = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'INTERNAL_ERROR';
    let message = 'Internal server error';
    let details: unknown;

    if (exception instanceof ApiException) {
      statusCode = exception.statusCode;
      code = exception.code;
      message = exception.message;
      details = exception.details;
    } else if (exception instanceof HttpException) {
      statusCode = exception.getStatus();
      const body = exception.getResponse();
      if (typeof body === 'string') {
        message = body;
      } else if (body && typeof body === 'object') {
        const b = body as {
          message?: string | string[];
          error?: string;
        };
        if (Array.isArray(b.message)) {
          code = 'VALIDATION_ERROR';
          message = b.message.join(', ');
          details = b.message;
        } else if (b.message) {
          message = b.message;
          code = b.error?.toUpperCase().replace(/\s+/g, '_') ?? code;
        }
      }
    }

    if (statusCode >= 500) {
      this.logger.error(
        `${request.method} ${request.url} -> ${message}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    } else {
      this.logger.warn(
        `${request.method} ${request.url} -> ${statusCode} ${code} ${message}`,
      );
    }

    response.status(statusCode).json({
      success: false,
      error: {
        code,
        message,
        ...(details !== undefined ? { details } : {}),
      },
    });
  }
}