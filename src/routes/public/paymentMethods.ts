import { type RequestHandler, type Router } from 'express';
import { z } from 'zod';
import { paymentRailCapabilityService } from '../../../backend/payments/PaymentRailCapabilityService.js';

const PaymentMethodQuerySchema = z.object({
  countryCode: z.string().min(2).max(3).optional(),
  currency: z.string().length(3).optional(),
  rail: z.enum(['MOBILE_MONEY', 'BANK', 'CARD_GATEWAY', 'CRYPTO', 'WALLET']).optional(),
  operation: z.enum([
    'AUTH',
    'ACCOUNT_LOOKUP',
    'COLLECTION_REQUEST',
    'COLLECTION_STATUS',
    'DISBURSEMENT_REQUEST',
    'DISBURSEMENT_STATUS',
    'PAYOUT_REQUEST',
    'PAYOUT_STATUS',
    'REVERSAL_REQUEST',
    'REVERSAL_STATUS',
    'BALANCE_INQUIRY',
    'TRANSACTION_LOOKUP',
    'WEBHOOK_VERIFY',
    'BENEFICIARY_VALIDATE',
  ]).optional(),
  amount: z.coerce.number().positive().optional(),
});

export const registerPaymentMethodRoutes = (v1: Router, authenticate: RequestHandler) => {
  v1.get('/payment-methods', authenticate, async (req, res) => {
    try {
      const query = PaymentMethodQuerySchema.parse(req.query || {});
      const data = await paymentRailCapabilityService.listAvailable({
        countryCode: query.countryCode,
        currency: query.currency,
        rail: query.rail,
        operation: query.operation,
        amount: query.amount,
      });
      res.json({
        success: true,
        data,
      });
    } catch (error: any) {
      const message = String(error?.message || 'PAYMENT_METHODS_UNAVAILABLE');
      const status = /DB_OFFLINE|schema|relation|payment_rail_capabilities/i.test(message) ? 503 : 400;
      res.status(status).json({
        success: false,
        error: message.split(':')[0] || 'PAYMENT_METHODS_UNAVAILABLE',
        message,
      });
    }
  });
};
