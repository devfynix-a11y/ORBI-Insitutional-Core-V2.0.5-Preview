import { DeleteObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { randomUUID } from 'crypto';

const allowedImageTypes = new Map<string, { extension: string; signatures: number[][] }>([
  ['image/jpeg', { extension: 'jpg', signatures: [[0xff, 0xd8, 0xff]] }],
  ['image/png', { extension: 'png', signatures: [[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]] }],
  ['image/webp', { extension: 'webp', signatures: [[0x52, 0x49, 0x46, 0x46]] }],
]);

const normalizedPublicBaseUrl = () =>
  String(
    process.env.CLOUDFLARE_PUBLIC_URL_PREFIX ||
    process.env.ORBI_IMAGE_PUBLIC_BASE_URL ||
    '',
  ).trim().replace(/\/+$/, '');

const r2Endpoint = () => {
  const configured = String(process.env.CLOUDFLARE_R2_ENDPOINT || '').trim();
  if (configured) return configured;
  const accountId = String(process.env.CLOUDFLARE_ACCOUNT_ID || '').trim();
  return accountId ? `https://${accountId}.r2.cloudflarestorage.com` : '';
};

const hasSignature = (file: Buffer, signatures: number[][]) =>
  signatures.some((signature) =>
    signature.every((byte, index) => file[index] === byte),
  );

const validateWebp = (file: Buffer) =>
  file.length >= 12 &&
  file.subarray(0, 4).toString('ascii') === 'RIFF' &&
  file.subarray(8, 12).toString('ascii') === 'WEBP';

export class ImageObjectStorage {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicBaseUrl: string;

  constructor() {
    const endpoint = r2Endpoint();
    const accessKeyId = String(
      process.env.CLOUDFLARE_ACCESS_KEY_ID ||
      process.env.CLOUDFLARE_R2_ACCESS_KEY_ID ||
      '',
    ).trim();
    const secretAccessKey = String(
      process.env.CLOUDFLARE_SECRET_ACCESS_KEY ||
      process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY ||
      '',
    ).trim();
    this.bucket = String(
      process.env.CLOUDFLARE_BUCKET_NAME ||
      process.env.CLOUDFLARE_R2_IMAGE_BUCKET ||
      '',
    ).trim();
    this.publicBaseUrl = normalizedPublicBaseUrl();

    if (!endpoint || !accessKeyId || !secretAccessKey || !this.bucket || !this.publicBaseUrl) {
      throw new Error('R2_IMAGE_STORAGE_NOT_CONFIGURED');
    }

    this.client = new S3Client({
      region: 'auto',
      endpoint,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });
  }

  validateImage(file: Buffer, contentType?: string): { contentType: string; extension: string } {
    const normalizedType = String(contentType || '').split(';')[0].trim().toLowerCase();
    const allowed = allowedImageTypes.get(normalizedType);
    if (!allowed) {
      throw new Error('UNSUPPORTED_IMAGE_TYPE: Only JPEG, PNG, and WEBP images are accepted.');
    }

    const maxBytes = Number(process.env.ORBI_IMAGE_MAX_BYTES || 5 * 1024 * 1024);
    if (!file.length || file.length > maxBytes) {
      throw new Error(`INVALID_IMAGE_SIZE: Image must be between 1 byte and ${maxBytes} bytes.`);
    }

    const validSignature =
      normalizedType === 'image/webp'
        ? validateWebp(file)
        : hasSignature(file, allowed.signatures);
    if (!validSignature) {
      throw new Error('IMAGE_SIGNATURE_MISMATCH');
    }

    return { contentType: normalizedType, extension: allowed.extension };
  }

  async uploadAvatar(userId: string, file: Buffer, contentType?: string): Promise<string> {
    const validated = this.validateImage(file, contentType);
    const key = `avatars/${userId}/${Date.now()}-${randomUUID()}.${validated.extension}`;

    await this.client.send(new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: file,
      ContentType: validated.contentType,
      CacheControl: 'public, max-age=31536000, immutable',
      Metadata: {
        owner: userId,
        purpose: 'avatar',
      },
    }));

    return `${this.publicBaseUrl}/${key}`;
  }

  async deletePublicUrl(url: string): Promise<boolean> {
    const normalizedUrl = String(url || '').trim();
    const prefix = `${this.publicBaseUrl}/`;
    if (!normalizedUrl.startsWith(prefix)) return true;

    const key = decodeURIComponent(normalizedUrl.slice(prefix.length).split('?')[0]);
    if (!key.startsWith('avatars/')) return false;

    await this.client.send(new DeleteObjectCommand({
      Bucket: this.bucket,
      Key: key,
    }));
    return true;
  }
}
