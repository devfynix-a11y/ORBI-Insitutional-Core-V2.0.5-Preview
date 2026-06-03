import type { NextFunction, Request, RequestHandler, Response } from 'express';

const boolEnv = (key: string, fallback: boolean) => {
  const value = process.env[key];
  if (value === undefined) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).trim().toLowerCase());
};

const numberEnv = (key: string, fallback: number) => {
  const parsed = Number(process.env[key]);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const API_PREFIXES = ['/api', '/api/v1', '/v1', '/auth', '/admin'];
const MUTATION_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);
const BODY_METHODS = new Set(['POST', 'PUT', 'PATCH']);
const ALLOWED_CONTENT_TYPES = [
  'application/json',
  'application/x-www-form-urlencoded',
  'multipart/form-data',
  'text/plain',
];
const HEADER_NAMES_TO_INSPECT = [
  'authorization',
  'origin',
  'referer',
  'user-agent',
  'x-orbi-app-id',
  'x-orbi-app-origin',
  'x-orbi-device-id',
  'x-orbi-fingerprint',
  'x-orbi-trace',
  'x-orbi-user-role',
  'idempotency-key',
];

const isApiPath = (path: string) =>
  API_PREFIXES.some((prefix) => path === prefix || path.startsWith(`${prefix}/`));

const normalizedPath = (req: Request) =>
  String(`${req.baseUrl || ''}${req.path || req.url || '/'}`).split('?')[0].replace(/\/+/g, '/');

const hasCrlf = (value: unknown) => /[\r\n]/.test(String(value || ''));

const headerValue = (req: Request, name: string) => {
  const raw = req.headers[name.toLowerCase()];
  return Array.isArray(raw) ? raw.join(',') : String(raw || '');
};

const isAllowedContentType = (contentType: string) => {
  const normalized = contentType.toLowerCase().split(';')[0].trim();
  return ALLOWED_CONTENT_TYPES.includes(normalized);
};

const shouldRequireContentType = (req: Request) => {
  if (!BODY_METHODS.has(req.method.toUpperCase())) return false;
  const contentLength = Number(req.headers['content-length'] || 0);
  return contentLength > 0 || req.headers['transfer-encoding'] !== undefined;
};

const isAdminMutation = (req: Request, path: string) => {
  if (!MUTATION_METHODS.has(req.method.toUpperCase())) return false;
  return path.startsWith('/v1/admin/') || path.startsWith('/api/v1/admin/') || path.startsWith('/admin/');
};

export const requestHardening = (): RequestHandler => {
  const maxQueryLength = numberEnv('ORBI_MAX_QUERY_LENGTH', 2048);
  const maxQueryParams = numberEnv('ORBI_MAX_QUERY_PARAMS', 60);
  const requireJsonContentType = boolEnv('ORBI_REQUIRE_API_CONTENT_TYPE', true);
  const requireAdminTrace = boolEnv('ORBI_REQUIRE_ADMIN_TRACE', process.env.NODE_ENV === 'production');
  const requireAdminDevice = boolEnv('ORBI_REQUIRE_ADMIN_DEVICE_ID', false);

  return (req: Request, res: Response, next: NextFunction) => {
    const path = normalizedPath(req);
    if (!isApiPath(path)) return next();

    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');

    const rawQuery = String(req.originalUrl || req.url || '').split('?')[1] || '';
    if (rawQuery.length > maxQueryLength) {
      return res.status(414).json({
        success: false,
        error: 'QUERY_TOO_LARGE',
        message: 'Request query is too large for this security boundary.',
      });
    }

    if (Object.keys(req.query || {}).length > maxQueryParams) {
      return res.status(400).json({
        success: false,
        error: 'TOO_MANY_QUERY_PARAMETERS',
        message: 'Request has too many query parameters.',
      });
    }

    for (const headerName of HEADER_NAMES_TO_INSPECT) {
      if (hasCrlf(headerValue(req, headerName))) {
        return res.status(400).json({
          success: false,
          error: 'INVALID_HEADER',
          message: 'Request contains an invalid header value.',
        });
      }
    }

    if (requireJsonContentType && shouldRequireContentType(req)) {
      const contentType = req.get('content-type') || '';
      if (!contentType || !isAllowedContentType(contentType)) {
        return res.status(415).json({
          success: false,
          error: 'UNSUPPORTED_CONTENT_TYPE',
          message: 'API mutations must use an approved content type.',
        });
      }
    }

    if (isAdminMutation(req, path)) {
      if (requireAdminTrace && !String(req.get('x-orbi-trace') || '').trim()) {
        return res.status(400).json({
          success: false,
          error: 'TRACE_REQUIRED',
          message: 'Admin mutations require x-orbi-trace for audit correlation.',
        });
      }

      const deviceIdentity = String(req.get('x-orbi-device-id') || req.get('x-orbi-fingerprint') || '').trim();
      if (requireAdminDevice && !deviceIdentity) {
        return res.status(400).json({
          success: false,
          error: 'DEVICE_ID_REQUIRED',
          message: 'Admin mutations require a device identity for operator accountability.',
        });
      }
    }

    next();
  };
};
