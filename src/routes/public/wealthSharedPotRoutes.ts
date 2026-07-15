import crypto from 'node:crypto';
import { type RequestHandler, type Router } from 'express';
import { Messaging } from '../../../backend/features/MessagingService.js';
import { contributeToSharedPot, withdrawFromSharedPot } from './wealthSharedPotFinance.js';

type Deps = {
  authenticate: RequestHandler;
  getSupabase: () => any;
  getAdminSupabase: () => any;
  SharedPotCreateSchema: any;
  SharedPotUpdateSchema: any;
  SharedPotMemberAddSchema: any;
  SharedPotInviteResponseSchema: any;
  SharedPotContributionSchema: any;
  SharedPotWithdrawSchema: any;
  wealthNumber: (value: any) => number;
  resolveWealthSourceWallet: (sb: any, userId: string, sourceWalletId?: string) => Promise<any>;
  resolveSharedPotMembership: (sb: any, potId: string, userId: string) => Promise<any>;
  canManageSharedPot: (role: string) => boolean;
  canContributeToSharedPot: (role: string) => boolean;
  resolveUserBySharedPotIdentifier: (sb: any, identifier: string) => Promise<any>;
  expireSharedPotInvitationIfNeeded: (sb: any, invite: any) => Promise<any>;
  OTPService?: any;
};

const ORBI_USER_SELECT = 'id, full_name, email, phone';

const compactIds = (rows: any[], key: string): string[] => Array.from(new Set(
  (rows || []).map((row: any) => String(row?.[key] || '')).filter(Boolean),
));

const fetchUsersById = async (sb: any, userIds: string[]): Promise<Map<string, any>> => {
  if (!userIds.length) return new Map();
  const { data, error } = await sb
    .from('users')
    .select(ORBI_USER_SELECT)
    .in('id', userIds);
  if (error) throw new Error(error.message);
  return new Map((data || []).map((user: any) => [String(user.id), user]));
};

const fetchSharedPotsById = async (sb: any, potIds: string[]): Promise<Map<string, any>> => {
  if (!potIds.length) return new Map();
  const { data, error } = await sb
    .from('shared_pots')
    .select('id, name, purpose, currency, target_amount, current_amount, status')
    .in('id', potIds);
  if (error) throw new Error(error.message);
  return new Map((data || []).map((pot: any) => [String(pot.id), pot]));
};

type ReportRangeKey = 'week' | 'month' | 'year';

const toMoneyNumber = (value: any): number => {
  const parsed = Number(value || 0);
  return Number.isFinite(parsed) ? parsed : 0;
};

const resolveReportRange = (raw: unknown): { key: ReportRangeKey; start: Date; end: Date } => {
  const key = String(Array.isArray(raw) ? raw[0] : raw || 'month').toLowerCase() as ReportRangeKey;
  const safeKey: ReportRangeKey = ['week', 'month', 'year'].includes(key) ? key : 'month';
  const end = new Date();
  const start = new Date(end);

  if (safeKey === 'week') {
    const day = start.getDay();
    const mondayOffset = day === 0 ? -6 : 1 - day;
    start.setDate(start.getDate() + mondayOffset);
    start.setHours(0, 0, 0, 0);
  } else if (safeKey === 'year') {
    start.setMonth(0, 1);
    start.setHours(0, 0, 0, 0);
  } else {
    start.setDate(1);
    start.setHours(0, 0, 0, 0);
  }

  return { key: safeKey, start, end };
};

const isPotWithdrawal = (transaction: any): boolean => {
  const source = String(transaction?.allocation_source || '').toUpperCase();
  const description = String(transaction?.description || '').toUpperCase();
  return source.includes('WITHDRAWAL') || description.includes('WITHDRAWAL');
};

const potActivityLabel = (transaction: any): string => {
  return isPotWithdrawal(transaction) ? 'Withdrawal from Fungu' : 'Contribution to Fungu';
};

const normalizeUpper = (value: any, fallback: string) =>
  String(value || fallback).trim().toUpperCase();

const defaultGovernanceForAccessModel = (accessModel: string) => {
  const model = normalizeUpper(accessModel, 'INVITE');
  if (model === 'ORG') {
    return {
      governance_model: 'ORG_APPROVAL',
      withdrawal_policy: 'APPROVAL_REQUIRED',
      min_withdrawal_approvals: 2,
      require_withdrawal_reason: true,
    };
  }
  if (model === 'PRIVATE') {
    return {
      governance_model: 'OWNER_CONTROLLED',
      withdrawal_policy: 'OWNER_ONLY',
      min_withdrawal_approvals: 1,
      require_withdrawal_reason: false,
    };
  }
  return {
    governance_model: 'OWNER_CONTROLLED',
    withdrawal_policy: 'OWNER_OR_MANAGER',
    min_withdrawal_approvals: 1,
    require_withdrawal_reason: false,
  };
};

const resolveActorOrganization = async (sb: any, userId: string) => {
  const { data, error } = await sb
    .from('users')
    .select('id,organization_id,org_role')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data || null;
};

const buildGovernancePayload = async (sb: any, actorUserId: string, payload: any) => {
  const accessModel = normalizeUpper(payload.access_model, 'INVITE');
  const defaults = defaultGovernanceForAccessModel(accessModel);
  const actor = accessModel === 'ORG' ? await resolveActorOrganization(sb, actorUserId) : null;
  if (accessModel === 'ORG' && !actor?.organization_id) {
    throw new Error('SHARED_POT_ORG_REQUIRED');
  }
  return {
    access_model: accessModel,
    organization_id: accessModel === 'ORG' ? actor.organization_id : null,
    governance_model: normalizeUpper(payload.governance_model, defaults.governance_model),
    withdrawal_policy: normalizeUpper(payload.withdrawal_policy, defaults.withdrawal_policy),
    min_withdrawal_approvals: Number(payload.min_withdrawal_approvals || defaults.min_withdrawal_approvals),
    withdrawal_limit_amount: payload.withdrawal_limit_amount ?? null,
    maturity_at: payload.maturity_at ?? null,
    require_withdrawal_reason: payload.require_withdrawal_reason ?? defaults.require_withdrawal_reason,
  };
};

