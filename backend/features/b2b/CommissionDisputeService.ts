import { b2bDb, asString, limitFromQuery } from './shared.js';

export class CommissionDisputeService {
  async list(query: Record<string, unknown> = {}) {
    const sb = b2bDb();
    let dbQuery = sb
      .from('service_commission_disputes')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limitFromQuery(query.limit, 100));

    const status = asString(query.status);
    const actorUserId = asString(query.actorUserId || query.actor_user_id);
    if (status) dbQuery = dbQuery.eq('status', status);
    if (actorUserId) dbQuery = dbQuery.eq('actor_user_id', actorUserId);

    const { data, error } = await dbQuery;
    if (error) throw new Error(error.message);
    return data || [];
  }

  async open(input: { commissionId: string; reason: string; actorId?: string }) {
    const sb = b2bDb();
    const { data: commission, error: commissionError } = await sb
      .from('service_commissions')
      .select('*')
      .eq('id', input.commissionId)
      .maybeSingle();
    if (commissionError) throw new Error(commissionError.message);
    if (!commission) throw new Error('COMMISSION_NOT_FOUND');

    const { data, error } = await sb
      .from('service_commission_disputes')
      .insert({
        commission_id: input.commissionId,
        actor_user_id: commission.actor_user_id,
        status: 'open',
        reason: input.reason,
        opened_by: input.actorId || null,
      })
      .select('*')
      .single();
    if (error) throw new Error(error.message);

    await sb
      .from('service_commissions')
      .update({
        status: 'disputed',
        metadata: {
          ...(commission.metadata || {}),
          dispute_id: data.id,
          disputed_at: new Date().toISOString(),
          dispute_reason: input.reason,
        },
        updated_at: new Date().toISOString(),
      })
      .eq('id', input.commissionId);

    return data;
  }

  async resolve(id: string, input: { decision: 'resolved' | 'rejected'; resolutionNote: string; actorId?: string }) {
    const sb = b2bDb();
    const status = input.decision === 'resolved' ? 'resolved' : 'rejected';
    const { data, error } = await sb
      .from('service_commission_disputes')
      .update({
        status,
        resolution_note: input.resolutionNote,
        resolved_by: input.actorId || null,
        resolved_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select('*')
      .single();
    if (error) throw new Error(error.message);

    if (data?.commission_id) {
      await sb
        .from('service_commissions')
        .update({
          status: status === 'resolved' ? 'ready_for_payout' : 'rejected',
          updated_at: new Date().toISOString(),
        })
        .eq('id', data.commission_id);
    }

    return data;
  }
}

export const commissionDisputeService = new CommissionDisputeService();
