import { NextFunction, Request, Response } from 'express';
import { RiskEngine } from '../../../backend/security/RiskEngine.js';
import { SecurityOperationsEngine } from '../../../backend/security/SecurityOperationsEngine.js';

export const riskAssessment = async (req: Request, res: Response, next: NextFunction) => {
  if (req.path === '/health' || req.path.startsWith('/public')) return next();

  const profile = SecurityOperationsEngine.classify(req);

  try {
    if (!SecurityOperationsEngine.hasRequiredReason(req, profile)) {
      return res.status(400).json({
        success: false,
        error: 'GOVERNANCE_REASON_REQUIRED',
        message: `${profile.class} requires a readable governance reason before it can be committed.`,
        operationClass: profile.class,
      });
    }

    const context = {
      userId: (req as any).session?.sub || (req as any).user?.sub,
      ip: req.ip || '0.0.0.0',
      appId: ((req.headers['x-orbi-app-id'] as string) || 'anonymous-node'),
    };

    const risk = await RiskEngine.evaluateRequest(req, context);

    if (risk.action === 'BLOCK') {
      return res.status(403).json({
        success: false,
        error: 'SECURITY_BLOCK',
        message: 'Request blocked by Risk Engine',
        score: risk.score,
        operationClass: profile.class,
      });
    }

    (req as any).risk = risk;
    next();
  } catch (err: any) {
    console.error('[RiskEngine] Evaluation Fault:', err.message);
    if (profile.failClosed) {
      await SecurityOperationsEngine.alertSecurityBlock(req, profile, {
        reason: 'RISK_ENGINE_FAULT',
        errorMessage: err?.message || 'Unknown risk engine fault',
      });
      return res.status(503).json({
        success: false,
        error: 'RISK_ENGINE_UNAVAILABLE',
        code: 'SECURITY_FAIL_CLOSED',
        message: 'Security controls are temporarily unavailable for this sensitive operation. Please retry later or escalate to operations.',
        operationClass: profile.class,
      });
    }
    next();
  }
};
