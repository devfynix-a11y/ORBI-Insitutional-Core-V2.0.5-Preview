import type { RequestHandler, Router } from 'express';
import { z } from 'zod';
import { BusinessIdentity } from '../../../backend/business/BusinessIdentityService.js';

const BusinessRegistrationSchema = z.object({
  requestedRole: z.string().optional(),
  requested_role: z.string().optional(),
  businessName: z.string().trim().min(1).max(160).optional(),
  business_name: z.string().trim().min(1).max(160).optional(),
  phone: z.string().trim().min(1).max(40).optional(),
  note: z.string().trim().max(1000).optional(),
  metadata: z.record(z.string(), z.any()).optional(),
});

const errorStatus = (message: string) => {
  if (/DB_OFFLINE|UNAVAILABLE/i.test(message)) return 503;
  if (/NOT_FOUND/i.test(message)) return 404;
  if (/ALREADY|PENDING/i.test(message)) return 409;
  if (/UNSUPPORTED|INELIGIBLE|REQUIRED|INVALID/i.test(message)) return 400;
  return 500;
};

type Deps = {
  authenticate: RequestHandler;
};

export const registerBusinessRoutes = (v1: Router, deps: Deps) => {
  const { authenticate } = deps;

  v1.get('/business/me', authenticate, async (req, res) => {
    const session = (req as any).session;
    try {
      const data = await BusinessIdentity.getBusinessProfile(session.sub, session.user);
      res.json({ success: true, data });
    } catch (e: any) {
      const message = String(e?.message || 'BUSINESS_PROFILE_FAILED');
      res.status(errorStatus(message)).json({ success: false, error: message });
    }
  });

  v1.post('/business/registrations', authenticate, async (req, res) => {
    const session = (req as any).session;
    try {
      const body = BusinessRegistrationSchema.parse(req.body || {});
      const result = await BusinessIdentity.submitBusinessRegistration(session.sub, session.user, {
        requestedRole: body.requestedRole || body.requested_role,
        businessName: body.businessName || body.business_name,
        phone: body.phone,
        note: body.note,
        submittedVia: 'orbi_business_public',
        metadata: body.metadata || {},
      });
      res.status(result.alreadyPending ? 200 : 201).json({ success: true, data: result });
    } catch (e: any) {
      const message = e?.issues ? 'BUSINESS_REGISTRATION_VALIDATION_FAILED' : String(e?.message || 'BUSINESS_REGISTRATION_FAILED');
      res.status(errorStatus(message)).json({
        success: false,
        error: message,
        details: e?.issues || undefined,
      });
    }
  });
};