const roleCanWithdrawDirectly = (role: string, policy: string) => {
  const normalizedRole = normalizeUpper(role, '');
  const normalizedPolicy = normalizeUpper(policy, 'OWNER_OR_MANAGER');
  if (normalizedPolicy === 'OWNER_ONLY') return normalizedRole === 'OWNER';
  if (normalizedPolicy === 'OWNER_OR_MANAGER') return ['OWNER', 'MANAGER'].includes(normalizedRole);
  return false;
};

const roleCanRequestWithdrawal = (role: string) =>
  ['OWNER', 'MANAGER', 'CONTRIBUTOR'].includes(normalizeUpper(role, ''));

const withdrawalRequiresApproval = (pot: any, role: string) => {
  const policy = normalizeUpper(pot?.withdrawal_policy, 'OWNER_OR_MANAGER');
  if (policy === 'APPROVAL_REQUIRED') return true;
  return !roleCanWithdrawDirectly(role, policy);
};

const validateWithdrawalPolicy = (pot: any, payload: any) => {
  const amount = toMoneyNumber(payload.amount);
  if (pot?.maturity_at && new Date(pot.maturity_at).getTime() > Date.now()) {
    throw new Error('SHARED_POT_NOT_MATURED');
  }
  if (pot?.withdrawal_limit_amount != null && toMoneyNumber(pot.withdrawal_limit_amount) > 0) {
    if (amount > toMoneyNumber(pot.withdrawal_limit_amount)) {
      throw new Error('SHARED_POT_WITHDRAWAL_LIMIT_EXCEEDED');
    }
  }
  if (pot?.require_withdrawal_reason && !String(payload.reason || '').trim()) {
    throw new Error('SHARED_POT_WITHDRAWAL_REASON_REQUIRED');
  }
};

const approvalCount = (approvals: any[]) => approvals.filter((item) => item?.action === 'APPROVE').length;

const normalizeApprovals = (value: any): any[] => Array.isArray(value) ? value : [];

const notifyPotMembers = async (sb: any, potId: string, subject: string, body: string, variables: Record<string, any> = {}) => {
  const { data: members } = await sb
    .from('shared_pot_members')
    .select('user_id')
    .eq('pot_id', potId);
  const userIds: string[] = Array.from(
    new Set<string>((members || []).map((member: any) => String(member.user_id || '')).filter(Boolean)),
  );
  await Promise.all(userIds.map((userId) => Messaging.dispatch(userId, 'info', subject, body, {
    push: true,
    sms: false,
    email: true,
    eventCode: variables.eventCode || 'SHARED_POT_GOVERNANCE_UPDATED',
    variables,
  }).catch((error: any) => {
    console.warn('[Wealth][SharedPot] Member notification deferred', {
      potId,
      userId,
      code: String(error?.code || error?.message || ''),
    });
  })));
};

const createSharedPotWithdrawalRequest = async (input: {
  sb: any;
  sessionUserId: string;
  pot: any;
  membership: any;
  payload: any;
  wealthNumber: (value: any) => number;
  resolveWealthSourceWallet: Deps['resolveWealthSourceWallet'];
}) => {
  const { sb, sessionUserId, pot, membership, payload, wealthNumber, resolveWealthSourceWallet } = input;
  validateWithdrawalPolicy(pot, payload);
  if (wealthNumber(pot.current_amount) < payload.amount) {
    throw new Error('INSUFFICIENT_POT_FUNDS');
  }
  const { sourceRecord: targetRecord, sourceTable: targetTable } = await resolveWealthSourceWallet(
    sb,
    sessionUserId,
    payload.target_wallet_id,
  );
  const idempotencyKey = String(payload.idempotency_key || crypto.randomUUID());
  const requiredApprovals = Math.max(1, Math.min(10, Number(pot.min_withdrawal_approvals || 1)));

  const { data: existing, error: existingError } = await sb
    .from('shared_pot_withdrawal_requests')
    .select('*')
    .eq('requester_user_id', sessionUserId)
    .eq('idempotency_key', idempotencyKey)
    .maybeSingle();
  if (existingError) throw new Error(existingError.message);
  if (existing) {
    return { request: existing, requires_approval: true, idempotent: true };
  }

  const { data, error } = await sb
    .from('shared_pot_withdrawal_requests')
    .insert({
      pot_id: pot.id,
      requester_user_id: sessionUserId,
      target_wallet_id: targetRecord.id,
      amount: payload.amount,
      currency: String(pot.currency || targetRecord.currency || 'TZS').toUpperCase(),
      reason: payload.reason || null,
      required_approvals: requiredApprovals,
      idempotency_key: idempotencyKey,
      metadata: {
        requester_role: membership.role || 'MANAGER',
        access_model: pot.access_model || 'INVITE',
        governance_model: pot.governance_model || null,
        withdrawal_policy: pot.withdrawal_policy || null,
        target_table: targetTable,
        target_wallet_role: targetRecord.vault_role || targetRecord.type || null,
      },
    })
    .select('*')
    .single();
  if (error) throw new Error(error.message);
  return { request: data, requires_approval: true, idempotent: false };
};

