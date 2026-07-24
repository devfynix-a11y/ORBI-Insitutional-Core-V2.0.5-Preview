import crypto from 'crypto';
import { getAdminSupabase, getSupabase } from '../supabaseClient.js';

type SupabaseClient = NonNullable<ReturnType<typeof getAdminSupabase> | ReturnType<typeof getSupabase>>;

export type PaymentProfileInput = {
  serviceCode: string;
  userId?: string;
  customerId?: string;
  email?: string;
  phone?: string;
  externalCustomerId?: string;
  scopes: string[];
  consent?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
  expiresAt?: string;
  idempotencyKey?: string;
  createdByWorkerId?: string;
};

const normalizePhone = (value?: string) => String(value || '').replace(/[^\d+]/g, '').trim();
const normalizeScope = (value: string) => value.trim().toLowerCase();
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const createProfileId = () => `pp_${crypto.randomBytes(18).toString('hex')}`;

const activeStatuses = new Set(['active', 'verified']);

const db = (): SupabaseClient => {
  const sb = getAdminSupabase() || getSupabase();
  if (!sb) throw new Error('DB_OFFLINE');
  return sb;
};

const resolveUser = async (sb: SupabaseClient, input: PaymentProfileInput) => {
  const userId = String(input.userId || '').trim();
  const customerId = String(input.customerId || '').trim();
  const email = String(input.email || '').trim().toLowerCase();
  const phone = normalizePhone(input.phone);

  const selectUser = () =>
    sb
      .from('users')
      .select('id,customer_id,full_name,email,phone,account_status,currency,preferred_currency,registry_type')
      .limit(1);

  let data: any = null;
  let error: any = null;

  if (userId) {
    if (!uuidPattern.test(userId)) throw new Error('PAYMENT_PROFILE_USER_ID_INVALID');
    ({ data, error } = await selectUser().eq('id', userId).maybeSingle());
  } else if (customerId) {
    ({ data, error } = await selectUser().eq('customer_id', customerId).maybeSingle());
  } else if (email) {
    ({ data, error } = await selectUser().ilike('email', email).maybeSingle());
  } else if (phone) {
    ({ data, error } = await selectUser().eq('phone', phone).maybeSingle());
    if (!data && !error && phone.startsWith('+')) {
      ({ data, error } = await selectUser().eq('phone', phone.replace(/^\+/, '')).maybeSingle());
    }
  } else {
    throw new Error('PAYMENT_PROFILE_IDENTITY_REQUIRED');
  }

  if (error) throw new Error(error.message || 'PAYMENT_PROFILE_IDENTITY_LOOKUP_FAILED');
  if (!data) throw new Error('PAYMENT_PROFILE_USER_NOT_FOUND');

  const status = String(data.account_status || '').toLowerCase();
  if (!activeStatuses.has(status)) throw new Error('PAYMENT_PROFILE_USER_NOT_ACTIVE');
  if (!String(data.currency || data.preferred_currency || '').trim()) {
    throw new Error('PAYMENT_PROFILE_USER_CURRENCY_REQUIRED');
  }

  return data;
};

const serializeProfile = (profile: Record<string, any>, user?: Record<string, any>) => ({
  id: profile.id,
  paymentProfileId: profile.profile_id,
  serviceCode: profile.service_code,
  externalCustomerId: profile.external_customer_id,
  userId: profile.user_id,
  customerId: profile.customer_id || user?.customer_id || null,
  status: profile.status,
  scopes: profile.scopes || [],
  expiresAt: profile.expires_at || null,
  createdAt: profile.created_at,
  updatedAt: profile.updated_at,
  user: user
    ? {
        id: user.id,
        customerId: user.customer_id || null,
        displayName: user.full_name || null,
        accountStatus: user.account_status || null,
        currency: user.currency || user.preferred_currency || null,
        registryType: user.registry_type || null,
      }
    : undefined,
});

export class PaymentProfileService {
  static async createOrLink(input: PaymentProfileInput) {
    const sb = db();
    const serviceCode = String(input.serviceCode || '').trim();
    if (!serviceCode) throw new Error('PAYMENT_PROFILE_SERVICE_CODE_REQUIRED');

    const scopes = [...new Set((input.scopes || []).map(normalizeScope).filter(Boolean))];
    if (scopes.length === 0) throw new Error('PAYMENT_PROFILE_SCOPE_REQUIRED');

    const user = await resolveUser(sb, input);
    const idempotencyKey = String(input.idempotencyKey || '').trim() || null;
    const externalCustomerId = String(input.externalCustomerId || '').trim() || null;

    if (idempotencyKey) {
      const { data: existing, error } = await sb
        .from('payment_profiles')
        .select('*')
        .eq('service_code', serviceCode)
        .eq('idempotency_key', idempotencyKey)
        .maybeSingle();
      if (error) throw new Error(error.message || 'PAYMENT_PROFILE_IDEMPOTENCY_LOOKUP_FAILED');
      if (existing) return { profile: serializeProfile(existing, user), replayed: true };
    }

    if (externalCustomerId) {
      const { data: existingByExternal, error } = await sb
        .from('payment_profiles')
        .select('*')
        .eq('service_code', serviceCode)
        .eq('external_customer_id', externalCustomerId)
        .neq('status', 'revoked')
        .maybeSingle();
      if (error) throw new Error(error.message || 'PAYMENT_PROFILE_EXTERNAL_LOOKUP_FAILED');
      if (existingByExternal) {
        if (String(existingByExternal.user_id) !== String(user.id)) {
          throw new Error('PAYMENT_PROFILE_EXTERNAL_CUSTOMER_CONFLICT');
        }
        return { profile: serializeProfile(existingByExternal, user), replayed: true };
      }
    }

    const payload = {
      profile_id: createProfileId(),
      service_code: serviceCode,
      external_customer_id: externalCustomerId,
      user_id: user.id,
      customer_id: user.customer_id || null,
      status: 'active',
      scopes,
      consent_payload: input.consent || {},
      metadata: {
        ...(input.metadata || {}),
        createdVia: 'pay_gateway_payment_profile',
      },
      expires_at: input.expiresAt || null,
      idempotency_key: idempotencyKey,
      created_by_worker_id: input.createdByWorkerId || null,
    };

    const { data, error } = await sb
      .from('payment_profiles')
      .insert(payload)
      .select('*')
      .single();
    if (error) throw new Error(error.message || 'PAYMENT_PROFILE_CREATE_FAILED');

    return { profile: serializeProfile(data, user), replayed: false };
  }
}
