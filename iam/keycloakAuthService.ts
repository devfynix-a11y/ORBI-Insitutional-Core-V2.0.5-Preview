import { randomUUID } from 'crypto';
import { createRemoteJWKSet, decodeJwt, decodeProtectedHeader, jwtVerify, type JWTPayload } from 'jose';
import type { Permission, Session, UserRole } from '../types.js';
import { IdentityGenerator } from '../services/utils.js';
import { getOrbiDatabase } from '../services/orbiDatabase.js';
import { OTPService } from '../backend/security/otpService.js';
import { logger } from '../backend/infrastructure/logger.js';
import { JWTNode } from '../backend/security/jwt.js';
import {
  DEFAULT_INSTITUTIONAL_APP_ORIGIN,
  TRUSTED_INSTITUTIONAL_APP_ORIGINS,
  TRUSTED_MOBILE_APP_ORIGINS,
} from '../backend/config/appIdentity.js';

type LoginMetadata = {
  fingerprint?: string;
  ip?: string;
  userAgent?: string;
};

type KeycloakTokenResponse = {
  access_token: string;
  refresh_token?: string;
  expires_in: number;
  token_type: string;
};

type IdentityRecord = {
  id: string;
  email: string | null;
  phone: string | null;
  raw_user_meta_data: Record<string, any>;
  full_name: string | null;
  customer_id: string | null;
  account_status: string;
  role: UserRole;
  registry_type: string;
  app_origin: string;
  kyc_level: number;
  kyc_status: string;
  id_type: string | null;
  id_number: string | null;
};

const provider = 'keycloak';
const internalUrl = () =>
  String(process.env.ORBI_KEYCLOAK_INTERNAL_URL || 'http://keycloak:8080').replace(/\/+$/, '');
const issuer = () =>
  String(process.env.ORBI_KEYCLOAK_ISSUER || 'https://auth.orbifinancial.com/realms/orbi').replace(/\/+$/, '');
const realm = () => String(process.env.ORBI_KEYCLOAK_REALM || 'orbi');
const mobileClientId = () => String(process.env.ORBI_KEYCLOAK_MOBILE_CLIENT_ID || 'orbi-mobile');
const realmUrl = () => `${internalUrl()}/realms/${encodeURIComponent(realm())}`;
const adminUrl = () => `${internalUrl()}/admin/realms/${encodeURIComponent(realm())}`;
const keycloakAuthLogger = logger.child({ component: 'keycloak_auth_service' });

const permissionsForRole = (role: UserRole): Permission[] => {
  const common: Permission[] = ['auth.login', 'auth.logout', 'auth.refresh', 'user.read', 'user.update'];
  if (role === 'SUPER_ADMIN') {
    return [
      ...common, 'auth.pwd_reset', 'user.freeze', 'wallet.read', 'wallet.create',
      'wallet.update', 'wallet.delete', 'wallet.credit', 'wallet.debit', 'wallet.freeze',
      'transaction.create', 'transaction.view', 'transaction.verify', 'transaction.reverse',
      'transaction.delete', 'ledger.read', 'ledger.write', 'admin.approve', 'admin.freeze',
      'admin.audit.read', 'admin.user.manage', 'staff.read', 'staff.write',
    ];
  }
  if (['ADMIN', 'IT', 'AUDIT', 'ACCOUNTANT', 'CUSTOMER_CARE', 'HUMAN_RESOURCE'].includes(role)) {
    return [...common, 'wallet.read', 'transaction.view', 'ledger.read', 'admin.audit.read'];
  }
  return [...common, 'wallet.read', 'wallet.create', 'wallet.update', 'transaction.create', 'transaction.view'];
};

const readError = async (response: Response): Promise<string> => {
  const raw = await response.text();
  if (!raw) return `HTTP_${response.status}`;
  try {
    const payload = JSON.parse(raw);
    return String(payload.error_description || payload.errorMessage || payload.error || raw);
  } catch {
    return raw;
  }
};

