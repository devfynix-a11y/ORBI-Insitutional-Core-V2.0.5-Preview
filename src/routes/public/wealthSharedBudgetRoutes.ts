import { type RequestHandler, type Router } from 'express';
import { Messaging } from '../../../backend/features/MessagingService.js';
import { requireIdempotencyKey, resolveIdempotencyHeader } from '../../middleware/security/idempotency.js';
import { resolveOperatingWealthWalletStrict } from './wealthShared.js';

type Deps = {
  authenticate: RequestHandler;
  LogicCore: any;
  getSupabase: () => any;
  getAdminSupabase: () => any;
  SharedBudgetCreateSchema: any;
  SharedBudgetUpdateSchema: any;
  SharedBudgetMemberAddSchema: any;
  SharedBudgetInviteResponseSchema: any;
  SharedBudgetApprovalResponseSchema: any;
  SharedBudgetSpendSchema: any;
  wealthNumber: (value: any) => number;
  resolveSharedBudgetMembership: (sb: any, budgetId: string, userId: string) => Promise<any>;
  canManageSharedBudget: (role: string) => boolean;
  canSpendFromSharedBudget: (role: string) => boolean;
  canReviewSharedBudgetSpend: (role: string) => boolean;
  resolveUserBySharedBudgetIdentifier: (sb: any, identifier: string) => Promise<any>;
  expireSharedBudgetInvitationIfNeeded: (sb: any, invite: any) => Promise<any>;
  executeSharedBudgetSpend: (sb: any, input: any) => Promise<any>;
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

const fetchSharedBudgetsById = async (sb: any, budgetIds: string[]): Promise<Map<string, any>> => {
  if (!budgetIds.length) return new Map();
  const { data, error } = await sb
    .from('shared_budgets')
    .select('id, name, purpose, currency, budget_limit, spent_amount, period_type, approval_mode, status')
    .in('id', budgetIds);
  if (error) throw new Error(error.message);
  return new Map((data || []).map((budget: any) => [String(budget.id), budget]));
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

const buildSharedBudgetReport = (budget: any, members: any[], transactions: any[], usersById: Map<string, any>, range: ReturnType<typeof resolveReportRange>) => {
  const periodByUser = new Map<string, number>();
  const totalSpent = (transactions || []).reduce((sum: number, transaction: any) => {
    const amount = toMoneyNumber(transaction.amount);
    const userId = String(transaction.member_user_id || '');
    if (userId) periodByUser.set(userId, (periodByUser.get(userId) || 0) + amount);
    return sum + amount;
  }, 0);

  return {
    report_type: 'SHARED_BUDGET',
    range: {
      key: range.key,
      start: range.start.toISOString(),
      end: range.end.toISOString(),
    },
    budget: {
      id: budget.id,
      name: budget.name,
      purpose: budget.purpose,
      currency: budget.currency || 'TZS',
      budget_limit: toMoneyNumber(budget.budget_limit),
      spent_amount: toMoneyNumber(budget.spent_amount),
      remaining_amount: Math.max(0, toMoneyNumber(budget.budget_limit) - toMoneyNumber(budget.spent_amount)),
      period_type: budget.period_type,
      status: budget.status,
    },
    summary: {
      currency: budget.currency || 'TZS',
      total_spent: totalSpent,
      transaction_count: transactions.length,
      member_count: members.length,
      budget_limit: toMoneyNumber(budget.budget_limit),
      remaining_amount: Math.max(0, toMoneyNumber(budget.budget_limit) - toMoneyNumber(budget.spent_amount)),
    },
    members: (members || []).map((member: any) => ({
      ...member,
      users: usersById.get(String(member.user_id)) || null,
      period_spent_amount: periodByUser.get(String(member.user_id)) || 0,
    })),
    transactions: (transactions || []).map((transaction: any) => ({
      ...transaction,
      users: usersById.get(String(transaction.member_user_id)) || null,
    })),
    generatedAt: new Date().toISOString(),
    issuer: 'ORBI FINANCIAL TECHNOLOGIES',
  };
};

export const registerSharedBudgetRoutes = (v1: Router, deps: Deps) => {
  const {
    authenticate,
    LogicCore,
    getSupabase,
    getAdminSupabase,
    SharedBudgetCreateSchema,
    SharedBudgetUpdateSchema,
    SharedBudgetMemberAddSchema,
    SharedBudgetInviteResponseSchema,
    SharedBudgetApprovalResponseSchema,
    SharedBudgetSpendSchema,
    wealthNumber,
    resolveSharedBudgetMembership,
    canManageSharedBudget,
    canSpendFromSharedBudget,
    canReviewSharedBudgetSpend,
    resolveUserBySharedBudgetIdentifier,
    expireSharedBudgetInvitationIfNeeded,
    executeSharedBudgetSpend,
  } = deps;

  v1.get('/wealth/shared-budgets', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data: memberships, error: memberError } = await sb
        .from('shared_budget_members')
        .select('budget_id, role')
        .eq('user_id', session.sub);
      if (memberError) return res.status(400).json({ success: false, error: memberError.message });

      const memberBudgetIds = Array.from(new Set((memberships || []).map((item: any) => String(item.budget_id || '')).filter(Boolean)));
      let query = sb
        .from('shared_budgets')
        .select('*')
        .eq('owner_user_id', session.sub);
      if (memberBudgetIds.length > 0) {
        query = sb
          .from('shared_budgets')
          .select('*')
          .or([
            `owner_user_id.eq.${session.sub}`,
            `id.in.(${memberBudgetIds.join(',')})`,
          ].join(','));
      }
      const { data, error } = await query.order('created_at', { ascending: false });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const membershipByBudget = new Map(
        (memberships || []).map((item: any) => [String(item.budget_id), String(item.role || 'SPENDER').toUpperCase()]),
      );
      const items = (data || []).map((budget: any) => ({
        ...budget,
        my_role: budget.owner_user_id === session.sub
          ? 'OWNER'
          : (membershipByBudget.get(String(budget.id)) || 'SPENDER'),
        is_owner: budget.owner_user_id === session.sub,
        remaining_amount: Math.max(0, wealthNumber(budget.budget_limit) - wealthNumber(budget.spent_amount)),
      }));
      res.json({ success: true, data: { budgets: items } });
    } catch (e: any) {
      res.status(500).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-budgets', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedBudgetCreateSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data, error } = await sb
        .from('shared_budgets')
        .insert({
          owner_user_id: session.sub,
          name: payload.name,
          purpose: payload.purpose,
          currency: payload.currency?.toUpperCase() || 'TZS',
          budget_limit: payload.budget_limit,
          spent_amount: 0,
          period_type: payload.period_type || 'MONTHLY',
          approval_mode: payload.approval_mode || 'AUTO',
          status: 'ACTIVE',
          metadata: { created_from: 'mobile_app' },
        })
        .select('*')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      await sb.from('shared_budget_members').insert({
        budget_id: data.id,
        user_id: session.sub,
        role: 'OWNER',
        spent_amount: 0,
      });
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.patch('/wealth/shared-budgets/:id', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedBudgetUpdateSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { membership } = await resolveSharedBudgetMembership(sb, req.params.id, session.sub);
      if (!canManageSharedBudget(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_BUDGET_ACCESS_DENIED' });
      }
      const updatePayload: any = { updated_at: new Date().toISOString() };
      if (payload.name !== undefined) updatePayload.name = payload.name;
      if (payload.purpose !== undefined) updatePayload.purpose = payload.purpose;
      if (payload.currency !== undefined) updatePayload.currency = payload.currency.toUpperCase();
      if (payload.budget_limit !== undefined) updatePayload.budget_limit = payload.budget_limit;
      if (payload.period_type !== undefined) updatePayload.period_type = payload.period_type;
      if (payload.approval_mode !== undefined) updatePayload.approval_mode = payload.approval_mode;
      if (payload.status !== undefined) updatePayload.status = payload.status;
      const { data, error } = await sb
        .from('shared_budgets')
        .update(updatePayload)
        .eq('id', req.params.id)
        .select('*')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(e.message === 'SHARED_BUDGET_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-budgets/:id/members', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { budget } = await resolveSharedBudgetMembership(sb, req.params.id, session.sub);
      const { data, error } = await sb
        .from('shared_budget_members')
        .select('id,budget_id,user_id,role,status,member_limit,spent_amount,metadata,created_at')
        .eq('budget_id', budget.id)
        .order('created_at', { ascending: true });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const usersById = await fetchUsersById(sb, compactIds(data || [], 'user_id'));
      const members = (data || []).map((member: any) => ({
        ...member,
        users: usersById.get(String(member.user_id)) || null,
      }));
      res.json({ success: true, data: { members } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_BUDGET_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-budgets/:id/transactions', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { budget } = await resolveSharedBudgetMembership(sb, req.params.id, session.sub);
      const { data, error } = await sb
        .from('shared_budget_transactions')
        .select('*')
        .eq('shared_budget_id', budget.id)
        .order('created_at', { ascending: false });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const usersById = await fetchUsersById(sb, compactIds(data || [], 'member_user_id'));
      const transactions = (data || []).map((transaction: any) => ({
        ...transaction,
        users: usersById.get(String(transaction.member_user_id)) || null,
      }));
      res.json({ success: true, data: { transactions } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_BUDGET_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-budgets/:id/report', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    const range = resolveReportRange(req.query.range);
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { budget } = await resolveSharedBudgetMembership(sb, req.params.id, session.sub);

      const { data: memberRows, error: memberError } = await sb
        .from('shared_budget_members')
        .select('id,budget_id,user_id,role,status,member_limit,spent_amount,metadata,created_at')
        .eq('budget_id', budget.id)
        .order('created_at', { ascending: true });
      if (memberError) return res.status(400).json({ success: false, error: memberError.message });

      const { data: transactionRows, error: transactionError } = await sb
        .from('shared_budget_transactions')
        .select('*')
        .eq('shared_budget_id', budget.id)
        .gte('created_at', range.start.toISOString())
        .lte('created_at', range.end.toISOString())
        .order('created_at', { ascending: false });
      if (transactionError) return res.status(400).json({ success: false, error: transactionError.message });

      const userIds = Array.from(new Set([
        ...compactIds(memberRows || [], 'user_id'),
        ...compactIds(transactionRows || [], 'member_user_id'),
      ]));
      const usersById = await fetchUsersById(sb, userIds);
      res.json({
        success: true,
        data: buildSharedBudgetReport(budget, memberRows || [], transactionRows || [], usersById, range),
      });
    } catch (e: any) {
      res.status(e.message === 'SHARED_BUDGET_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-budgets/:id/invitations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { budget, membership } = await resolveSharedBudgetMembership(sb, req.params.id, session.sub);
      if (!canManageSharedBudget(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_BUDGET_ACCESS_DENIED' });
      }
      const { data, error } = await sb
        .from('shared_budget_invitations')
        .select('id,budget_id,inviter_user_id,invitee_user_id,invitee_identifier,role,member_limit,status,message,responded_at,expires_at,metadata,created_at')
        .eq('budget_id', budget.id)
        .order('created_at', { ascending: false });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const usersById = await fetchUsersById(sb, compactIds(data || [], 'invitee_user_id'));
      const invitations = (data || []).map((invite: any) => ({
        ...invite,
        users: usersById.get(String(invite.invitee_user_id)) || null,
      }));
      res.json({ success: true, data: { invitations } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_BUDGET_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-budget-invitations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { data, error } = await sb
        .from('shared_budget_invitations')
        .select('id,budget_id,inviter_user_id,invitee_user_id,invitee_identifier,role,member_limit,status,message,responded_at,expires_at,metadata,created_at')
        .eq('invitee_user_id', session.sub)
        .order('created_at', { ascending: false });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const budgetsById = await fetchSharedBudgetsById(sb, compactIds(data || [], 'budget_id'));
      const usersById = await fetchUsersById(sb, compactIds(data || [], 'inviter_user_id'));
      const invitations = [];
      for (const invite of data || []) {
        invitations.push(await expireSharedBudgetInvitationIfNeeded(sb, {
          ...invite,
          shared_budgets: budgetsById.get(String(invite.budget_id)) || null,
          users: usersById.get(String(invite.inviter_user_id)) || null,
        }));
      }
      res.json({ success: true, data: { invitations } });
    } catch (e: any) {
      res.status(400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-budgets/:id/invitations', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedBudgetMemberAddSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { budget, membership } = await resolveSharedBudgetMembership(sb, req.params.id, session.sub);
      if (!canManageSharedBudget(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_BUDGET_ACCESS_DENIED' });
      }
      const verifiedInviteeUserId = String(
        payload.invitee_user_id ||
        payload.inviteeUserId ||
        payload.recipient_id ||
        payload.recipientId ||
        '',
      ).trim();
      const memberUser = verifiedInviteeUserId
        ? await resolveUserBySharedBudgetIdentifier(sb, verifiedInviteeUserId)
        : await resolveUserBySharedBudgetIdentifier(sb, payload.identifier);
      if (!memberUser?.id) {
        return res.status(404).json({ success: false, error: 'USER_NOT_FOUND' });
      }
      if (String(memberUser.id) === String(budget.owner_user_id)) {
        return res.status(400).json({ success: false, error: 'OWNER_ALREADY_MEMBER' });
      }
      const { data: existingMember, error: existingMemberError } = await sb
        .from('shared_budget_members')
        .select('id')
        .eq('budget_id', budget.id)
        .eq('user_id', memberUser.id)
        .maybeSingle();
      if (existingMemberError) return res.status(400).json({ success: false, error: existingMemberError.message });
      if (existingMember) {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_MEMBER_ALREADY_EXISTS' });
      }
      const { data: pendingInvite, error: pendingInviteError } = await sb
        .from('shared_budget_invitations')
        .select('*')
        .eq('budget_id', budget.id)
        .eq('invitee_user_id', memberUser.id)
        .eq('status', 'PENDING')
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (pendingInviteError) {
        return res.status(400).json({ success: false, error: pendingInviteError.message });
      }
      if (pendingInvite) {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_INVITE_ALREADY_PENDING' });
      }

      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
      const { data, error } = await sb
        .from('shared_budget_invitations')
        .insert({
          budget_id: budget.id,
          inviter_user_id: session.sub,
          invitee_user_id: memberUser.id,
          invitee_identifier: payload.identifier,
          role: payload.role || 'SPENDER',
          member_limit: payload.member_limit || null,
          message: payload.message || null,
          expires_at: expiresAt,
          metadata: {
            invited_by: session.sub,
            invite_source: 'shared_budget_member_sheet',
            identifier: payload.identifier,
          },
        })
        .select('id,budget_id,inviter_user_id,invitee_user_id,invitee_identifier,role,member_limit,status,message,responded_at,expires_at,metadata,created_at')
        .single();
      if (error) return res.status(400).json({ success: false, error: error.message });

      await Messaging.dispatch(
        String(memberUser.id),
        'info',
        'Shared budget invitation',
        `${session.user?.user_metadata?.full_name || 'A member'} invited you to join "${budget.name}" as ${String(payload.role || 'SPENDER').toLowerCase()}.`,
        {
          push: true,
          sms: false,
          email: true,
          eventCode: 'SHARED_BUDGET_INVITATION',
          variables: {
            budget_name: budget.name,
            role: payload.role || 'SPENDER',
            invite_id: data.id,
          },
        },
      );

      res.json({ success: true, data: { invitation: data } });
    } catch (e: any) {
      res.status(e.message === 'SHARED_BUDGET_ACCESS_DENIED' ? 403 : 400).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-budget-invitations/:id/respond', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedBudgetInviteResponseSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });

      const { data: inviteRaw, error: inviteError } = await sb
        .from('shared_budget_invitations')
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();
      if (inviteError) return res.status(400).json({ success: false, error: inviteError.message });
      if (!inviteRaw) return res.status(404).json({ success: false, error: 'SHARED_BUDGET_INVITE_NOT_FOUND' });
      const invite = await expireSharedBudgetInvitationIfNeeded(sb, inviteRaw);

      if (String(invite.invitee_user_id || '') !== String(session.sub)) {
        return res.status(403).json({ success: false, error: 'SHARED_BUDGET_INVITE_ACCESS_DENIED' });
      }
      if (String(invite.status || '').toUpperCase() !== 'PENDING') {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_INVITE_NOT_PENDING' });
      }

      if (payload.action === 'REJECT') {
        const { data, error } = await sb
          .from('shared_budget_invitations')
          .update({
            status: 'REJECTED',
            responded_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', invite.id)
          .select('*')
          .single();
        if (error) return res.status(400).json({ success: false, error: error.message });
        return res.json({ success: true, data: { invitation: data } });
      }

      const { data: existingMember, error: existingMemberError } = await sb
        .from('shared_budget_members')
        .select('id')
        .eq('budget_id', invite.budget_id)
        .eq('user_id', session.sub)
        .maybeSingle();
      if (existingMemberError) return res.status(400).json({ success: false, error: existingMemberError.message });
      if (existingMember) {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_MEMBER_ALREADY_EXISTS' });
      }

      const { data: member, error: memberError } = await sb
        .from('shared_budget_members')
        .insert({
          budget_id: invite.budget_id,
          user_id: session.sub,
          role: invite.role || 'SPENDER',
          status: 'ACTIVE',
          member_limit: invite.member_limit || null,
          spent_amount: 0,
          metadata: {
            joined_via_invitation: invite.id,
            invited_by: invite.inviter_user_id,
          },
        })
        .select('*')
        .single();
      if (memberError) return res.status(400).json({ success: false, error: memberError.message });

      const { data: updatedInvite, error: updateInviteError } = await sb
        .from('shared_budget_invitations')
        .update({
          status: 'ACCEPTED',
          responded_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', invite.id)
        .select('*')
        .single();
      if (updateInviteError) return res.status(400).json({ success: false, error: updateInviteError.message });

      res.json({ success: true, data: { invitation: updatedInvite, member } });
    } catch (e: any) {
      const status = e.message === 'SHARED_BUDGET_INVITE_ACCESS_DENIED' ? 403 : 400;
      res.status(status).json({ success: false, error: e.message });
    }
  });

  v1.get('/wealth/shared-budgets/:id/approvals', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { budget, membership } = await resolveSharedBudgetMembership(sb, req.params.id, session.sub);
      if (!canReviewSharedBudgetSpend(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_BUDGET_ACCESS_DENIED' });
      }
      const { data, error } = await sb
        .from('shared_budget_approvals')
        .select('*')
        .eq('shared_budget_id', budget.id)
        .order('created_at', { ascending: false });
      if (error) return res.status(400).json({ success: false, error: error.message });
      const usersById = await fetchUsersById(sb, Array.from(new Set([
        ...compactIds(data || [], 'requester_user_id'),
        ...compactIds(data || [], 'reviewer_user_id'),
      ])));
      const approvals = (data || []).map((approval: any) => ({
        ...approval,
        users: usersById.get(String(approval.requester_user_id)) || null,
        reviewer: usersById.get(String(approval.reviewer_user_id)) || null,
      }));
      res.json({ success: true, data: { approvals } });
    } catch (e: any) {
      const status = e.message === 'SHARED_BUDGET_ACCESS_DENIED' ? 403 : 400;
      res.status(status).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-budget-approvals/:id/respond', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedBudgetApprovalResponseSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });

      const { data: approval, error: approvalError } = await sb
        .from('shared_budget_approvals')
        .select('*')
        .eq('id', req.params.id)
        .maybeSingle();
      if (approvalError) return res.status(400).json({ success: false, error: approvalError.message });
      if (!approval) return res.status(404).json({ success: false, error: 'SHARED_BUDGET_APPROVAL_NOT_FOUND' });
      if (String(approval.status || '').toUpperCase() !== 'PENDING') {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_APPROVAL_NOT_PENDING' });
      }

      const { budget, membership } = await resolveSharedBudgetMembership(sb, approval.shared_budget_id, session.sub);
      if (!canReviewSharedBudgetSpend(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_BUDGET_ACCESS_DENIED' });
      }

      if (payload.action === 'REJECT') {
        const { data, error } = await sb
          .from('shared_budget_approvals')
          .update({
            status: 'REJECTED',
            reviewer_user_id: session.sub,
            responded_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            note: payload.note ?? approval.note ?? null,
          })
          .eq('id', approval.id)
          .select('*')
          .single();
        if (error) return res.status(400).json({ success: false, error: error.message });
        return res.json({ success: true, data: { approval: data } });
      }

      const requesterMembershipResult = await resolveSharedBudgetMembership(
        sb,
        approval.shared_budget_id,
        String(approval.requester_user_id),
      );

      const approvalMetadata = approval.metadata && typeof approval.metadata === 'object'
        ? approval.metadata
        : {};

      const spendPayload = {
        source_wallet_id: approvalMetadata.source_wallet_id || null,
        amount: wealthNumber(approval.amount),
        currency: approval.currency || budget.currency || 'TZS',
        provider: approval.provider || null,
        bill_category: approval.bill_category || null,
        reference: approval.reference || null,
        description: approval.note || null,
        type: approvalMetadata.type || 'EXTERNAL_PAYMENT',
        metadata: {
          ...approvalMetadata,
          approval_reviewer_user_id: session.sub,
          approval_reviewer_role: membership.role || 'MANAGER',
          approval_response_note: payload.note || null,
        },
      };

      const spendData = await executeSharedBudgetSpend(sb, {
        budget,
        membership: requesterMembershipResult.membership,
        actorUserId: String(approval.requester_user_id),
        actorUser: {
          ...(session.user || {}),
          id: String(approval.requester_user_id),
        },
        payload: spendPayload,
        approvalId: approval.id,
      });

      const transactionId = (spendData as any)?.transaction?.internalId || (spendData as any)?.transaction?.id || null;
      const { data: updatedApproval, error: approvalUpdateError } = await sb
        .from('shared_budget_approvals')
        .update({
          status: 'APPROVED',
          reviewer_user_id: session.sub,
          responded_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          metadata: {
            ...approvalMetadata,
            approved_transaction_id: transactionId,
            approval_response_note: payload.note || null,
          },
        })
        .eq('id', approval.id)
        .select('*')
        .single();
      if (approvalUpdateError) return res.status(400).json({ success: false, error: approvalUpdateError.message });

      res.json({ success: true, data: { approval: updatedApproval, ...spendData } });
    } catch (e: any) {
      const status = e.message === 'SHARED_BUDGET_ACCESS_DENIED' ? 403 : 400;
      res.status(status).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-budgets/:id/spend/preview', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedBudgetSpendSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const budgetId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const { budget, membership } = await resolveSharedBudgetMembership(sb, budgetId, session.sub);
      if (!canSpendFromSharedBudget(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_BUDGET_SPEND_DENIED' });
      }
      const currentSpent = wealthNumber(budget.spent_amount);
      const budgetLimit = wealthNumber(budget.budget_limit);
      if (currentSpent + payload.amount > budgetLimit) {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_LIMIT_EXCEEDED' });
      }
      const memberSpent = wealthNumber(membership.spent_amount || 0);
      const memberLimit = payload.amount + memberSpent;
      if (membership.member_limit && memberLimit > wealthNumber(membership.member_limit)) {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_MEMBER_LIMIT_EXCEEDED' });
      }

      const { sourceRecord, sourceTable } = await resolveOperatingWealthWalletStrict(
        sb,
        session.sub,
        payload.source_wallet_id || undefined,
      );

      const result = await LogicCore.getTransactionPreview(session.sub, {
        sourceWalletId: sourceRecord.id,
        recipientId: payload.provider,
        amount: payload.amount,
        currency: (payload.currency || budget.currency || 'TZS').toUpperCase(),
        description: payload.description || `${budget.name} spend`,
        type: payload.type || 'EXTERNAL_PAYMENT',
        metadata: {
          ...(payload.metadata || {}),
          shared_budget_id: budget.id,
          shared_budget_name: budget.name,
          shared_budget_role: membership.role || 'SPENDER',
          bill_provider: payload.provider || null,
          bill_category: payload.bill_category || null,
          bill_reference: payload.reference || null,
          shared_budget_preview: true,
          spend_origin: 'SHARED_BUDGET',
          spend_type: payload.type || 'EXTERNAL_PAYMENT',
          source_wallet_id: sourceRecord.id,
          source_wallet_table: sourceTable,
          source_wallet_role: sourceRecord.vault_role || sourceRecord.type || null,
        },
      });
      if (!result.success) return res.status(400).json(result);
      res.json({
        success: true,
        data: {
          preview: result,
          budget: {
            ...budget,
            remaining_amount: Math.max(0, budgetLimit - currentSpent - payload.amount),
          },
          member: {
            ...membership,
            remaining_member_limit: membership.member_limit
              ? Math.max(0, wealthNumber(membership.member_limit) - memberSpent - payload.amount)
              : null,
          },
        },
      });
    } catch (e: any) {
      const status = e.message === 'SHARED_BUDGET_SPEND_DENIED' ? 403 : 400;
      res.status(status).json({ success: false, error: e.message });
    }
  });

  v1.post('/wealth/shared-budgets/:id/spend/settle', authenticate as any, requireIdempotencyKey, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = {
        ...SharedBudgetSpendSchema.parse(req.body),
        idempotencyKey: String(resolveIdempotencyHeader(req)).trim(),
      };
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const budgetId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const { budget, membership } = await resolveSharedBudgetMembership(sb, budgetId, session.sub);
      if (!canSpendFromSharedBudget(String(membership.role || ''))) {
        return res.status(403).json({ success: false, error: 'SHARED_BUDGET_SPEND_DENIED' });
      }
      const currentSpent = wealthNumber(budget.spent_amount);
      const budgetLimit = wealthNumber(budget.budget_limit);
      if (currentSpent + payload.amount > budgetLimit) {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_LIMIT_EXCEEDED' });
      }
      const memberSpent = wealthNumber(membership.spent_amount || 0);
      if (membership.member_limit && memberSpent + payload.amount > wealthNumber(membership.member_limit)) {
        return res.status(400).json({ success: false, error: 'SHARED_BUDGET_MEMBER_LIMIT_EXCEEDED' });
      }
      const { sourceRecord, sourceTable } = await resolveOperatingWealthWalletStrict(
        sb,
        session.sub,
        payload.source_wallet_id || undefined,
      );
      const normalizedPayload = {
        ...payload,
        source_wallet_id: sourceRecord.id,
        metadata: {
          ...(payload.metadata || {}),
          source_wallet_id: sourceRecord.id,
          source_wallet_table: sourceTable,
          source_wallet_role: sourceRecord.vault_role || sourceRecord.type || null,
        },
      };
      if (String(budget.approval_mode || 'AUTO').toUpperCase() === 'REVIEW') {
        const { data, error } = await sb
          .from('shared_budget_approvals')
          .insert({
            shared_budget_id: budget.id,
            requester_user_id: session.sub,
            amount: payload.amount,
            currency: (payload.currency || budget.currency || 'TZS').toUpperCase(),
            provider: payload.provider || null,
            bill_category: payload.bill_category || null,
            reference: payload.reference || null,
            note: payload.description || null,
            status: 'PENDING',
            metadata: {
              ...(normalizedPayload.metadata || {}),
              source_wallet_id: sourceRecord.id,
              type: payload.type || 'EXTERNAL_PAYMENT',
              shared_budget_name: budget.name,
              requester_role: membership.role || 'SPENDER',
              spend_origin: 'SHARED_BUDGET',
              bill_provider: payload.provider || null,
              bill_category: payload.bill_category || null,
              bill_reference: payload.reference || null,
              preview_required: true,
            },
          })
          .select('*')
          .single();
        if (error) return res.status(400).json({ success: false, error: error.message });
        return res.json({ success: true, data: { approval: data, requires_approval: true } });
      }

      const data = await executeSharedBudgetSpend(sb, {
        budget,
        membership,
        actorUserId: session.sub,
        actorUser: session.user,
        payload: normalizedPayload,
      });
      res.json({ success: true, data });
    } catch (e: any) {
      const status = e.message === 'SHARED_BUDGET_SPEND_DENIED' ? 403 : 400;
      res.status(status).json({ success: false, error: e.message });
    }
  });
};
