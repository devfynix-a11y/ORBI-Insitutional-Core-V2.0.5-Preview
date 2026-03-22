import { Request, Response, NextFunction } from 'express';

export const continuousSessionMonitor = (req: Request, res: Response, next: NextFunction) => {
    // Extract session info (assuming it was populated by an earlier auth middleware)
    const session = (req as any).session;
    
    if (!session) {
        return next(); // Skip if not authenticated
    }

    const currentIp = req.ip || req.headers['x-forwarded-for'] || '0.0.0.0';
    const currentDeviceFingerprint = req.headers['x-device-fingerprint'];

    // 1. IP Anomaly Detection
    if (session.ip && session.ip !== currentIp) {
        console.warn(`[SessionMonitor] IP Address changed drastically for user ${session.userId}. Old: ${session.ip}, New: ${currentIp}`);
        // In a strict Zero-Trust model, we invalidate the session or require step-up authentication
        return res.status(401).json({ 
            error: "SESSION_INVALIDATED", 
            message: "IP address changed drastically. Please re-authenticate." 
        });
    }

    // 2. Device Fingerprint Anomaly Detection
    if (session.deviceFingerprint && currentDeviceFingerprint && session.deviceFingerprint !== currentDeviceFingerprint) {
        console.warn(`[SessionMonitor] Device fingerprint changed mid-session for user ${session.userId}.`);
        return res.status(401).json({ 
            error: "SESSION_INVALIDATED", 
            message: "Device fingerprint mismatch. Please re-authenticate." 
        });
    }

    // 3. Update last active timestamp
    session.lastActive = new Date().toISOString();

    next();
};