export class KeycloakAuthService {
  private readonly jwks = createRemoteJWKSet(new URL(`${realmUrl()}/protocol/openid-connect/certs`));
  private adminToken: { value: string; expiresAt: number } | null = null;

  private readonly identityQuery = `
    SELECT
      au.id, au.email, au.phone, au.raw_user_meta_data,
      COALESCE(s.full_name, u.full_name, au.raw_user_meta_data->>'full_name') AS full_name,
      COALESCE(s.customer_id, u.customer_id, au.raw_user_meta_data->>'customer_id') AS customer_id,
      COALESCE(s.account_status, u.account_status, au.raw_user_meta_data->>'account_status', 'active') AS account_status,
      COALESCE(s.role, u.role, au.raw_user_meta_data->>'role', 'USER') AS role,
      COALESCE(u.registry_type, au.raw_user_meta_data->>'registry_type',
        CASE WHEN s.id IS NOT NULL THEN 'STAFF' ELSE 'CONSUMER' END) AS registry_type,
      COALESCE(u.app_origin, au.raw_user_meta_data->>'app_origin', $2) AS app_origin,
      COALESCE(u.kyc_level, 0) AS kyc_level,
      COALESCE(u.kyc_status, 'unverified') AS kyc_status,
      u.id_type, u.id_number
    FROM auth.users au
    LEFT JOIN public.users u ON u.id = au.id
    LEFT JOIN public.staff s ON s.id = au.id
    WHERE au.id = $1
  `;

