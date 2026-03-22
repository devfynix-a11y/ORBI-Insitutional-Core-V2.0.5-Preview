import { Request, Response, NextFunction } from 'express';
import { UUID } from '../../services/utils.js';

/**
 * Enterprise Distributed Tracing Middleware
 * Injects a unique trace ID into every request for end-to-end observability.
 */
export const tracingMiddleware = (req: Request, res: Response, next: NextFunction) => {
    // Check if trace ID is passed from an upstream load balancer or gateway
    const traceId = req.headers['x-trace-id'] || req.headers['x-request-id'] || UUID.generate();
    
    // Attach to request object for downstream services
    (req as any).traceId = traceId;
    
    // Attach to response headers for client debugging
    res.setHeader('X-Trace-Id', traceId as string);
    
    next();
};

/**
 * PII Data Masking Utility
 * Ensures sensitive data is redacted before logging.
 */
export class Logger {
    private static readonly SENSITIVE_KEYS = ['password', 'pin', 'ssn', 'credit_card', 'token', 'secret', 'jwt'];

    private static maskData(data: any): any {
        if (!data) return data;
        if (typeof data !== 'object') return data;

        const masked = { ...data };
        for (const key of Object.keys(masked)) {
            if (this.SENSITIVE_KEYS.some(sensitive => key.toLowerCase().includes(sensitive))) {
                masked[key] = '***REDACTED***';
            } else if (typeof masked[key] === 'object') {
                masked[key] = this.maskData(masked[key]);
            }
        }
        return masked;
    }

    public static info(traceId: string, message: string, data?: any) {
        console.info(`[INFO] [Trace: ${traceId}] ${message}`, data ? this.maskData(data) : '');
    }

    public static error(traceId: string, message: string, error?: any) {
        console.error(`[ERROR] [Trace: ${traceId}] ${message}`, error ? this.maskData(error) : '');
    }

    public static warn(traceId: string, message: string, data?: any) {
        console.warn(`[WARN] [Trace: ${traceId}] ${message}`, data ? this.maskData(data) : '');
    }
}
