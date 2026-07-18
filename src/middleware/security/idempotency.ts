import { NextFunction, Request, Response } from 'express';
import crypto from 'crypto';

type CachedResponse = { status: number; body: any; state?: 'COMPLETED' | 'PROCESSING' };

type CreateIdempotencyOptions = {
  redisClient: any;
  allowProcessLocalIdempotency: boolean;
  idempotencyTtlSeconds: number;
};

export const resolveIdempotencyHeader = (req: Request) =>
  req.header('Idempotency-Key') ||
  req.header('x-idempotency-key') ||
  (req.body as any)?.idempotencyKey ||
  (req.body as any)?.idempotency_key;

const stableStringify = (value: any): string => {
  if (value === null || value === undefined) return '';
  if (Buffer.isBuffer(value)) return value.toString('base64');
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  if (typeof value === 'object') {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
};

const buildRequestFingerprint = (req: Request, key: string) => {
  const bodyHash = crypto
    .createHash('sha256')
    .update(stableStringify((req as any).body || {}))
    .digest('hex');
  const path = req.baseUrl
    ? `${req.baseUrl}${req.path}`
    : (req.route?.path ? `${req.originalUrl.split('?')[0]}` : req.originalUrl.split('?')[0]);
  return `${req.method.toUpperCase()}:${path}:${key}:${bodyHash}`;
};

export const requireIdempotencyKey = (req: Request, res: Response, next: NextFunction) => {
  const key = resolveIdempotencyHeader(req);
  if (!key || !String(key).trim()) {
    return res.status(428).json({
      success: false,
      error: 'IDEMPOTENCY_KEY_REQUIRED',
      message: 'Money movement requests require an Idempotency-Key header.',
    });
  }
  return next();
};

export const createIdempotencyMiddleware = ({
  redisClient,
  allowProcessLocalIdempotency,
  idempotencyTtlSeconds,
}: CreateIdempotencyOptions) => {
  const idempotencyCache = new Map<string, CachedResponse>();

  const readIdempotencyCache = async (key: string) => {
    if (redisClient) {
      try {
        const cached = await redisClient.get(`idempotency:${key}`);
        if (cached) {
          return JSON.parse(String(cached)) as CachedResponse;
        }
      } catch (e) {
        console.warn('[Idempotency] Redis read failed:', e);
      }
    }

    if (allowProcessLocalIdempotency) {
      return idempotencyCache.get(key);
    }

    return null;
  };

  const reserveIdempotencyKey = async (key: string): Promise<boolean> => {
    const processingValue = JSON.stringify({ state: 'PROCESSING' });
    if (redisClient) {
      try {
        const result = await redisClient.set(
          `idempotency:${key}`,
          processingValue,
          'EX',
          idempotencyTtlSeconds,
          'NX',
        );
        return result === 'OK';
      } catch (e) {
        console.warn('[Idempotency] Redis reservation failed:', e);
      }
    }

    if (!allowProcessLocalIdempotency) return true;
    if (idempotencyCache.has(key)) return false;
    idempotencyCache.set(key, { status: 202, body: null, state: 'PROCESSING' });
    return true;
  };

  const writeIdempotencyCache = async (key: string, value: CachedResponse) => {
    if (redisClient) {
      try {
        await redisClient.set(
          `idempotency:${key}`,
          JSON.stringify(value),
          'EX',
          idempotencyTtlSeconds,
        );
        return;
      } catch (e) {
        console.warn('[Idempotency] Redis write failed:', e);
      }
    }

    if (!allowProcessLocalIdempotency) {
      console.warn(
        `[Idempotency] Redis unavailable and process-local fallback disabled. Key ${key} will not be cached.`,
      );
      return;
    }

    idempotencyCache.set(key, value);
    if (idempotencyCache.size > 1000) {
      const firstKey = idempotencyCache.keys().next().value;
      if (firstKey !== undefined) idempotencyCache.delete(firstKey);
    }
  };

  return async (req: Request, res: Response, next: NextFunction) => {
    const rawKey = resolveIdempotencyHeader(req);
    if (!rawKey) return next();

    const key = buildRequestFingerprint(req, String(rawKey).trim());

    const cached = await readIdempotencyCache(key);
    if (cached) {
      if (cached.state === 'PROCESSING') {
        return res.status(409).json({
          success: false,
          error: 'IDEMPOTENT_REQUEST_IN_PROGRESS',
          message: 'A request with this Idempotency-Key and payload is still processing.',
        });
      }
      console.info(`[Idempotency] Duplicate request detected for key: ${rawKey}`);
      return res.status(cached.status).json(cached.body);
    }

    const reserved = await reserveIdempotencyKey(key);
    if (!reserved) {
      return res.status(409).json({
        success: false,
        error: 'IDEMPOTENT_REQUEST_IN_PROGRESS',
        message: 'A request with this Idempotency-Key and payload is still processing.',
      });
    }

    const originalJson = res.json;
    res.json = function (body: any) {
      void writeIdempotencyCache(key, { status: res.statusCode, body, state: 'COMPLETED' });
      return originalJson.call(this, body);
    };

    next();
  };
};
