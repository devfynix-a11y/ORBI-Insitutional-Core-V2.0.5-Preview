import { NextFunction, Request, Response } from 'express';
import { z } from 'zod';

export const validate = (schema: z.ZodSchema) =>
  (req: Request, res: Response, next: NextFunction) => {
    try {
      schema.parse(req.body);
      next();
    } catch (err: any) {
      const issues = Array.isArray(err?.issues)
        ? err.issues
        : Array.isArray(err?.errors)
          ? err.errors
          : [];
      res.status(400).json({
        success: false,
        error: 'VALIDATION_FAILED',
        details: issues.map((e: any) => ({
          path: Array.isArray(e.path) ? e.path : [],
          message: e.message || 'Invalid value',
          code: e.code,
        })),
      });
    }
  };
