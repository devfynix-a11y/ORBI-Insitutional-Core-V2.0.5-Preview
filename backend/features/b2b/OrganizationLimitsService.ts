import { b2bDb, asNumber, asString, limitFromQuery } from './shared.js';

export class OrganizationLimitsService {
  async list(query: Record<string, unknown> = {}) {
    const sb = b2bDb();
    let dbQuery = sb
      .from('organization_limit_configs')
      .select('*')
      .order('updated_at', { ascending: false })
      .limit(limitFromQuery(query.limit, 100));

    const organizationId = asString(query.organizationId || query.organization_id);
    const currency = asString(query.currency).toUpperCase();
    const status = asString(query.status);
    if (organizationId) dbQuery = dbQuery.eq('organization_id', organizationId);
    if (currency) dbQuery = dbQuery.eq('currency', currency);
    if (status) dbQuery = dbQuery.eq('status', status);

    const { data, error } = await dbQuery;
    if (error) throw new Error(error.message);
    return data || [];
  }

  async upsert(input: Record<string, unknown>, actorId?: string) {
    const sb = b2bDb();
    const organizationId = asString(input.organizationId || input.organization_id);
    if (!organizationId) throw new Error('ORGANIZATION_ID_REQUIRED');

    const payload = {
      organization_id: organizationId,
      currency: asString(input.currency, 'TZS').toUpperCase(),
      max_amount_per_tx: input.maxAmountPerTx === undefined ? null : asNumber(input.maxAmountPerTx),
      daily_limit: input.dailyLimit === undefined ? null : asNumber(input.dailyLimit),
      monthly_limit: input.monthlyLimit === undefined ? null : asNumber(input.monthlyLimit),
      maker_checker_threshold: input.makerCheckerThreshold === undefined ? null : asNumber(input.makerCheckerThreshold),
      auto_freeze_threshold: input.autoFreezeThreshold === undefined ? null : asNumber(input.autoFreezeThreshold),
      status: asString(input.status, 'active').toLowerCase(),
      reason: asString(input.reason, 'Organization limit policy updated by platform control.'),
      updated_by: actorId || null,
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await sb
      .from('organization_limit_configs')
      .upsert(payload, { onConflict: 'organization_id,currency' })
      .select('*')
      .single();
    if (error) throw new Error(error.message);

    await sb
      .from('organizations')
      .update({
        max_amount_per_tx: payload.max_amount_per_tx,
        daily_limit: payload.daily_limit,
        currency: payload.currency,
        updated_at: new Date().toISOString(),
      })
      .eq('id', organizationId);

    return data;
  }
}

export const organizationLimitsService = new OrganizationLimitsService();
