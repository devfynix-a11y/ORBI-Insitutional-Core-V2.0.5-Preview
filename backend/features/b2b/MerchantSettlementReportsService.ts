import { b2bDb, asNumber, asString, limitFromQuery } from './shared.js';

export type MerchantSettlementReportInput = {
  merchantId: string;
  periodStart: string;
  periodEnd: string;
  currency?: string;
  actorId?: string;
};

export class MerchantSettlementReportsService {
  async list(query: Record<string, unknown> = {}) {
    const sb = b2bDb();
    let dbQuery = sb
      .from('merchant_settlement_reports')
      .select('*')
      .order('period_end', { ascending: false })
      .limit(limitFromQuery(query.limit, 100));

    const merchantId = asString(query.merchantId || query.merchant_id);
    const status = asString(query.status);
    const currency = asString(query.currency).toUpperCase();
    if (merchantId) dbQuery = dbQuery.eq('merchant_id', merchantId);
    if (status) dbQuery = dbQuery.eq('status', status);
    if (currency) dbQuery = dbQuery.eq('currency', currency);

    const { data, error } = await dbQuery;
    if (error) throw new Error(error.message);
    return data || [];
  }

  async generate(input: MerchantSettlementReportInput) {
    const sb = b2bDb();
    const currency = asString(input.currency, 'TZS').toUpperCase();

    const { data: rows, error } = await sb
      .from('merchant_paysafe_settlements')
      .select('*')
      .eq('merchant_id', input.merchantId)
      .eq('currency', currency)
      .eq('status', 'SETTLED')
      .gte('settled_at', input.periodStart)
      .lte('settled_at', input.periodEnd);
    if (error) throw new Error(error.message);

    const settlements = rows || [];
    const grossAmount = settlements.reduce((sum: number, row: any) => sum + asNumber(row.gross_amount), 0);
    const feeAmount = settlements.reduce((sum: number, row: any) => sum + asNumber(row.fee_amount), 0);
    const taxAmount = settlements.reduce((sum: number, row: any) => sum + asNumber(row.tax_amount), 0);
    const netAmount = settlements.reduce((sum: number, row: any) => sum + asNumber(row.net_amount), 0);
    const ownerUserId = settlements.find((row: any) => row.owner_user_id)?.owner_user_id || null;

    const payload = {
      merchant_id: input.merchantId,
      owner_user_id: ownerUserId,
      period_start: input.periodStart,
      period_end: input.periodEnd,
      currency,
      gross_amount: grossAmount,
      fee_amount: feeAmount,
      tax_amount: taxAmount,
      net_amount: netAmount,
      transaction_count: settlements.length,
      settled_transaction_count: settlements.length,
      status: 'generated',
      generated_by: input.actorId || null,
      metadata: {
        source: 'merchant_paysafe_settlements',
        settlement_ids: settlements.map((row: any) => row.id),
      },
    };

    const { data, error: upsertError } = await sb
      .from('merchant_settlement_reports')
      .upsert(payload, { onConflict: 'merchant_id,period_start,period_end,currency' })
      .select('*')
      .single();
    if (upsertError) throw new Error(upsertError.message);
    return data;
  }
}

export const merchantSettlementReportsService = new MerchantSettlementReportsService();
