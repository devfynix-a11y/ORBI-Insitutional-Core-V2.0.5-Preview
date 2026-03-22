import { Request, Response, NextFunction } from 'express';
import { FinancialCore } from '../core/FinancialCoreEngine.js';

/**
 * Middleware to authenticate requests using an API Key (x-api-key header)
 */
export const authenticateApiKey = async (req: Request, res: Response, next: NextFunction) => {
    const apiKey = req.headers['x-api-key'] as string;

    if (!apiKey) {
        return res.status(401).json({ success: false, error: "Missing API Key (x-api-key header required)" });
    }

    try {
        const tenantId = await FinancialCore.validateApiKey(apiKey);

        if (!tenantId) {
            return res.status(401).json({ success: false, error: "Invalid or revoked API Key" });
        }

        // Attach tenant context to the request
        (req as any).tenantId = tenantId;
        next();
    } catch (error: any) {
        console.error("API Key Auth Error:", error);
        res.status(500).json({ success: false, error: "Authentication service error" });
    }
};