const buildSharedPotReport = (
  pot: any,
  members: any[],
  ledgerRows: any[],
  transactions: any[],
  usersById: Map<string, any>,
  range: ReturnType<typeof resolveReportRange>,
) => {
  const transactionsById = new Map((transactions || []).map((transaction: any) => [String(transaction.id), transaction]));
  const periodByUser = new Map<string, { contributed: number; withdrawn: number }>();
  const uniqueTransactions = Array.from(transactionsById.values()).sort((a: any, b: any) => (
    new Date(b.created_at || b.date || 0).getTime() - new Date(a.created_at || a.date || 0).getTime()
  ));

  let totalContributed = 0;
  let totalWithdrawn = 0;
  for (const transaction of uniqueTransactions) {
    const amount = toMoneyNumber(transaction.amount);
    const userId = String(transaction.user_id || '');
    const bucket = periodByUser.get(userId) || { contributed: 0, withdrawn: 0 };
    if (isPotWithdrawal(transaction)) {
      bucket.withdrawn += amount;
      totalWithdrawn += amount;
    } else {
      bucket.contributed += amount;
      totalContributed += amount;
    }
    if (userId) periodByUser.set(userId, bucket);
  }

  return {
    report_type: 'SHARED_POT',
    range: {
      key: range.key,
      start: range.start.toISOString(),
      end: range.end.toISOString(),
    },
    pot: {
      id: pot.id,
      name: pot.name,
      purpose: pot.purpose,
      currency: pot.currency || 'TZS',
      target_amount: toMoneyNumber(pot.target_amount),
      current_amount: toMoneyNumber(pot.current_amount),
      status: pot.status,
    },
    summary: {
      currency: pot.currency || 'TZS',
      total_contributed: totalContributed,
      total_withdrawn: totalWithdrawn,
      net_movement: totalContributed - totalWithdrawn,
      transaction_count: uniqueTransactions.length,
      audit_entry_count: ledgerRows.length,
      member_count: members.length,
      current_amount: toMoneyNumber(pot.current_amount),
      target_amount: toMoneyNumber(pot.target_amount),
    },
    members: (members || []).map((member: any) => {
      const period = periodByUser.get(String(member.user_id)) || { contributed: 0, withdrawn: 0 };
      return {
        ...member,
        users: usersById.get(String(member.user_id)) || null,
        period_contributed_amount: period.contributed,
        period_withdrawn_amount: period.withdrawn,
        period_net_amount: period.contributed - period.withdrawn,
      };
    }),
    transactions: uniqueTransactions.map((transaction: any) => ({
      ...transaction,
      users: usersById.get(String(transaction.user_id)) || null,
      activity_label: potActivityLabel(transaction),
      direction: isPotWithdrawal(transaction) ? 'OUT' : 'IN',
    })),
    ledger: (ledgerRows || []).map((entry: any) => ({
      ...entry,
      transaction: transactionsById.get(String(entry.transaction_id)) || null,
    })),
    generatedAt: new Date().toISOString(),
    issuer: 'ORBI FINANCIAL TECHNOLOGIES',
  };
};

