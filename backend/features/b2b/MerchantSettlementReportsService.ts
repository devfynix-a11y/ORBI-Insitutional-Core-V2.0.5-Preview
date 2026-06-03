import { b2bDb, asNumber, asString, limitFromQuery, metadataNumber } from './shared.js';

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
      .from('merchant_transactions')
      .select('*')
      .eq('merchant_id', input.merchantId)
      .eq('currency', currency)
      .gte('created_at', input.periodStart)
      .lte('created_at', input.periodEnd);
    if (error) throw new Error(error.message);

    const transactions = rows || [];
    const grossAmount = transactions.reduce((sum: number, row: any) => sum + asNumber(row.amount), 0);
    const feeAmount = transactions.reduce((sum: number, row: any) => (
      sum + metadataNumber(row.metadata, ['feeAmount', 'fee_amount', 'totalFee', 'platformFee'])
    ), 0);
    const taxAmount = transactions.reduce((sum: number, row: any) => (
      sum + metadataNumber(row.metadata, ['taxAmount', 'tax_amount', 'vatAmount', 'governmentFee'])
    ), 0);
    const settledCount = transactions.filter((row: any) => String(row.status || '').toLowerCase() === 'completed').length;

    const payload = {
      merchant_id: input.merchantId,
      owner_user_id: transactions.find((row: any) => row.owner_user_id)?.owner_user_id || null,
      period_start: input.periodStart,
      period_end: input.periodEnd,
      currency,
      gross_amount: grossAmount,
      fee_amount: feeAmount,
      tax_amount: taxAmount,
      net_amount: grossAmount - feeAmount - taxAmount,
      transaction_count: transactions.length,
      settled_transaction_count: settledCount,
      status: 'generated',
      generated_by: input.actorId || null,
      metadata: {
        failed_transaction_count: transactions.filter((row: any) => String(row.status || '').toLowerCase() === 'failed').length,
        pending_transaction_count: transactions.filter((row: any) => !['completed', 'failed'].includes(String(row.status || '').toLowerCase())).length,
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
