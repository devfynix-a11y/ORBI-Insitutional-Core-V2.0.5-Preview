import { b2bDb, asNumber, isoDaysAgo } from './shared.js';

const ratio = (part: number, whole: number) => whole > 0 ? Math.round((part / whole) * 100) : 0;

export class B2BRiskDashboardService {
  async summary(query: Record<string, unknown> = {}) {
    const sb = b2bDb();
    const since = isoDaysAgo(asNumber(query.days, 30));

    const [
      { data: merchantTxs, error: merchantError },
      { data: agentTxs, error: agentError },
      { data: commissions, error: commissionError },
      { data: floatRows, error: floatError },
      { data: requests, error: requestError },
      { data: limits, error: limitError },
    ] = await Promise.all([
      sb.from('merchant_transactions').select('*').gte('created_at', since),
      sb.from('agent_transactions').select('*').gte('created_at', since),
      sb.from('service_commissions').select('*').gte('created_at', since),
      sb.from('agent_float_controls').select('*'),
      sb.from('service_access_requests').select('*').gte('created_at', since),
      sb.from('organization_limit_configs').select('*'),
    ]);
    if (merchantError) throw new Error(merchantError.message);
    if (agentError) throw new Error(agentError.message);
    if (commissionError) throw new Error(commissionError.message);
    if (floatError) throw new Error(floatError.message);
    if (requestError) throw new Error(requestError.message);
    if (limitError) throw new Error(limitError.message);

    const merchantFailed = (merchantTxs || []).filter((tx: any) => String(tx.status || '').toLowerCase() === 'failed').length;
    const agentFailed = (agentTxs || []).filter((tx: any) => String(tx.status || '').toLowerCase() === 'failed').length;
    const disputedCommissions = (commissions || []).filter((row: any) => String(row.status || '').toLowerCase() === 'disputed').length;
    const pendingRequests = (requests || []).filter((row: any) => String(row.status || '').toLowerCase() === 'pending').length;
    const lockedFloatControls = (floatRows || []).filter((row: any) => ['paused', 'locked'].includes(String(row.status || '').toLowerCase())).length;
    const suspendedOrgLimits = (limits || []).filter((row: any) => String(row.status || '').toLowerCase() !== 'active').length;

    const weightedScore = Math.min(100, Math.round(
      ratio(merchantFailed + agentFailed, (merchantTxs || []).length + (agentTxs || []).length) * 0.35 +
      Math.min(100, disputedCommissions * 8) * 0.25 +
      Math.min(100, lockedFloatControls * 12) * 0.2 +
      Math.min(100, pendingRequests * 4) * 0.1 +
      Math.min(100, suspendedOrgLimits * 10) * 0.1,
    ));

    return {
      since,
      riskScore: weightedScore,
      status: weightedScore >= 80 ? 'CRITICAL' : weightedScore >= 60 ? 'HIGH' : weightedScore >= 35 ? 'WATCH' : 'HEALTHY',
      merchant: {
        transactions: (merchantTxs || []).length,
        failed: merchantFailed,
        failureRate: ratio(merchantFailed, (merchantTxs || []).length),
      },
      agent: {
        transactions: (agentTxs || []).length,
        failed: agentFailed,
        failureRate: ratio(agentFailed, (agentTxs || []).length),
        lockedFloatControls,
      },
      commissions: {
        total: (commissions || []).length,
        disputed: disputedCommissions,
      },
      serviceAccess: {
        requests: (requests || []).length,
        pending: pendingRequests,
      },
      organizationLimits: {
        total: (limits || []).length,
        inactive: suspendedOrgLimits,
      },
    };
  }
}

export const b2bRiskDashboardService = new B2BRiskDashboardService();
