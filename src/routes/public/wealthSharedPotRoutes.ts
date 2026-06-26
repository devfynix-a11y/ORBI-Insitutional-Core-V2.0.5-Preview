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
      const { data, error } = await sb.rpc('create_shared_pot_v1', {
        p_actor_user_id: session.sub,
        p_name: payload.name,
        p_purpose: payload.purpose || null,
        p_currency: payload.currency?.toUpperCase() || 'TZS',
        p_target_amount: payload.target_amount || 0,
        p_access_model: payload.access_model || 'INVITE',
        p_idempotency_key: payload.idempotency_key || crypto.randomUUID(),
        p_metadata: { created_from: 'mobile_app' },
      });
      if (error) return res.status(400).json({ success: false, error: error.message });
      res.json({
        success: true,
        data: data?.pot || null,
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
      const { membership } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
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
      const memberUser = await resolveUserBySharedPotIdentifier(sb, payload.identifier);
      if (!memberUser?.id) {
        return res.status(404).json({ success: false, error: 'USER_NOT_FOUND' });
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

  v1.post('/wealth/shared-pots/:id/withdraw', authenticate as any, async (req, res) => {
    const session = (req as any).session;
    try {
      const payload = SharedPotWithdrawSchema.parse(req.body);
      const sb = getAdminSupabase() || getSupabase();
      if (!sb) return res.status(503).json({ success: false, error: 'DB_OFFLINE' });
      const { pot, membership } = await resolveSharedPotMembership(sb, req.params.id, session.sub);
      if (!canManageSharedPot(String(membership.role || ''))) {
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
