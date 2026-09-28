import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { v4 as uuid } from 'uuid';
import { ApiException } from '../common/errors/api.exception';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly client: S3Client | null;
  private readonly bucket: string | null;
  private readonly publicUrl: string | null;

  constructor(config: ConfigService) {
    const endpoint = config.get<string>('storage.endpoint');
    const bucket = config.get<string>('storage.bucket');
    this.bucket = bucket ?? null;
    this.publicUrl = config.get<string>('storage.publicUrl') ?? null;
    if (!endpoint || !bucket) {
      this.logger.warn('Storage endpoints not configured; uploads disabled');
      this.client = null;
      return;
    }
    this.client = new S3Client({
      endpoint,
      region: config.get<string>('storage.region', 'us-east-1'),
      credentials: {
        accessKeyId: config.get<string>('storage.accessKey', ''),
        secretAccessKey: config.get<string>('storage.secretKey', ''),
      },
      forcePathStyle: true,
    });
  }

  async upload(
    keyPrefix: string,
    buffer: Buffer,
    contentType: string,
  ): Promise<{ key: string; url: string }> {
    if (!this.client || !this.bucket) {
      throw new ApiException('STORAGE_DISABLED', 'Object storage is not configured', 503);
    }
    const ext = contentType.split('/')[1] ?? 'bin';
    const key = `${keyPrefix}/${uuid()}.${ext}`;
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: buffer,
        ContentType: contentType,
      }),
    );
    return { key, url: this.toUrl(key) };
  }

  async delete(key: string): Promise<void> {
    if (!this.client || !this.bucket) return;
    try {
      await this.client.send(
        new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
      );
    } catch (err) {
      this.logger.warn(`Failed to delete ${key}: ${(err as Error).message}`);
    }
  }

  private toUrl(key: string): string {
    if (this.publicUrl) return `${this.publicUrl}/${key}`;
    return `/files/${key}`;
  }
}