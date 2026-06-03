import { b2bDb, asNumber, asString, isoDaysAgo, limitFromQuery } from './shared.js';

export type AgentFloatControlInput = {
  agentId: string;
  currency?: string;
  minFloat?: number;
  maxFloat?: number;
  dailyCashInLimit?: number;
  dailyCashOutLimit?: number;
  status?: string;
  reason: string;
  actorId?: string;
};

export class AgentFloatControlService {
  async list(query: Record<string, unknown> = {}) {
    const sb = b2bDb();
    let dbQuery = sb
      .from('agent_float_controls')
      .select('*')
      .order('updated_at', { ascending: false })
      .limit(limitFromQuery(query.limit, 100));

    const agentId = asString(query.agentId || query.agent_id);
    const status = asString(query.status);
    const currency = asString(query.currency).toUpperCase();
    if (agentId) dbQuery = dbQuery.eq('agent_id', agentId);
    if (status) dbQuery = dbQuery.eq('status', status);
    if (currency) dbQuery = dbQuery.eq('currency', currency);

    const { data, error } = await dbQuery;
    if (error) throw new Error(error.message);
    return data || [];
  }

  async upsert(input: AgentFloatControlInput) {
    const sb = b2bDb();
    const payload = {
      agent_id: input.agentId,
      currency: asString(input.currency, 'TZS').toUpperCase(),
      min_float: asNumber(input.minFloat),
      max_float: input.maxFloat === undefined ? null : asNumber(input.maxFloat),
      daily_cash_in_limit: input.dailyCashInLimit === undefined ? null : asNumber(input.dailyCashInLimit),
      daily_cash_out_limit: input.dailyCashOutLimit === undefined ? null : asNumber(input.dailyCashOutLimit),
      status: asString(input.status, 'active').toLowerCase(),
      reason: input.reason,
      updated_by: input.actorId || null,
      updated_at: new Date().toISOString(),
    };

    const { data, error } = await sb
      .from('agent_float_controls')
      .upsert(payload, { onConflict: 'agent_id,currency' })
      .select('*')
      .single();
    if (error) throw new Error(error.message);
    return data;
  }

  async dashboard(query: Record<string, unknown> = {}) {
    const sb = b2bDb();
    const currency = asString(query.currency, 'TZS').toUpperCase();
    const since = isoDaysAgo(asNumber(query.days, 1));

    const [{ data: controls, error: controlsError }, { data: wallets, error: walletsError }, { data: transactions, error: txError }] = await Promise.all([
      sb.from('agent_float_controls').select('*').eq('currency', currency),
      sb.from('agent_wallets').select('*').eq('currency', currency),
      sb.from('agent_transactions').select('*').eq('currency', currency).gte('created_at', since),
    ]);
    if (controlsError) throw new Error(controlsError.message);
    if (walletsError) throw new Error(walletsError.message);
    if (txError) throw new Error(txError.message);

    const walletByAgent = new Map<string, any[]>();
    for (const wallet of wallets || []) {
      const key = String(wallet.agent_id || '');
      if (!key) continue;
      walletByAgent.set(key, [...(walletByAgent.get(key) || []), wallet]);
    }

    return (controls || []).map((control: any) => {
      const agentWallets = walletByAgent.get(String(control.agent_id)) || [];
      const currentFloat = agentWallets.reduce((sum, wallet) => sum + asNumber(wallet.balance), 0);
      const agentTxs = (transactions || []).filter((tx: any) => tx.agent_id === control.agent_id);
      const cashIn = agentTxs
        .filter((tx: any) => String(tx.service_type || '').includes('deposit') || String(tx.direction || '').toLowerCase() === 'inbound')
        .reduce((sum: number, tx: any) => sum + asNumber(tx.amount), 0);
      const cashOut = agentTxs
        .filter((tx: any) => String(tx.service_type || '').includes('withdraw') || String(tx.direction || '').toLowerCase() === 'outbound')
        .reduce((sum: number, tx: any) => sum + asNumber(tx.amount), 0);

      const breaches = [
        currentFloat < asNumber(control.min_float) ? 'BELOW_MIN_FLOAT' : null,
        control.max_float !== null && currentFloat > asNumber(control.max_float) ? 'ABOVE_MAX_FLOAT' : null,
        control.daily_cash_in_limit !== null && cashIn > asNumber(control.daily_cash_in_limit) ? 'DAILY_CASH_IN_LIMIT' : null,
        control.daily_cash_out_limit !== null && cashOut > asNumber(control.daily_cash_out_limit) ? 'DAILY_CASH_OUT_LIMIT' : null,
      ].filter(Boolean);

      return {
        ...control,
        current_float: currentFloat,
        wallet_count: agentWallets.length,
        daily_cash_in: cashIn,
        daily_cash_out: cashOut,
        breach_count: breaches.length,
        breaches,
        health: breaches.length > 0 ? 'ATTENTION' : 'HEALTHY',
      };
    });
  }
}

export const agentFloatControlService = new AgentFloatControlService();
