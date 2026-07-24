import { Audit } from '../security/audit.js';
import { getAdminSupabase, getSupabase } from '../supabaseClient.js';

type BusinessRegistrationInput = {
  requestedRole?: string;
  businessName?: string;
  phone?: string;
  note?: string;
  metadata?: Record<string, any>;
  submittedVia?: string;
};

type GatewayBusinessRegistrationInput = BusinessRegistrationInput & {
  userId?: string;
  email?: string;
  phone?: string;
  externalBusinessId?: string;
  serviceCode?: string;
};

const normalizeUpper = (value: unknown, fallback = '') =>
  String(value ?? fallback).trim().toUpperCase();

const clean = (value: unknown) => String(value ?? '').trim();

const roleToRegistryType = (role: string): 'MERCHANT' | 'AGENT' =>
  normalizeUpper(role) === 'AGENT' ? 'AGENT' : 'MERCHANT';

const normalizeRequestedRole = (value: unknown): 'MERCHANT' | 'AGENT' => {
  const role = normalizeUpper(value, 'MERCHANT');
  if (role === 'AGENT' || role === 'WAKALA' || role === 'BROKER') return 'AGENT';
  if (['MERCHANT', 'SELLER', 'PRODUCER', 'INDUSTRIAL', 'BUSINESS'].includes(role)) return 'MERCHANT';
  throw new Error('BUSINESS_ROLE_UNSUPPORTED');
};

class BusinessIdentityService {
  private getDb() {
    return getAdminSupabase() || getSupabase();
  }

  private async ensureUserRow(userId: string, sessionUser?: any, fallbackMetadata: Record<string, any> = {}) {
    const sb = this.getDb();
    if (!sb) throw new Error('DB_OFFLINE');

    const { data: existing, error: existingError } = await sb
      .from('users')
      .select('id')
      .eq('id', userId)
      .maybeSingle();
    if (existingError) throw new Error(existingError.message);
    if (existing) return;

    const adminSb = getAdminSupabase();
    const authUserResult = adminSb ? await adminSb.auth.admin.getUserById(userId) : null;
    const authUser = authUserResult?.data?.user;
    const metadata = {
      ...(authUser?.user_metadata || {}),
      ...(sessionUser?.user_metadata || {}),
      ...(fallbackMetadata || {}),
    };

    const profilePayload = {
      id: userId,
      full_name: metadata.full_name || sessionUser?.full_name || clean(metadata.name) || 'User',
      email: authUser?.email || sessionUser?.email || metadata.email || null,
      phone: authUser?.phone || sessionUser?.phone || metadata.phone || null,
      nationality: metadata.nationality || null,
      address: metadata.address || null,
      avatar_url: metadata.avatar_url || null,
      customer_id: metadata.customer_id || null,
      currency: metadata.currency || 'TZS',
      preferred_currency: metadata.preferred_currency || metadata.currency || 'TZS',
      country_code: metadata.country_code || null,
      country_name: metadata.country_name || null,
      dial_code: metadata.dial_code || null,
      language: metadata.language || 'en',
      fcm_token: metadata.fcm_token || null,
      account_status: metadata.account_status || 'active',
      role: normalizeUpper(metadata.role, 'USER'),
      registry_type: normalizeUpper(metadata.registry_type, 'CONSUMER'),
      app_origin: metadata.app_origin || null,
      metadata,
    };

    const { error: upsertError } = await sb
      .from('users')
      .upsert(profilePayload, { onConflict: 'id' });
    if (upsertError) throw new Error(upsertError.message);
  }

  private async resolveUser(input: { userId?: string; email?: string; phone?: string; customerId?: string }) {
    const sb = this.getDb();
    if (!sb) throw new Error('DB_OFFLINE');

    const userId = clean(input.userId);
    if (userId) {
      const { data, error } = await sb.from('users').select('*').eq('id', userId).maybeSingle();
      if (error) throw new Error(error.message);
      if (data) return data;
    }

    const email = clean(input.email).toLowerCase();
    if (email) {
      const { data, error } = await sb.from('users').select('*').ilike('email', email).maybeSingle();
      if (error) throw new Error(error.message);
      if (data) return data;
    }

    const phone = clean(input.phone);
    if (phone) {
      const digits = phone.replace(/\D/g, '');
      const { data, error } = await sb
        .from('users')
        .select('*')
        .or(`phone.eq.${phone},phone.ilike.%${digits.slice(-9)}`)
        .limit(1);
      if (error) throw new Error(error.message);
      if (data?.[0]) return data[0];
    }

    const customerId = clean(input.customerId);
    if (customerId) {
      const { data, error } = await sb.from('users').select('*').eq('customer_id', customerId).maybeSingle();
      if (error) throw new Error(error.message);
      if (data) return data;
    }

    return null;
  }