  private async getAdminToken(): Promise<string> {
    if (this.adminToken && this.adminToken.expiresAt > Date.now() + 30_000) {
      return this.adminToken.value;
    }
    const username = String(process.env.ORBI_KEYCLOAK_ADMIN_USERNAME || '').trim();
    const password = String(process.env.ORBI_KEYCLOAK_ADMIN_PASSWORD || '').trim();
    if (!username || !password) throw new Error('KEYCLOAK_ADMIN_CREDENTIALS_REQUIRED');

    const response = await fetch(`${internalUrl()}/realms/master/protocol/openid-connect/token`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'password',
        client_id: 'admin-cli',
        username,
        password,
      }),
    });
    if (!response.ok) throw new Error(await readError(response));
    const token = await response.json() as KeycloakTokenResponse;
    this.adminToken = {
      value: token.access_token,
      expiresAt: Date.now() + Math.max(token.expires_in - 30, 30) * 1000,
    };
    return token.access_token;
  }

  private async deleteKeycloakUser(userId: string): Promise<void> {
    const token = await this.getAdminToken();
    await fetch(`${adminUrl()}/users/${encodeURIComponent(userId)}`, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${token}` },
    });
  }

  private async keycloakSubjectForUser(userId: string): Promise<string | null> {
    const { rows } = await getOrbiDatabase().query<{ provider_subject: string }>(
      `SELECT provider_subject FROM orbi_auth.identity_links
       WHERE provider = $1 AND user_id = $2`,
      [provider, userId],
    );
    return rows[0]?.provider_subject || null;
  }

  private async setKeycloakPassword(userId: string, password: string): Promise<void> {
    const subject = await this.keycloakSubjectForUser(userId);
    if (!subject) throw new Error('IDENTITY_LINK_REQUIRED');
    const token = await this.getAdminToken();
    const response = await fetch(`${adminUrl()}/users/${encodeURIComponent(subject)}/reset-password`, {
      method: 'PUT',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ type: 'password', value: password, temporary: false }),
    });
    if (!response.ok) throw new Error(await readError(response));
    await fetch(`${adminUrl()}/users/${encodeURIComponent(subject)}/logout`, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
  }

  private validatePasswordPolicy(password: string): Error | null {
    if (password.length < 8) return new Error('INVALID_PASSWORD_POLICY: Password must be at least 8 characters.');
    if (!/[a-z]/.test(password)) return new Error('INVALID_PASSWORD_POLICY: Password must contain at least 1 lowercase letter.');
    if (!/[A-Z]/.test(password)) return new Error('INVALID_PASSWORD_POLICY: Password must contain at least 1 uppercase letter.');
    if (!/[0-9]/.test(password)) return new Error('INVALID_PASSWORD_POLICY: Password must contain at least 1 number.');
    if (!/[^A-Za-z0-9]/.test(password)) return new Error('INVALID_PASSWORD_POLICY: Password must contain at least 1 special character.');
    return null;
  }

  private async setKeycloakEmailVerified(userId: string): Promise<void> {
    const subject = await this.keycloakSubjectForUser(userId);
    if (!subject) throw new Error('IDENTITY_LINK_REQUIRED');
    const token = await this.getAdminToken();
    const response = await fetch(`${adminUrl()}/users/${encodeURIComponent(subject)}`, {
      method: 'PUT',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ enabled: true, emailVerified: true }),
    });
    if (!response.ok) throw new Error(await readError(response));
  }

  private async findChallengeIdentity(identifier: string): Promise<{
    id: string;
    email: string | null;
    phone: string | null;
    nationality: string | null;
    status: string;
  } | null> {
    const normalized = identifier.trim().toLowerCase();
    const { rows } = await getOrbiDatabase().query<{
      id: string;
      email: string | null;
      phone: string | null;
      nationality: string | null;
      status: string;
    }>(
      `SELECT au.id, au.email, au.phone,
              COALESCE(u.nationality, au.raw_user_meta_data->>'nationality', 'Tanzania') AS nationality,
              COALESCE(u.account_status, au.raw_user_meta_data->>'account_status', 'active') AS status
       FROM auth.users au
       LEFT JOIN public.users u ON u.id = au.id
       WHERE lower(au.email) = $1 OR au.phone = $2
       LIMIT 1`,
      [normalized, identifier.trim()],
    );
    return rows[0] || null;
  }

  private maskContact(contact: string): string {
    if (contact.includes('@')) {
      const [local, domain] = contact.split('@');
      return `${local.slice(0, 2)}***@${domain}`;
    }
    return contact.length > 4 ? `${contact.slice(0, 3)}***${contact.slice(-2)}` : '***';
  }

  private normalizePhoneIdentifier(identifier: string): string {
    const value = String(identifier || '').trim();
    if (!value || value.includes('@')) return value;
    return value.startsWith('+') ? value : `+${value.replace(/\s/g, '')}`;
  }

  private preferredChallengeContact(
    identity: {
      email?: string | null;
      phone?: string | null;
      nationality?: string | null;
    },
    fallback?: string,
    preferFallbackInput = false,
  ): { contact: string; type: 'sms' | 'email' } | null {
    const phone = String(identity.phone || '').trim();
    const email = String(identity.email || '').trim();
    const fallbackValue = String(fallback || '').trim();
    if (fallbackValue.includes('@')) {
      const normalizedFallbackEmail = fallbackValue.toLowerCase();
      if (email && email.toLowerCase() === normalizedFallbackEmail) {
        return { contact: email, type: 'email' };
      }
    } else if (fallbackValue) {
      const normalizedFallbackPhone = this.normalizePhoneIdentifier(fallbackValue);
      if (phone && this.normalizePhoneIdentifier(phone) === normalizedFallbackPhone) {
        return { contact: phone, type: 'sms' };
      }
    }
    const nationality = String(identity.nationality || '').trim().toLowerCase();
    const normalizedPhone = phone ? this.normalizePhoneIdentifier(phone) : '';
    const isTanzania =
      nationality === 'tz' ||
      nationality === 'tza' ||
      nationality === 'tanzania' ||
      nationality === 'united republic of tanzania' ||
      normalizedPhone.startsWith('+255');
    if (isTanzania && phone) return { contact: phone, type: 'sms' };
    if (!isTanzania && email) return { contact: email, type: 'email' };
    if (preferFallbackInput && fallbackValue) {
      return {
        contact: fallbackValue,
        type: fallbackValue.includes('@') ? 'email' : 'sms',
      };
    }
    if (email) return { contact: email, type: 'email' };
    if (phone) return { contact: phone, type: 'sms' };
    if (fallbackValue) {
      return {
        contact: fallbackValue,
        type: fallbackValue.includes('@') ? 'email' : 'sms',
      };
    }
    return null;
  }

  private isTanzaniaIdentity(identity: {
    phone?: string | null;
    nationality?: string | null;
  }): boolean {
    const nationality = String(identity.nationality || '').trim().toLowerCase();
    const phone = String(identity.phone || '').trim();
    const normalizedPhone = phone ? this.normalizePhoneIdentifier(phone) : '';
    return (
      nationality === 'tz' ||
      nationality === 'tza' ||
      nationality === 'tanzania' ||
      nationality === 'united republic of tanzania' ||
      normalizedPhone.startsWith('+255')
    );
  }

  private isPhoneIdentifier(identifier: string): boolean {
    const value = String(identifier || '').trim();
    return Boolean(value && !value.includes('@'));
  }

  private async getIdentity(userId: string): Promise<IdentityRecord | null> {
    const { rows } = await getOrbiDatabase().query<IdentityRecord>(this.identityQuery, [
      userId,
      DEFAULT_INSTITUTIONAL_APP_ORIGIN,
    ]);
    return rows[0] || null;
  }

  private async resolveOrbiUserId(claims: JWTPayload): Promise<string | null> {
    const subject = String(claims.sub || '').trim();
    if (!subject) return null;
    const linked = await getOrbiDatabase().query<{ user_id: string }>(
      `SELECT user_id FROM orbi_auth.identity_links
       WHERE provider = $1 AND provider_subject = $2`,
      [provider, subject],
    );
    if (linked.rows[0]) {
      await getOrbiDatabase().query(
        `UPDATE orbi_auth.identity_links SET last_authenticated_at = NOW()
         WHERE provider = $1 AND provider_subject = $2`,
        [provider, subject],
      );
      return linked.rows[0].user_id;
    }

    const email = String(claims.email || claims.preferred_username || '').trim().toLowerCase();
    if (!email || !email.includes('@')) return null;
    const matches = await getOrbiDatabase().query<{ id: string }>(
      `SELECT id FROM auth.users WHERE lower(email) = $1 LIMIT 2`,
      [email],
    );
    if (matches.rows.length !== 1) return null;
    await getOrbiDatabase().query(
      `INSERT INTO orbi_auth.identity_links (
         provider, provider_subject, user_id, provider_username,
         provider_email, last_authenticated_at
       ) VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (provider, provider_subject) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         provider_username = EXCLUDED.provider_username,
         provider_email = EXCLUDED.provider_email,
         last_authenticated_at = NOW()`,
      [provider, subject, matches.rows[0].id, String(claims.preferred_username || ''), email],
    );
    return matches.rows[0].id;
  }

  private toSession(
    identity: IdentityRecord,
    accessToken: string,
    claims: JWTPayload,
    refreshToken?: string,
  ): Session {
    const expiresAt = Number(claims.exp || 0);
    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'Bearer',
      user: {
        id: identity.id,
        email: identity.email || undefined,
        phone: identity.phone || undefined,
        full_name: identity.full_name || 'Customer',
        customer_id: identity.customer_id || undefined,
        role: identity.role,
        account_status: identity.account_status,
        kyc_level: identity.kyc_level,
        kyc_status: identity.kyc_status,
        id_type: identity.id_type || undefined,
        id_number: identity.id_number || undefined,
        registry_type: identity.registry_type,
        app_origin: identity.app_origin,
        user_metadata: {
          ...identity.raw_user_meta_data,
          full_name: identity.full_name,
          customer_id: identity.customer_id,
          role: identity.role,
          account_status: identity.account_status,
          registry_type: identity.registry_type,
          app_origin: identity.app_origin,
          kyc_level: identity.kyc_level,
          kyc_status: identity.kyc_status,
        },
      },
      sub: identity.id,
      iss: String(claims.iss || issuer()),
      exp: expiresAt,
      expires_at: expiresAt,
      role: identity.role,
      permissions: permissionsForRole(identity.role),
      client_id: String(claims.azp || ''),
    };
  }

  private async getCoreJwtSession(token: string): Promise<Session | null> {
    const payload = await JWTNode.verify<JWTPayload & {
      userId?: string;
      issuer?: string;
      role?: string;
      registry_type?: string;
      app_origin?: string;
    }>(token);
    if (!payload || payload.type !== 'access') return null;

    const userId = String(payload.sub || payload.userId || '').trim();
    if (!userId) {
      keycloakAuthLogger.warn('core.session_missing_subject');
      return null;
    }

    const identity = await this.getIdentity(userId);
    if (!identity) {
      keycloakAuthLogger.warn('core.session_identity_unavailable', { sub: userId });
      return null;
    }
    if (identity.account_status === 'blocked' || identity.account_status === 'frozen') return null;

    return this.toSession(identity, token, {
      ...payload,
      sub: userId,
      iss: String(payload.iss || payload.issuer || 'orbi-core'),
      azp: String(payload.azp || 'orbi-core'),
    });
  }

  private async exchangeToken(params: Record<string, string>): Promise<KeycloakTokenResponse> {
    const response = await fetch(`${realmUrl()}/protocol/openid-connect/token`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: mobileClientId(), ...params }),
    });
    if (!response.ok) {
      const error: any = new Error(await readError(response));
      error.status = response.status;
      throw error;
    }
    return response.json() as Promise<KeycloakTokenResponse>;
  }

  async login(identifier: string, password: string, _metadata: LoginMetadata = {}) {
    try {
      const tokens = await this.exchangeToken({
        grant_type: 'password',
        username: identifier.trim(),
        password,
        scope: 'openid profile email',
      });
      const session = await this.getSession(tokens.access_token, tokens.refresh_token);
      if (!session) return { error: { message: 'IDENTITY_LINK_REQUIRED' } };
      return {
        user: session.user,
        session,
        access_token: tokens.access_token,
        refresh_token: tokens.refresh_token,
        biometric_setup_required: true,
      };
    } catch (error: any) {
      return { error: { message: error?.status === 401 ? 'INVALID_CREDENTIALS' : String(error?.message || error) } };
    }
  }

  async signUp(email: string, password: string, metadata: Record<string, any> = {}) {
    const normalizedEmail = email.trim().toLowerCase();
    const phone = String(metadata.phone || '').trim() || null;
    const currency = String(metadata.currency || '').trim().toUpperCase();
    if (!normalizedEmail) return { data: null, error: { message: 'EMAIL_REQUIRED' } };
    if (!currency) {
      return { data: null, error: { message: 'CURRENCY_REQUIRED: Account currency is mandatory at signup.' } };
    }

    const origin = String(metadata.app_origin || '');
    const isInstitutional = TRUSTED_INSTITUTIONAL_APP_ORIGINS.includes(origin);
    const isMobile = TRUSTED_MOBILE_APP_ORIGINS.includes(origin);
    const requestedRole = String(metadata.role || 'USER').toUpperCase() as UserRole;
    const staffRoles: UserRole[] = ['SUPER_ADMIN', 'ADMIN', 'IT', 'AUDIT', 'ACCOUNTANT', 'CUSTOMER_CARE', 'HUMAN_RESOURCE'];
    const role: UserRole = isInstitutional && staffRoles.includes(requestedRole) ? requestedRole : 'USER';
    const registryType = role !== 'USER' ? 'STAFF' : isMobile ? 'CONSUMER' : 'CONSUMER';
    if (registryType === 'STAFF') {
      return { data: null, error: { message: 'STAFF_CREATION_REQUIRES_BOOTSTRAP_OR_ADMIN' } };
    }

    const userId = randomUUID();
    const customerId = String(metadata.customer_id || IdentityGenerator.generateCustomerID());
    const accountStatus = process.env.ORBI_KEYCLOAK_REQUIRE_CONFIRMATION === 'true'
      ? 'pending_confirmation'
      : 'active';
    let keycloakUserId: string | null = null;
    const client = await getOrbiDatabase().connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO auth.users (
           id, email, phone, encrypted_password, raw_user_meta_data,
           email_confirmed_at, phone_confirmed_at
         ) VALUES ($1, $2, $3, 'KEYCLOAK_MANAGED', $4::jsonb, $5, $6)`,
        [
          userId, normalizedEmail, phone,
          JSON.stringify({
            ...metadata, customer_id: customerId, currency, role,
            registry_type: registryType, account_status: accountStatus,
            app_origin: origin || 'ORBI_MOBILE_V2026',
          }),
          accountStatus === 'active' ? new Date() : null,
          accountStatus === 'active' && phone ? new Date() : null,
        ],
      );

      const adminToken = await this.getAdminToken();
      const response = await fetch(`${adminUrl()}/users`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${adminToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          username: normalizedEmail,
          email: normalizedEmail,
          emailVerified: accountStatus === 'active',
          enabled: true,
          firstName: String(metadata.full_name || '').trim().split(/\s+/)[0] || undefined,
          lastName: String(metadata.full_name || '').trim().split(/\s+/).slice(1).join(' ') || undefined,
          attributes: {
            orbi_user_id: [userId],
            customer_id: [customerId],
            registry_type: [registryType],
          },
          credentials: [{ type: 'password', value: password, temporary: false }],
        }),
      });
      if (!response.ok) {
        throw new Error(response.status === 409 ? 'ACCOUNT_ALREADY_EXISTS' : await readError(response));
      }
      const location = response.headers.get('location') || '';
      keycloakUserId = location.split('/').filter(Boolean).pop() || null;
      if (!keycloakUserId) throw new Error('KEYCLOAK_USER_ID_MISSING');

      await client.query(
        `INSERT INTO orbi_auth.identity_links (
           provider, provider_subject, user_id, provider_username, provider_email
         ) VALUES ($1, $2, $3, $4, $5)`,
        [provider, keycloakUserId, userId, normalizedEmail, normalizedEmail],
      );
      await client.query('COMMIT');
      let activationChallenge: Awaited<ReturnType<typeof OTPService.generateAndSend>> | null = null;
      if (accountStatus !== 'active') {
        activationChallenge = await OTPService.generateAndSend(
          userId,
          normalizedEmail,
          'ACCOUNT_ACTIVATION',
          'email',
          'ORBI Account Activation',
          true,
        );
      }
      return {
        data: {
          user: {
            id: userId, email: normalizedEmail, phone,
            full_name: metadata.full_name || 'New User',
            customer_id: customerId, registry_type: registryType,
            account_status: accountStatus,
          },
          session: null,
          activation: accountStatus === 'active' ? null : {
            required: true,
            requestId: activationChallenge?.requestId,
            deliveryType: activationChallenge?.deliveryType,
            deliveryContact: this.maskContact(
              activationChallenge?.deliveryContact || normalizedEmail,
            ),
            expiresInSeconds: 300,
          },
        },
        error: null,
      };
    } catch (error: any) {
      await client.query('ROLLBACK');
      if (keycloakUserId) await this.deleteKeycloakUser(keycloakUserId).catch(() => undefined);
      return { data: null, error: { message: String(error?.message || error) } };
    } finally {
      client.release();
    }
  }

  async getSession(token?: string, refreshToken?: string): Promise<Session | null> {
    if (!token) return null;
    try {
      const header = decodeProtectedHeader(token);
      if (header.alg !== 'RS256') {
        return this.getCoreJwtSession(token);
      }

      const { payload } = await jwtVerify(token, this.jwks, {
        algorithms: ['RS256'],
        issuer: issuer(),
        audience: process.env.ORBI_KEYCLOAK_AUDIENCE || undefined,
      });
      const azp = String(payload.azp || '');
      const aud = Array.isArray(payload.aud)
        ? payload.aud.map(String)
        : payload.aud
          ? [String(payload.aud)]
          : [];
      const expectedAudience = String(process.env.ORBI_KEYCLOAK_AUDIENCE || '').trim();
      const allowedClientIds = new Set([
        mobileClientId(),
        'orbi-core',
        ...(expectedAudience ? [expectedAudience] : []),
      ]);
      const clientAllowed =
        (azp && allowedClientIds.has(azp)) ||
        aud.some((value) => allowedClientIds.has(value));
      if (!clientAllowed) {
        keycloakAuthLogger.warn('keycloak.session_client_rejected', {
          azp,
          aud,
        });
        return null;
      }
      if (!payload.sub) {
        keycloakAuthLogger.warn('keycloak.session_missing_subject');
        return null;
      }
      if (!payload.jti) {
        keycloakAuthLogger.warn('keycloak.session_missing_jti', {
          sub: String(payload.sub),
        });
        return null;
      }
      const revoked = await getOrbiDatabase().query(
        `SELECT 1 FROM orbi_auth.revoked_access_tokens
         WHERE jti::text = $1 AND expires_at > NOW()`,
        [String(payload.jti)],
      );
      if (revoked.rows.length > 0) return null;
      const userId = await this.resolveOrbiUserId(payload);
      if (!userId) {
        keycloakAuthLogger.warn('keycloak.session_identity_link_missing', {
          sub: String(payload.sub),
          email: String(payload.email || payload.preferred_username || ''),
          azp,
        });
        return null;
      }
      const identity = await this.getIdentity(userId);
      if (!identity || ['blocked', 'frozen'].includes(identity.account_status.toLowerCase())) {
        keycloakAuthLogger.warn('keycloak.session_identity_unavailable', {
          user_id: userId,
          status: identity?.account_status,
        });
        return null;
      }
      return this.toSession(identity, token, payload, refreshToken);
    } catch (error: any) {
      keycloakAuthLogger.warn('keycloak.session_verify_failed', {
        error: String(error?.message || error),
      });
      return null;
    }
  }

  async refreshSession(refreshToken: string, _metadata: LoginMetadata = {}) {
    try {
      const tokens = await this.exchangeToken({
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      });
      const session = await this.getSession(tokens.access_token, tokens.refresh_token);
      if (!session) return { error: { message: 'INVALID_REFRESH_TOKEN' } };
      return { session, access_token: tokens.access_token, refresh_token: tokens.refresh_token };
    } catch {
      return { error: { message: 'INVALID_REFRESH_TOKEN' } };
    }
  }

  async logout(accessToken?: string, refreshToken?: string) {
    if (accessToken) {
      try {
        const claims = decodeJwt(accessToken);
        if (claims.jti && claims.exp) {
          const userId = await this.resolveOrbiUserId(claims);
          if (userId) {
            await getOrbiDatabase().query(
              `INSERT INTO orbi_auth.revoked_access_tokens (jti, user_id, expires_at, reason)
               VALUES ($1, $2, to_timestamp($3), 'logout')
               ON CONFLICT (jti) DO NOTHING`,
              [String(claims.jti), userId, claims.exp],
            );
          }
        }
      } catch {
        // Logout remains idempotent for malformed or expired tokens.
      }
    }
    if (refreshToken) {
      await fetch(`${realmUrl()}/protocol/openid-connect/logout`, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ client_id: mobileClientId(), refresh_token: refreshToken }),
      }).catch(() => undefined);
    }
    return { success: true };
  }

  async initiatePasswordReset(identifier: string) {
    const identity = await this.findChallengeIdentity(identifier);
    if (!identity) return { data: { requestId: null, deliveryContact: null }, error: null };
    if (identity.status.toLowerCase() !== 'active') {
      return { data: null, error: new Error('ACCOUNT_NOT_ACTIVE: Confirm your account before resetting the password.') };
    }
    const challengeContact = this.preferredChallengeContact(identity, identifier, true);
    if (!challengeContact) return { data: null, error: new Error('NO_CONTACT_AVAILABLE') };
    const result = await OTPService.generateAndSend(
      identity.id,
      challengeContact.contact,
      'PASSWORD_RESET',
      challengeContact.type,
      'ORBI Password Reset',
      true,
    );
    if (result.requestId === 'THROTTLED') {
      return { data: null, error: new Error('OTP_THROTTLED: Please wait before requesting another OTP.') };
    }
    if (result.requestId.startsWith('ERROR_')) {
      return { data: null, error: new Error(result.requestId) };
    }
    return {
      data: {
        requestId: result.requestId,
        deliveryType: result.deliveryType,
        deliveryContact: this.maskContact(result.deliveryContact || challengeContact.contact),
        expiresInSeconds: 300,
      },
      error: null,
    };
  }

  async completePasswordReset(
    password: string,
    identifier?: string,
    requestId?: string,
    code?: string,
  ) {
    if (!identifier || !requestId || !code) {
      return { data: null, error: new Error('PASSWORD_RESET_CHALLENGE_REQUIRED') };
    }
    const normalizedPassword = String(password || '').trim();
    const passwordPolicyError = this.validatePasswordPolicy(normalizedPassword);
    if (passwordPolicyError) return { data: null, error: passwordPolicyError };
    const identity = await this.findChallengeIdentity(identifier);
    if (!identity) return { data: null, error: new Error('IDENTITY_NOT_FOUND') };
    const valid = await OTPService.verify(requestId, code, identity.id);
    if (!valid) return { data: null, error: new Error('INVALID_OTP') };
    try {
      await this.setKeycloakPassword(identity.id, normalizedPassword);
    } catch (error: any) {
      const message = String(error?.message || error || '');
      if (message.toLowerCase().includes('invalidpasswordhistory')) {
        return { data: null, error: new Error('PASSWORD_RECENTLY_USED') };
      }
      if (message.toLowerCase().includes('invalid password')) {
        return { data: null, error: new Error(`INVALID_PASSWORD_POLICY: ${message}`) };
      }
      throw error;
    }
    return { data: { userId: identity.id }, error: null };
  }

  async initiateAccountConfirmation(identifier: string, replacementContact?: string) {
    const identity = await this.findChallengeIdentity(identifier);
    if (!identity) return { success: true, requestId: null };
    const contact = String(replacementContact || identity.email || identity.phone || '').trim();
    if (!contact) return { error: 'NO_CONTACT_AVAILABLE' };
    const type = contact.includes('@') ? 'email' : 'sms';
    const result = await OTPService.generateAndSend(
      identity.id,
      contact,
      'ACCOUNT_CONFIRMATION',
      type,
      'ORBI Account Confirmation',
    );
    return {
      success: true,
      requestId: result.requestId,
      deliveryType: result.deliveryType,
      deliveryContact: this.maskContact(result.deliveryContact || contact),
      expiresInSeconds: 300,
    };
  }

  async confirmAccount(identifier: string, requestId: string, code: string) {
    const identity = await this.findChallengeIdentity(identifier);
    if (!identity) return { success: false, error: 'IDENTITY_NOT_FOUND' };
    const valid = await OTPService.verify(requestId, code, identity.id);
    if (!valid) return { success: false, error: 'INVALID_OTP' };

    const client = await getOrbiDatabase().connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `UPDATE auth.users
         SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
             phone_confirmed_at = CASE WHEN phone IS NOT NULL THEN COALESCE(phone_confirmed_at, NOW()) ELSE phone_confirmed_at END,
             raw_user_meta_data = raw_user_meta_data || '{"account_status":"active"}'::jsonb,
             updated_at = NOW()
         WHERE id = $1`,
        [identity.id],
      );
      await client.query(`UPDATE public.users SET account_status = 'active' WHERE id = $1`, [identity.id]);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
    await this.setKeycloakEmailVerified(identity.id);
    return { success: true, userId: identity.id };
  }

  async getUserProfile(userId: string) {
    const identity = await this.getIdentity(userId);
    return {
      data: identity
        ? {
            id: identity.id, email: identity.email, phone: identity.phone,
            full_name: identity.full_name, customer_id: identity.customer_id,
            account_status: identity.account_status, role: identity.role,
            registry_type: identity.registry_type, app_origin: identity.app_origin,
            kyc_level: identity.kyc_level, kyc_status: identity.kyc_status,
            metadata: identity.raw_user_meta_data,
          }
        : null,
    };
  }
}
