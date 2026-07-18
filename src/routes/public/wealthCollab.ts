import { buildPostgrestOrFilter } from '../../../backend/security/postgrest.js';

const normalizeWealthIdentifier = (value: string) => value.trim().toLowerCase();

const normalizeWealthPhone = (value: string) =>
  value
    .trim()
    .replace(/[^\d+]/g, '')
    .replace(/(?!^)\+/g, '');

const isEmailLikeIdentifier = (value: string) => value.includes('@');
const isUuidLikeIdentifier = (value: string) =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value.trim());

export const resolveSharedPotMembership = async (sb: any, potId: string, userId: string) => {
  const { data: pot, error: potError } = await sb
    .from('shared_pots')
    .select('*')
    .eq('id', potId)
    .maybeSingle();
  if (potError) throw new Error(potError.message);
  if (!pot) throw new Error('SHARED_POT_NOT_FOUND');

  const { data: membership, error: memberError } = await sb
    .from('shared_pot_members')
    .select('*')
    .eq('pot_id', potId)
    .eq('user_id', userId)
    .eq('status', 'ACTIVE')
    .maybeSingle();
  if (memberError) throw new Error(memberError.message);

  const ownerMembership = pot.owner_user_id === userId
    ? { role: 'OWNER', status: 'ACTIVE', user_id: userId, pot_id: potId }
    : null;

  let organizationMembership = null;
  if (!membership && !ownerMembership && String(pot.access_model || '').toUpperCase() === 'ORG' && pot.organization_id) {
    const { data: orgUser, error: orgUserError } = await sb
      .from('users')
      .select('id,organization_id,org_role')
      .eq('id', userId)
      .maybeSingle();
    if (orgUserError) throw new Error(orgUserError.message);
    const orgRole = String(orgUser?.org_role || '').toUpperCase();
    if (String(orgUser?.organization_id || '') === String(pot.organization_id)) {
      const potRole = orgRole === 'SIGNATORY'
        ? 'SIGNATORY'
        : orgRole === 'ACCOUNTANT'
          ? 'ACCOUNTANT'
          : ['ADMIN', 'MANAGER'].includes(orgRole)
            ? 'MANAGER'
            : 'VIEWER';
      organizationMembership = {
        role: potRole,
        user_id: userId,
        pot_id: potId,
        organization_role: orgRole || 'MEMBER',
        derived_from_organization: true,
      };
    }
  }

  const effectiveMembership = membership || ownerMembership || organizationMembership;
  if (!effectiveMembership) throw new Error('SHARED_POT_ACCESS_DENIED');
  return { pot, membership: effectiveMembership };
};

export const canManageSharedPot = (role: string) => ['OWNER', 'MANAGER'].includes(role.toUpperCase());
export const canReviewSharedPot = (role: string) => ['OWNER', 'MANAGER', 'SIGNATORY'].includes(role.toUpperCase());
export const canViewSharedPotGovernance = (role: string) =>
  ['OWNER', 'MANAGER', 'SIGNATORY', 'ACCOUNTANT'].includes(role.toUpperCase());
export const canContributeToSharedPot = (role: string) =>
  ['OWNER', 'MANAGER', 'CONTRIBUTOR'].includes(role.toUpperCase());

export const resolveUserBySharedPotIdentifier = async (sb: any, identifier: string) => {
  const rawIdentifier = String(identifier || '').trim();
  if (!rawIdentifier) return null;

  if (isUuidLikeIdentifier(rawIdentifier)) {
    const { data, error } = await sb
      .from('users')
      .select('id,email,phone,full_name,customer_id')
      .eq('id', rawIdentifier)
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (data) return data;
  }

  if (isEmailLikeIdentifier(identifier)) {
    const { data, error } = await sb
      .from('users')
      .select('id,email,phone,full_name,customer_id')
      .eq('email', normalizeWealthIdentifier(identifier))
      .maybeSingle();
    if (error) throw new Error(error.message);
    return data;
  }

  const normalizedPhone = normalizeWealthPhone(identifier);
  const candidates = Array.from(new Set([rawIdentifier, normalizedPhone, normalizedPhone.replace(/\D/g, '')].filter(Boolean)));
  const { data, error } = await sb
    .from('users')
    .select('id,email,phone,full_name,customer_id')
    .or(buildPostgrestOrFilter([
      ...candidates.map((candidate) => ({ column: 'phone', operator: 'eq' as const, value: candidate })),
      ...candidates.map((candidate) => ({ column: 'customer_id', operator: 'eq' as const, value: candidate })),
    ]))
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data;
};

export const expireSharedPotInvitationIfNeeded = async (sb: any, invite: any) => {
  if (!invite?.expires_at) return invite;
  if (String(invite.status || '').toUpperCase() !== 'PENDING') return invite;
  if (new Date(invite.expires_at).getTime() > Date.now()) return invite;

  const { data, error } = await sb
    .from('shared_pot_invitations')
    .update({
      status: 'EXPIRED',
      updated_at: new Date().toISOString(),
    })
    .eq('id', invite.id)
    .select('*')
    .single();
  if (error) throw new Error(error.message);
  return data || invite;
};

export const resolveSharedBudgetMembership = async (sb: any, budgetId: string, userId: string) => {
  const { data: budget, error: budgetError } = await sb
    .from('shared_budgets')
    .select('*')
    .eq('id', budgetId)
    .maybeSingle();
  if (budgetError) throw new Error(budgetError.message);
  if (!budget) throw new Error('SHARED_BUDGET_NOT_FOUND');

  const { data: membership, error: memberError } = await sb
    .from('shared_budget_members')
    .select('*')
    .eq('budget_id', budgetId)
    .eq('user_id', userId)
    .eq('status', 'ACTIVE')
    .maybeSingle();
  if (memberError) throw new Error(memberError.message);

  const ownerMembership = budget.owner_user_id === userId
    ? { role: 'OWNER', status: 'ACTIVE', user_id: userId, budget_id: budgetId }
    : null;

  const effectiveMembership = membership || ownerMembership;
  if (!effectiveMembership) throw new Error('SHARED_BUDGET_ACCESS_DENIED');
  return { budget, membership: effectiveMembership };
};

export const canManageSharedBudget = (role: string) => ['OWNER', 'MANAGER'].includes(role.toUpperCase());
export const canSpendFromSharedBudget = (role: string) => ['OWNER', 'MANAGER', 'SPENDER'].includes(role.toUpperCase());
export const canReviewSharedBudgetSpend = (role: string) => ['OWNER', 'MANAGER'].includes(role.toUpperCase());

export const resolveUserBySharedBudgetIdentifier = async (sb: any, identifier: string) => {
  return resolveUserBySharedPotIdentifier(sb, identifier);
};

export const expireSharedBudgetInvitationIfNeeded = async (sb: any, invite: any) => {
  if (!invite?.expires_at) return invite;
  if (String(invite.status || '').toUpperCase() !== 'PENDING') return invite;
  if (new Date(invite.expires_at).getTime() > Date.now()) return invite;

  const { data, error } = await sb
    .from('shared_budget_invitations')
    .update({
      status: 'EXPIRED',
      updated_at: new Date().toISOString(),
    })
    .eq('id', invite.id)
    .select('*')
    .single();
  if (error) throw new Error(error.message);
  return data || invite;
};