  async getBusinessProfile(userId: string, sessionUser?: any) {
    const sb = this.getDb();
    if (!sb) throw new Error('DB_OFFLINE');
    await this.ensureUserRow(userId, sessionUser);

    const { data: user, error: userError } = await sb
      .from('users')
      .select('id,full_name,email,phone,customer_id,role,registry_type,account_status,currency,language,organization_id,org_role,metadata,created_at,updated_at')
      .eq('id', userId)
      .maybeSingle();
    if (userError) throw new Error(userError.message);
    if (!user) throw new Error('USER_NOT_FOUND');

    const [
      merchantResult,
      agentResult,
      accessResult,
      organizationMembershipResult,
    ] = await Promise.all([
      sb
        .from('merchants')
        .select('id,business_name,status,metadata,created_at,updated_at,merchant_wallets(id,name,wallet_type,is_primary,currency,status,metadata),merchant_settlements(id,bank_name,settlement_schedule,status),merchant_fees(id,transaction_fee_percent,fixed_fee,currency)')
        .eq('owner_user_id', userId)
        .order('created_at', { ascending: false }),
      sb
        .from('agents')
        .select('id,display_name,status,service_pay_number,cash_withdraw_till,metadata,created_at,updated_at')
        .eq('user_id', userId)
        .maybeSingle(),
      sb
        .from('service_access_requests')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false }),
      sb
        .from('organization_members')
        .select('id,organization_id,user_id,role,status,created_at,organizations(id,name,type,status,metadata)')
        .eq('user_id', userId)
        .order('created_at', { ascending: false }),
    ]);

    if (merchantResult.error) throw new Error(merchantResult.error.message);
    if (agentResult.error) throw new Error(agentResult.error.message);
    if (accessResult.error) throw new Error(accessResult.error.message);
    if (organizationMembershipResult.error) throw new Error(organizationMembershipResult.error.message);

    return {
      identity: {
        userId: user.id,
        fullName: user.full_name,
        email: user.email,
        phone: user.phone,
        customerId: user.customer_id,
        role: user.role,
        registryType: user.registry_type,
        accountStatus: user.account_status,
        currency: user.currency,
        language: user.language,
        organizationId: user.organization_id,
        organizationRole: user.org_role,
        metadata: user.metadata || {},
      },
      merchant: {
        active: (merchantResult.data || []).some((item: any) => String(item.status || '').toLowerCase() === 'active'),
        accounts: merchantResult.data || [],
      },
      agent: agentResult.data || null,
      serviceAccessRequests: accessResult.data || [],
      organizations: organizationMembershipResult.data || [],
    };
  }

  async submitBusinessRegistration(userId: string, sessionUser: any, input: BusinessRegistrationInput) {
    const sb = this.getDb();
    if (!sb) throw new Error('DB_OFFLINE');
    await this.ensureUserRow(userId, sessionUser, input.metadata || {});

    const { data: user, error: userError } = await sb
      .from('users')
      .select('id,role,registry_type,phone,email,account_status')
      .eq('id', userId)
      .maybeSingle();
    if (userError) throw new Error(userError.message);
    if (!user) throw new Error('USER_NOT_FOUND');

    const requestedRole = normalizeRequestedRole(input.requestedRole);
    const requestedRegistryType = roleToRegistryType(requestedRole);
    const currentRole = normalizeUpper(user.role, 'USER');
    const currentRegistryType = normalizeUpper(user.registry_type, 'CONSUMER');

    if (currentRegistryType === 'STAFF') throw new Error('STAFF_INELIGIBLE');
    if (currentRole === requestedRole && currentRegistryType === requestedRegistryType) {
      throw new Error('ROLE_ALREADY_ACTIVE');
    }

    const { data: pending, error: pendingError } = await sb
      .from('service_access_requests')
      .select('*')
      .eq('user_id', userId)
      .eq('requested_role', requestedRole)
      .in('status', ['pending', 'under_review'])
      .order('created_at', { ascending: false })
      .limit(1);
    if (pendingError) throw new Error(pendingError.message);
    if (pending?.[0]) {
      return { request: pending[0], alreadyPending: true };
    }

    const metadata = {
      ...(input.metadata || {}),
      business_registration_version: 'v1',
    };

    const payload = {
      user_id: userId,
      requested_role: requestedRole,
      requested_registry_type: requestedRegistryType,
      current_user_role: currentRole,
      current_user_registry_type: currentRegistryType,
      business_name: clean(input.businessName) || null,
      phone: clean(input.phone) || user.phone || null,
      note: clean(input.note) || null,
      submitted_via: clean(input.submittedVia) || 'orbi_business',
      status: 'pending',
      metadata,
    };

    const { data, error } = await sb
      .from('service_access_requests')
      .insert(payload)
      .select('*')
      .single();
    if (error) throw new Error(error.message);

    await Audit.log('ADMIN', userId, 'ORBI_BUSINESS_REGISTRATION_SUBMITTED', {
      requestId: data.id,
      requestedRole,
      requestedRegistryType,
      submittedVia: payload.submitted_via,
    });

    return { request: data, alreadyPending: false };
  }

  async submitGatewayBusinessRegistration(input: GatewayBusinessRegistrationInput, workerId: string) {
    const user = await this.resolveUser({
      userId: input.userId,
      email: input.email,
      phone: input.phone,
    });
    if (!user?.id) throw new Error('BUSINESS_USER_NOT_FOUND');

    return this.submitBusinessRegistration(user.id, user, {
      requestedRole: input.requestedRole,
      businessName: input.businessName,
      phone: input.phone,
      note: input.note,
      submittedVia: input.submittedVia || 'pay_gateway',
      metadata: {
        ...(input.metadata || {}),
        externalBusinessId: input.externalBusinessId || null,
        serviceCode: input.serviceCode || null,
        gatewayWorkerId: workerId,
      },
    });
  }
}

export const BusinessIdentity = new BusinessIdentityService();
