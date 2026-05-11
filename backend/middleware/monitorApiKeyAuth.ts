import crypto from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';

const readBearerToken = (headerValue: string | undefined) => {
  if (!headerValue) return null;
  const match = headerValue.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
};

const safeEqual = (left: string, right: string) => {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  if (leftBuffer.length !== rightBuffer.length) return false;
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
};

/**
 * Middleware to authenticate internal monitor routes.
 * This is intentionally separate from tenant-facing x-api-key flows.
 */
export const authenticateMonitorApiKey = (req: Request, res: Response, next: NextFunction) => {
  const expected = String(process.env.ORBI_MONITOR_API_KEY || '').trim();

  if (!expected) {
    return res.status(503).json({
      success: false,
      error: 'MONITOR_AUTH_NOT_CONFIGURED',
    });
  }

  const provided =
    readBearerToken(String(req.headers.authorization || '').trim()) ||
    String(req.headers['x-orbi-monitor-key'] || '').trim() ||
    '';

  if (!provided) {
    return res.status(401).json({
      success: false,
      error: 'Missing monitor credentials',
    });
  }

  if (!safeEqual(provided, expected)) {
    return res.status(401).json({
      success: false,
      error: 'Invalid monitor credentials',
    });
  }

  (req as any).monitorAccess = true;
  next();
};