export const registerSharedPotRoutes = (v1: Router, deps: Deps) => {
  const {
    authenticate,
    getSupabase,
    getAdminSupabase,
    SharedPotCreateSchema,
    SharedPotUpdateSchema,
    SharedPotMemberAddSchema,
    SharedPotInviteResponseSchema,
    SharedPotContributionSchema,
    SharedPotWithdrawSchema,
    wealthNumber,
    resolveWealthSourceWallet,
    resolveSharedPotMembership,
    canManageSharedPot,
    canContributeToSharedPot,
    resolveUserBySharedPotIdentifier,
    expireSharedPotInvitationIfNeeded,
    OTPService,
  } = deps;

  v1.get('/wealth/shared-pots', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data: memberships, error: memberError } = await sb
        .from('shared_pot_members')
        .select('pot_id, role')
        .eq('user_id', session.sub);
      if (memberError) return res.status(400).json({ success: false, error: memberError.message });

      const memberPotIds = Array.from(new Set((memberships || []).map((item: any) => String(item.pot_id || '')).filter(Boolean)));
      let query = sb
        .from('shared_pots')
        .select('*')
        .eq('owner_user_id', session.sub);
      if (memberPotIds.length > 0) {
        query = sb
          .from('shared_pots')
          .select('*')
          .or([
            `owner_user_id.eq.${session.sub}`,
            `id.in.(${memberPotIds.join(',')})`,
          ].join(','));
      }
      const { data, error } = await query.order('created_at', { ascending: false });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const membershipByPot = new Map(
        (memberships || []).map((item: any) => [String(item.pot_id), String(item.role || 'CONTRIBUTOR').toUpperCase()]),
      );
      const items = (data || []).map((pot: any) => ({
        ...pot,
        my_role: pot.owner_user_id === session.sub
          ? 'OWNER'
          : (membershipByPot.get(String(pot.id)) || 'CONTRIBUTOR'),
        is_owner: pot.owner_user_id === session.sub,
      }));
      res.json({ success: true, data: { pots: items } });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pots', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedPotCreateSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const governance = await buildGovernancePayload(sb, session.sub, payload);
      const { data, error } = await sb.rpc('create_shared_pot_v1', {
        p_actor_user_id: session.sub,
        p_name: payload.name,
        p_purpose: payload.purpose || null,
        p_currency: payload.currency?.toUpperCase() || 'TZS',
        p_target_amount: payload.target_amount || 0,
        p_access_model: governance.access_model,
        p_idempotency_key: payload.idempotency_key || crypto.randomUUID(),
        p_metadata: {
          created_from: 'mobile_app',
          governance_model: governance.governance_model,
          withdrawal_policy: governance.withdrawal_policy,
        },
      });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const potId = data?.pot?.id;
      let pot = data?.pot || null;
      if (potId) {
        const { data: governedPot, error: governanceError } = await sb
          .from('shared_pots')
          .update({
            organization_id: governance.organization_id,
            governance_model: governance.governance_model,
            withdrawal_policy: governance.withdrawal_policy,
            min_withdrawal_approvals: governance.min_withdrawal_approvals,
            withdrawal_limit_amount: governance.withdrawal_limit_amount,
            maturity_at: governance.maturity_at,
            require_withdrawal_reason: governance.require_withdrawal_reason,
            updated_at: new Date().toISOString(),
          })
          .eq('id', potId)
          .eq('owner_user_id', session.sub)
          .select('*')
          .single();
        if (governanceError) return res.status(400).json({ success: false, error: governanceError.message });
        pot = governedPot;
      }
      res.json({
        success: true,
        data: pot,
        idempotent: Boolean(data?.idempotent),
      });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.patch('/wealth/shared-pots/:id', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedPotUpdateSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot, membership } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      if (!canManageSharedPot(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_ACCESS_DENIED' });
      }
      const updatePayload: any = {
        updated_at: new Date().toISOString(),
      };
      if (payload.name !== undefined) updatePayload.name = payload.name;
      if (payload.purpose !== undefined) updatePayload.purpose = payload.purpose;
      if (payload.currency !== undefined) updatePayload.currency = payload.currency.toUpperCase();
      if (payload.target_amount !== undefined) updatePayload.target_amount = payload.target_amount;
      if (payload.access_model !== undefined) updatePayload.access_model = payload.access_model;
      if (
        payload.access_model !== undefined ||
        payload.governance_model !== undefined ||
        payload.withdrawal_policy !== undefined ||
        payload.min_withdrawal_approvals !== undefined ||
        payload.withdrawal_limit_amount !== undefined ||
        payload.maturity_at !== undefined ||
        payload.require_withdrawal_reason !== undefined
      ) {
        const governance = await buildGovernancePayload(sb, session.sub, {
          access_model: payload.access_model ?? pot.access_model ?? undefined,
          governance_model: payload.governance_model,
          withdrawal_policy: payload.withdrawal_policy,
          min_withdrawal_approvals: payload.min_withdrawal_approvals,
          withdrawal_limit_amount: payload.withdrawal_limit_amount,
          maturity_at: payload.maturity_at,
          require_withdrawal_reason: payload.require_withdrawal_reason,
        });
        updatePayload.access_model = payload.access_model ?? updatePayload.access_model;
        updatePayload.organization_id = governance.organization_id;
        updatePayload.governance_model = governance.governance_model;
        updatePayload.withdrawal_policy = governance.withdrawal_policy;
        updatePayload.min_withdrawal_approvals = governance.min_withdrawal_approvals;
        updatePayload.withdrawal_limit_amount = governance.withdrawal_limit_amount;
        updatePayload.maturity_at = governance.maturity_at;
        updatePayload.require_withdrawal_reason = governance.require_withdrawal_reason;
      }
      if (payload.status !== undefined) updatePayload.status = payload.status;
      const { data, error } = await sb
        .from('shared_pots')
        .update(updatePayload)
        .eq('id', req.params.id)
        .eq('owner_user_id', session.sub)
        .select('*')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-pots/:id/members', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      const { data, error } = await sb
        .from('shared_pot_members')
        .select('id,pot_id,user_id,role,contribution_target,contributed_amount,metadata,created_at')
        .eq('pot_id', pot.id)
        .order('created_at', { ascending: true });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const usersById = await fetchUsersById(sb, compactIds(data || [], 'user_id'));
      const members = (data || []).map((member: any) => ({
        ...member,
        users: usersById.get(String(member.user_id)) || null,
      }));
      res.json({ success: true, data: { members } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-pots/:id/report', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const range = resolveReportRange(req.query.range);
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot } = await resolveSharedPotMembership(sb, req.params.id, session.sub);

      const { data: memberRows, error: memberError } = await sb
        .from('shared_pot_members')
        .select('id,pot_id,user_id,role,contribution_target,contributed_amount,metadata,created_at')
        .eq('pot_id', pot.id)
        .order('created_at', { ascending: true });
      if (memberError) return res.status(400).json({ success: false, error: memberError.message });

      const { data: ledgerRows, error: ledgerError } = await sb
        .from('financial_ledger')
        .select('id,transaction_id,user_id,wallet_id,shared_pot_id,bucket_type,entry_side,entry_type,amount,balance_after,description,created_at')
        .eq('shared_pot_id', pot.id)
        .gte('created_at', range.start.toISOString())
        .lte('created_at', range.end.toISOString())
        .order('created_at', { ascending: false });
      if (ledgerError) return res.status(400).json({ success: false, error: ledgerError.message });

      const transactionIds = compactIds(ledgerRows || [], 'transaction_id');
      const transactionRowsById = new Map<string, any>();
      if (transactionIds.length) {
        const { data: txRows, error: txError } = await sb
          .from('transactions')
          .select('*')
          .in('id', transactionIds)
          .order('created_at', { ascending: false });
        if (txError) return res.status(400).json({ success: false, error: txError.message });
        for (const row of txRows || []) {
          if (row?.id) transactionRowsById.set(String(row.id), row);
        }
      }

      const { data: metadataTxRows, error: metadataTxError } = await sb
        .from('transactions')
        .select('*')
        .contains('metadata', { shared_pot_id: pot.id })
        .gte('created_at', range.start.toISOString())
        .lte('created_at', range.end.toISOString())
        .order('created_at', { ascending: false });
      if (!metadataTxError) {
        for (const row of metadataTxRows || []) {
          if (row?.id) transactionRowsById.set(String(row.id), row);
        }
      }
      const transactionRows = Array.from(transactionRowsById.values());

      const userIds = Array.from(new Set([
        ...compactIds(memberRows || [], 'user_id'),
        ...compactIds(ledgerRows || [], 'user_id'),
        ...compactIds(transactionRows || [], 'user_id'),
      ]));
      const usersById = await fetchUsersById(sb, userIds);
      res.json({
        success: true,
        data: buildSharedPotReport(pot, memberRows || [], ledgerRows || [], transactionRows, usersById, range),
      });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-pots/:id/invitations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot, membership } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      if (!canManageSharedPot(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_ACCESS_DENIED' });
      }
      const { data, error } = await sb
        .from('shared_pot_invitations')
        .select('id,pot_id,inviter_user_id,invitee_user_id,invitee_identifier,role,status,message,responded_at,expires_at,metadata,created_at')
        .eq('pot_id', pot.id)
        .order('created_at', { ascending: false });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const usersById = await fetchUsersById(sb, compactIds(data || [], 'invitee_user_id'));
      const invitations = (data || []).map((invite: any) => ({
        ...invite,
        users: usersById.get(String(invite.invitee_user_id)) || null,
      }));
      res.json({ success: true, data: { invitations } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-pot-invitations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data, error } = await sb
        .from('shared_pot_invitations')
        .select('id,pot_id,inviter_user_id,invitee_user_id,invitee_identifier,role,status,message,responded_at,expires_at,metadata,created_at')
        .eq('invitee_user_id', session.sub)
        .order('created_at', { ascending: false });
      if (error) return res.status(400).json({ success: false, error: error.message });

      const potsById = await fetchSharedPotsById(sb, compactIds(data || [], 'pot_id'));
      const usersById = await fetchUsersById(sb, compactIds(data || [], 'inviter_user_id'));
      const invitations = [];
      for (const invite of data || []) {
        invitations.push(await expireSharedPotInvitationIfNeeded(sb, {
          ...invite,
          shared_pots: potsById.get(String(invite.pot_id)) || null,
          users: usersById.get(String(invite.inviter_user_id)) || null,
        }));
      }
      res.json({ success: true, data: { invitations } });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pots/:id/invitations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedPotMemberAddSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot, membership } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      if (!canManageSharedPot(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_ACCESS_DENIED' });
      }
      if (normalizeUpper(pot.access_model, 'INVITE') === 'PRIVATE') {
        return res.status(400).json({ success: false, error: 'SHARED_POT_PRIVATE_INVITES_DISABLED' });
      }
      const verifiedInviteeUserId = String(
        payload.invitee_user_id ||
        payload.inviteeUserId ||
        payload.recipient_id ||
        payload.recipientId ||
        '',
      ).trim();
      const memberUser = verifiedInviteeUserId
        ? await resolveUserBySharedPotIdentifier(sb, verifiedInviteeUserId)
        : await resolveUserBySharedPotIdentifier(sb, payload.identifier);
      if (!memberUser?.id) {
        return res.status(404).json({ success: false, error: 'USER_NOT_FOUND' });
      }
      if (normalizeUpper(pot.access_model, 'INVITE') === 'ORG') {
        const inviteeOrg = await resolveActorOrganization(sb, String(memberUser.id));
        if (!pot.organization_id || String(inviteeOrg?.organization_id || '') !== String(pot.organization_id)) {
          return res.status(403).json({ success: false, error: 'SHARED_POT_ORG_MEMBER_REQUIRED' });
        }
      }
      if (String(memberUser.id) === String(pot.owner_user_id)) {
        return res.status(400).json({ success: false, error: 'OWNER_ALREADY_MEMBER' });
      }
      const { data: existingMember, error: existingMemberError } = await sb
        .from('shared_pot_members')
        .select('id')
        .eq('pot_id', pot.id)
        .eq('user_id', memberUser.id)
        .maybeSingle();
      if (existingMemberError) {
        return res.status(400).json({ success: false, error: existingMemberError.message });
      }
      if (existingMember) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_MEMBER_ALREADY_EXISTS' });
      }

      const { data: pendingInvite, error: pendingInviteError } = await sb
        .from('shared_pot_invitations')
        .select('*')
        .eq('pot_id', pot.id)
        .eq('invitee_user_id', memberUser.id)
        .eq('status', 'PENDING')
        .order('created_at', { ascending: false })
        .limit(1)
        .single();
      if (pendingInviteError && pendingInviteError.code !== 'PGRST116') {
        return res.status(400).json({ success: false, error: pendingInviteError.message });
      }
      if (pendingInvite) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_INVITE_ALREADY_PENDING' });
      }

      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
      const { data, error } = await sb
        .from('shared_pot_invitations')
        .insert({
          pot_id: pot.id,
          inviter_user_id: session.sub,
          invitee_user_id: memberUser.id,
          invitee_identifier: payload.identifier,
          role: payload.role || 'CONTRIBUTOR',
          message: payload.message || null,
          expires_at: expiresAt,
          metadata: {
            invited_by: session.sub,
            invite_source: 'shared_pot_member_sheet',
            identifier: payload.identifier,
          },
        })
        .select('id,pot_id,inviter_user_id,invitee_user_id,invitee_identifier,role,status,message,responded_at,expires_at,metadata,created_at')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });

      try {
        await Messaging.dispatch(
          String(memberUser.id),
          'info',
          'Shared pot invitation',
          `${session.user?.user_metadata?.full_name || 'A member'} invited you to join "${pot.name}" as ${String(payload.role || 'CONTRIBUTOR').toLowerCase()}.`,
          {
            push: true,
            sms: false,
            email: true,
            eventCode: 'SHARED_POT_INVITATION',
            variables: {
              pot_name: pot.name,
              role: payload.role || 'CONTRIBUTOR',
              invite_id: data.id,
            },
          },
        );
      } catch (notificationError: any) {
        console.warn('[Wealth][SharedPot] Invitation notification deferred', {
          invitationId: data.id,
          code: String(notificationError?.code || ''),
        });
      }

      res.json({
        success: true,
        data: {
          invitation: {
            ...data,
            invitee: {
              id: memberUser.id,
              full_name: memberUser.full_name,
              email: memberUser.email,
              phone: memberUser.phone,
            },
          },
        },
      });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pot-invitations/:id/respond', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedPotInviteResponseSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });

      const { data, error } = await sb.rpc('respond_shared_pot_invitation_v1', {
        p_actor_user_id: session.sub,
        p_invitation_id: req.params.id,
        p_action: payload.action,
        p_idempotency_key: payload.idempotency_key || crypto.randomUUID(),
      });
      if (error) return res.status(400).json({ success: false, error: error.message });
      res.json({ success: true, data });
    } catch (e: any) {
      const status = e.message === 'SHARED_POT_INVITE_ACCESS_DENIED' ? 403 : 400;
      res.status(status).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pots/:id/contribute', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedPotContributionSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot, membership } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      if (!canContributeToSharedPot(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_CONTRIBUTION_DENIED' });
      }

      const data = await contributeToSharedPot({
        sb,
        sessionUserId: session.sub,
        pot,
        membership,
        payload,
        wealthNumber,
        resolveWealthSourceWallet,
      });
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(
        ['SHARED_POT_ACCESS_DENIED', 'SHARED_POT_CONTRIBUTION_DENIED'].includes(e.message) ? 403 : 400,
      ).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-pots/:id/withdrawal-requests', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      const { data, error } = await sb
        .from('shared_pot_withdrawal_requests')
        .select('*')
        .eq('pot_id', pot.id)
        .order('created_at', { ascending: false })
        .limit(100);
      if (error) return res.status(400).json({ success: false, error: error.message });
      const usersById = await fetchUsersById(sb, compactIds(data || [], 'requester_user_id'));
      res.json({
        success: true,
        data: {
          requests: (data || []).map((request: any) => ({
            ...request,
            users: usersById.get(String(request.requester_user_id)) || null,
          })),
        },
      });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pot-withdrawal-requests/:id/respond', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const action = normalizeUpper(req.body?.action, '');
      const note = String(req.body?.note || '').trim() || null;
      if (!['APPROVE', 'REJECT'].includes(action)) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_WITHDRAWAL_ACTION_INVALID' });
      }
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });

      const { data: request, error: requestError } = await sb
        .from('shared_pot_withdrawal_requests')
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();
      if (requestError) return res.status(400).json({ success: false, error: requestError.message });
      if (!request) return res.status(404).json({ success: false, error: 'SHARED_POT_WITHDRAWAL_REQUEST_NOT_FOUND' });
      if (String(request.status || '').toUpperCase() !== 'PENDING') {
        return res.status(400).json({ success: false, error: 'SHARED_POT_WITHDRAWAL_REQUEST_NOT_PENDING' });
      }

      const { pot, membership } = await resolveSharedPotMembership(sb, request.pot_id, session.sub);
      if (!canManageSharedPot(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_WITHDRAW_APPROVAL_DENIED' });
      }
      if (String(request.requester_user_id) === String(session.sub)) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_WITHDRAW_SELF_APPROVAL_DENIED' });
      }

      const approvals = normalizeApprovals(request.approvals);
      if (approvals.some((approval) => String(approval?.user_id) === String(session.sub))) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_WITHDRAW_ALREADY_REVIEWED' });
      }

      if (action === 'REJECT') {
        const updatedApprovals = [
          ...approvals,
          {
            user_id: session.sub,
            role: membership.role || 'MANAGER',
            action,
            note,
            at: new Date().toISOString(),
          },
        ];
        const { data, error } = await sb
          .from('shared_pot_withdrawal_requests')
          .update({
            status: 'REJECTED',
            approvals: updatedApprovals,
            rejection_reason: note,
            decided_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', request.id)
          .select('*')
          .single();
        if (error) return res.status(400).json({ success: false, error: error.message });
        return res.json({ success: true, data: { request: data } });
      }

      validateWithdrawalPolicy(pot, { amount: request.amount, reason: request.reason });
      const updatedApprovals = [
        ...approvals,
        {
          user_id: session.sub,
          role: membership.role || 'MANAGER',
          action,
          note,
          at: new Date().toISOString(),
        },
      ];
      const hasEnoughApprovals = approvalCount(updatedApprovals) >= Number(request.required_approvals || 1);
      if (!hasEnoughApprovals) {
        const { data, error } = await sb
          .from('shared_pot_withdrawal_requests')
          .update({
            approvals: updatedApprovals,
            updated_at: new Date().toISOString(),
          })
          .eq('id', request.id)
          .select('*')
          .single();
        if (error) return res.status(400).json({ success: false, error: error.message });
        return res.json({ success: true, data: { request: data, requires_more_approvals: true } });
      }

      const { membership: requesterMembership } = await resolveSharedPotMembership(
        sb,
        request.pot_id,
        String(request.requester_user_id),
      );
      const withdrawal = await withdrawFromSharedPot({
        sb,
        sessionUserId: String(request.requester_user_id),
        pot,
        membership: requesterMembership,
        payload: {
          amount: Number(request.amount),
          target_wallet_id: request.target_wallet_id,
          idempotency_key: `approved_${request.id}`,
        },
        wealthNumber,
        resolveWealthSourceWallet,
      });
      const { data, error } = await sb
        .from('shared_pot_withdrawal_requests')
        .update({
          status: 'EXECUTED',
          approvals: updatedApprovals,
          transaction_id: withdrawal.transaction?.id || null,
          decided_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', request.id)
        .select('*')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      res.json({ success: true, data: { request: data, ...withdrawal } });
    } catch (e: any) {
      res.status(
        ['SHARED_POT_ACCESS_DENIED', 'SHARED_POT_WITHDRAW_APPROVAL_DENIED', 'SHARED_POT_WITHDRAW_SELF_APPROVAL_DENIED'].includes(e.message) ? 403 : 400,
      ).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pots/:id/delete-request', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot, membership } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      if (!canManageSharedPot(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_DELETE_DENIED' });
      }
      if (toMoneyNumber(pot.current_amount) >= 1) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_DELETE_BALANCE_NOT_EMPTY' });
      }

      const otpRequestId = String(req.body?.otp_request_id || '');
      const otpCode = String(req.body?.otp_code || '');
      if (!otpRequestId || !otpCode) {
        if (!OTPService) return res.status(503).json({ success: false, error: 'OTP_SERVICE_UNAVAILABLE' });
        const { data: user } = await sb
          .from('users')
          .select('id,email,phone')
          .eq('id', session.sub)
          .maybeSingle();
        const contact = String(user?.phone || user?.email || '').trim();
        const type = contact.includes('@') ? 'email' : 'sms';
        const challenge = await OTPService.generateAndSend(session.sub, contact, 'SHARED_POT_DELETE', type, 'Orbi App', true);
        return res.status(202).json({
          success: false,
          error: 'SECURITY_CHALLENGE',
          challenge: {
            otp_request_id: challenge.requestId,
            delivery_type: challenge.deliveryType || type,
            delivery_contact: challenge.deliveryContact || contact,
          },
        });
      }
      const verified = OTPService ? await OTPService.verify(otpRequestId, otpCode, session.sub) : false;
      if (!verified) return res.status(403).json({ success: false, error: 'INVALID_OTP' });

      const { data: existing, error: existingError } = await sb
        .from('shared_pot_delete_requests')
        .select('*')
        .eq('pot_id', pot.id)
        .in('status', ['PENDING_APPROVAL', 'SCHEDULED'])
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (existingError) return res.status(400).json({ success: false, error: existingError.message });
      if (existing) return res.json({ success: true, data: { request: existing, already_pending: true } });

      const { data, error } = await sb
        .from('shared_pot_delete_requests')
        .insert({
          pot_id: pot.id,
          requested_by: session.sub,
          required_approvals: 3,
          reason: req.body?.reason || null,
          otp_verified_at: new Date().toISOString(),
          metadata: {
            pot_name: pot.name,
            access_model: pot.access_model || 'INVITE',
            requested_role: membership.role || 'MANAGER',
          },
        })
        .select('*')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      await notifyPotMembers(
        sb,
        pot.id,
        'Fungu archive request',
        `${pot.name} has an archive request pending approvals. You can still cancel before it is archived.`,
        { potId: pot.id, requestId: data.id, eventCode: 'SHARED_POT_DELETE_REQUESTED' },
      );
      res.json({ success: true, data: { request: data, requires_approval: true } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pot-delete-requests/:id/respond', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const action = normalizeUpper(req.body?.action, '');
      if (!['APPROVE', 'REJECT'].includes(action)) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_DELETE_ACTION_INVALID' });
      }
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data: request, error: requestError } = await sb
        .from('shared_pot_delete_requests')
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();
      if (requestError) return res.status(400).json({ success: false, error: requestError.message });
      if (!request) return res.status(404).json({ success: false, error: 'SHARED_POT_DELETE_REQUEST_NOT_FOUND' });
      if (String(request.status || '').toUpperCase() !== 'PENDING_APPROVAL') {
        return res.status(400).json({ success: false, error: 'SHARED_POT_DELETE_REQUEST_NOT_PENDING' });
      }
      const { pot, membership } = await resolveSharedPotMembership(sb, request.pot_id, session.sub);
      if (!canManageSharedPot(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_DELETE_APPROVAL_DENIED' });
      }
      if (toMoneyNumber(pot.current_amount) >= 1) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_DELETE_BALANCE_NOT_EMPTY' });
      }
      const approvals = normalizeApprovals(request.approvals);
      if (approvals.some((approval) => String(approval?.user_id) === String(session.sub))) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_DELETE_ALREADY_REVIEWED' });
      }
      const updatedApprovals = [
        ...approvals,
        {
          user_id: session.sub,
          role: membership.role || 'MANAGER',
          action,
          note: req.body?.note || null,
          at: new Date().toISOString(),
        },
      ];
      if (action === 'REJECT') {
        const { data, error } = await sb.from('shared_pot_delete_requests').update({
          status: 'REJECTED',
          approvals: updatedApprovals,
          updated_at: new Date().toISOString(),
        }).eq('id', request.id).select('*').single();
        if (error) return res.status(400).json({ success: false, error: error.message });
        await notifyPotMembers(sb, pot.id, 'Fungu archive rejected', `${pot.name} archive request was rejected.`, { potId: pot.id, requestId: data.id, eventCode: 'SHARED_POT_DELETE_REJECTED' });
        return res.json({ success: true, data: { request: data } });
      }
      if (approvalCount(updatedApprovals) < Number(request.required_approvals || 3)) {
        const { data, error } = await sb.from('shared_pot_delete_requests').update({
          approvals: updatedApprovals,
          updated_at: new Date().toISOString(),
        }).eq('id', request.id).select('*').single();
        if (error) return res.status(400).json({ success: false, error: error.message });
        return res.json({ success: true, data: { request: data, requires_more_approvals: true } });
      }
      const scheduledAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
      const { data, error } = await sb.from('shared_pot_delete_requests').update({
        status: 'SCHEDULED',
        approvals: updatedApprovals,
        scheduled_archive_at: scheduledAt,
        updated_at: new Date().toISOString(),
      }).eq('id', request.id).select('*').single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      await sb.from('shared_pots').update({
        metadata: {
          ...(pot.metadata || {}),
          delete_request_id: data.id,
          pending_archive: true,
          scheduled_archive_at: scheduledAt,
        },
        updated_at: new Date().toISOString(),
      }).eq('id', pot.id);
      await notifyPotMembers(sb, pot.id, 'Fungu archive scheduled', `${pot.name} will be archived after 24 hours unless cancelled.`, { potId: pot.id, requestId: data.id, scheduledAt, eventCode: 'SHARED_POT_DELETE_SCHEDULED' });
      res.json({ success: true, data: { request: data, scheduled_archive_at: scheduledAt } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pot-delete-requests/:id/cancel', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data: request, error: requestError } = await sb
        .from('shared_pot_delete_requests')
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();
      if (requestError) return res.status(400).json({ success: false, error: requestError.message });
      if (!request) return res.status(404).json({ success: false, error: 'SHARED_POT_DELETE_REQUEST_NOT_FOUND' });
      if (!['PENDING_APPROVAL', 'SCHEDULED'].includes(String(request.status || '').toUpperCase())) {
        return res.status(400).json({ success: false, error: 'SHARED_POT_DELETE_CANCEL_CLOSED' });
      }
      const { pot, membership } = await resolveSharedPotMembership(sb, request.pot_id, session.sub);
      if (!canManageSharedPot(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_DELETE_CANCEL_DENIED' });
      }
      const { data, error } = await sb.from('shared_pot_delete_requests').update({
        status: 'CANCELLED',
        updated_at: new Date().toISOString(),
      }).eq('id', request.id).select('*').single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      await sb.from('shared_pots').update({
        metadata: {
          ...(pot.metadata || {}),
          pending_archive: false,
          delete_request_cancelled_at: new Date().toISOString(),
        },
        updated_at: new Date().toISOString(),
      }).eq('id', pot.id);
      await notifyPotMembers(sb, pot.id, 'Fungu archive cancelled', `${pot.name} archive request was cancelled.`, { potId: pot.id, requestId: data.id, eventCode: 'SHARED_POT_DELETE_CANCELLED' });
      res.json({ success: true, data: { request: data } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pot-delete-requests/process-due', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data: actor } = await sb
        .from('users')
        .select('id,org_role')
        .eq('id', session.sub)
        .maybeSingle();
      if (!['ADMIN', 'SIGNATORY'].includes(String(actor?.org_role || '').toUpperCase())) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_ARCHIVE_PROCESS_DENIED' });
      }
      const { data: dueRows, error } = await sb
        .from('shared_pot_delete_requests')
        .select('*')
        .eq('status', 'SCHEDULED')
        .lte('scheduled_archive_at', new Date().toISOString())
        .limit(50);
      if (error) return res.status(400).json({ success: false, error: error.message });
      const archived = [];
      for (const request of dueRows || []) {
        const { data: pot } = await sb.from('shared_pots').select('*').eq('id', request.pot_id).maybeSingle();
        if (!pot || toMoneyNumber(pot.current_amount) >= 1) continue;
        await sb.from('shared_pots').update({
          status: 'ARCHIVED',
          metadata: {
            ...(pot.metadata || {}),
            archived_by_delete_request: request.id,
            archived_at: new Date().toISOString(),
          },
          updated_at: new Date().toISOString(),
        }).eq('id', pot.id);
        const { data: updated } = await sb.from('shared_pot_delete_requests').update({
          status: 'ARCHIVED',
          archived_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }).eq('id', request.id).select('*').single();
        archived.push(updated || request);
        await notifyPotMembers(sb, pot.id, 'Fungu archived', `${pot.name} has been archived. It remains available under Archived.`, { potId: pot.id, requestId: request.id, eventCode: 'SHARED_POT_ARCHIVED' });
      }
      res.json({ success: true, data: { archived } });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-pots/:id/withdraw', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedPotWithdrawSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot, membership } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      const memberRole = String(membership.role || '');
      validateWithdrawalPolicy(pot, payload);
      if (withdrawalRequiresApproval(pot, memberRole)) {
        if (!roleCanRequestWithdrawal(memberRole)) {
          return res.status(403).json({ success: false, error: 'SHARED_POT_WITHDRAW_REQUEST_DENIED' });
        }
        const data = await createSharedPotWithdrawalRequest({
          sb,
          sessionUserId: session.sub,
          pot,
          membership,
          payload,
          wealthNumber,
          resolveWealthSourceWallet,
        });
        return res.json({ success: true, data });
      }
      if (!roleCanWithdrawDirectly(memberRole, String(pot.withdrawal_policy || 'OWNER_OR_MANAGER'))) {
        return res.status(403).json({ success: false, error: 'SHARED_POT_WITHDRAW_DENIED' });
      }
      const data = await withdrawFromSharedPot({
        sb,
        sessionUserId: session.sub,
        pot,
        membership,
        payload,
        wealthNumber,
        resolveWealthSourceWallet,
      });
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(e.message === 'SHARED_POT_WITHDRAW_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });
};
