import bcrypt from 'bcryptjs';
import { createHash, randomBytes, randomUUID } from 'crypto';
import jwt, { JwtPayload } from 'jsonwebtoken';
import type { Pool, PoolClient } from 'pg';
import type { Permission, Session, UserRole } from '../types.js';
import { IdentityGenerator } from '../services/utils.js';
import { getOrbiDatabase } from '../services/orbiDatabase.js';
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

type AccessClaims = JwtPayload & {
  sub: string;
  jti: string;
  type: 'access';
  role: UserRole;
  registry_type: string;
  app_origin: string;
  token_version: number;
};

type IdentityRecord = {
  id: string;
  email: string | null;
  phone: string | null;
  encrypted_password: string;
  raw_user_meta_data: Record<string, any>;
  token_version: number;
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

const accessTtlSeconds = () => Number(process.env.ORBI_ACCESS_TOKEN_TTL_SECONDS || 900);
const refreshTtlSeconds = () => Number(process.env.ORBI_REFRESH_TOKEN_TTL_SECONDS || 2592000);
const issuer = () => String(process.env.ORBI_AUTH_ISSUER || 'orbi-auth');
const audience = () => String(process.env.ORBI_AUTH_AUDIENCE || 'orbi-core');

const jwtSecret = (): string => {
  const value = String(process.env.JWT_SECRET || '').trim();
  if (!value) throw new Error('JWT_SECRET_REQUIRED');
  return value;
};

const tokenHash = (token: string) => createHash('sha256').update(token).digest('hex');

const permissionsForRole = (role: UserRole): Permission[] => {
  const common: Permission[] = ['auth.login', 'auth.logout', 'auth.refresh', 'user.read', 'user.update'];
  if (role === 'SUPER_ADMIN') {
    return [
      ...common,
      'auth.pwd_reset',
      'user.freeze',
      'wallet.read',
      'wallet.create',
      'wallet.update',
      'wallet.delete',
      'wallet.credit',
      'wallet.debit',
      'wallet.freeze',
      'transaction.create',
      'transaction.view',
      'transaction.verify',
      'transaction.reverse',
      'transaction.delete',
      'ledger.read',
      'ledger.write',
      'admin.approve',
      'admin.freeze',
      'admin.audit.read',
      'admin.user.manage',
      'staff.read',
      'staff.write',
    ];
  }
  if (['ADMIN', 'IT', 'AUDIT', 'ACCOUNTANT', 'CUSTOMER_CARE', 'HUMAN_RESOURCE'].includes(role)) {
    return [...common, 'wallet.read', 'transaction.view', 'ledger.read', 'admin.audit.read'];
  }
  return [...common, 'wallet.read', 'wallet.create', 'wallet.update', 'transaction.create', 'transaction.view'];
};

export class OrbiAuthService {
  private identityQuery = `
    SELECT
      au.id,
      au.email,
      au.phone,
      au.encrypted_password,
      au.raw_user_meta_data,
      au.token_version,
      COALESCE(s.full_name, u.full_name, au.raw_user_meta_data->>'full_name') AS full_name,
      COALESCE(s.customer_id, u.customer_id, au.raw_user_meta_data->>'customer_id') AS customer_id,
      COALESCE(s.account_status, u.account_status, au.raw_user_meta_data->>'account_status', 'active') AS account_status,
      COALESCE(s.role, u.role, au.raw_user_meta_data->>'role', 'USER') AS role,
      COALESCE(u.registry_type, au.raw_user_meta_data->>'registry_type', CASE WHEN s.id IS NOT NULL THEN 'STAFF' ELSE 'CONSUMER' END) AS registry_type,
      COALESCE(u.app_origin, au.raw_user_meta_data->>'app_origin', $2) AS app_origin,
      COALESCE(u.kyc_level, 0) AS kyc_level,
      COALESCE(u.kyc_status, 'unverified') AS kyc_status,
      u.id_type,
      u.id_number
    FROM auth.users au
    LEFT JOIN public.users u ON u.id = au.id
    LEFT JOIN public.staff s ON s.id = au.id
    WHERE au.id = $1
  `;

  private async findIdentity(identifier: string): Promise<IdentityRecord | null> {
    const normalized = identifier.trim().toLowerCase();
    const { rows } = await getOrbiDatabase().query<{ id: string }>(
      `SELECT id
       FROM auth.users
       WHERE lower(email) = $1 OR phone = $2
       LIMIT 1`,
      [normalized, identifier.trim()],
    );
    if (!rows[0]) return null;
    return this.getIdentity(rows[0].id);
  }

  private async getIdentity(
    userId: string,
    client: Pick<Pool, 'query'> | Pick<PoolClient, 'query'> = getOrbiDatabase(),
  ): Promise<IdentityRecord | null> {
    const { rows } = await client.query<IdentityRecord>(this.identityQuery, [
      userId,
      DEFAULT_INSTITUTIONAL_APP_ORIGIN,
    ]);
    return rows[0] || null;
  }

  private issueAccessToken(identity: IdentityRecord): { token: string; expiresAt: number } {
    const expiresIn = accessTtlSeconds();
    const expiresAt = Math.floor(Date.now() / 1000) + expiresIn;
    const token = jwt.sign(
      {
        type: 'access',
        role: identity.role,
        registry_type: identity.registry_type,
        app_origin: identity.app_origin,
        token_version: identity.token_version,
      },
      jwtSecret(),
      {
        algorithm: 'HS256',
        subject: identity.id,
        jwtid: randomUUID(),
        issuer: issuer(),
        audience: audience(),
        expiresIn,
      },
    );
    return { token, expiresAt };
  }

  private async createRefreshSession(
    client: PoolClient,
    identity: IdentityRecord,
    metadata: LoginMetadata = {},
    familyId: string = randomUUID(),
  ): Promise<{ token: string; expiresAt: Date; id: string }> {
    const token = randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + refreshTtlSeconds() * 1000);
    const id = randomUUID();
    await client.query(
      `INSERT INTO orbi_auth.refresh_sessions (
         id, user_id, token_hash, family_id, device_fingerprint,
         ip_address, user_agent, expires_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        id,
        identity.id,
        tokenHash(token),
        familyId,
        metadata.fingerprint || null,
        metadata.ip || null,
        metadata.userAgent || null,
        expiresAt,
      ],
    );
    return { token, expiresAt, id };
  }

  private toSession(
    identity: IdentityRecord,
    accessToken: string,
    expiresAt: number,
    refreshToken?: string,
  ): Session {
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
      iss: issuer(),
      exp: expiresAt,
      expires_at: expiresAt,
      role: identity.role,
      permissions: permissionsForRole(identity.role),
    };
  }

  async signUp(email: string, password: string, metadata: Record<string, any> = {}) {
    const normalizedEmail = email.trim().toLowerCase();
    const phone = String(metadata.phone || '').trim() || null;
    if (!normalizedEmail && !phone) {
      return { data: null, error: { message: 'EMAIL_OR_PHONE_REQUIRED' } };
    }
    if (password.length < 8) {
      return { data: null, error: { message: 'PASSWORD_TOO_SHORT' } };
    }

    const currency = String(metadata.currency || '').trim().toUpperCase();
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
    const accountStatus = process.env.ORBI_LOCAL_AUTH_REQUIRE_CONFIRMATION === 'true'
      ? 'pending_confirmation'
      : 'active';
    const passwordHash = await bcrypt.hash(password, Number(process.env.ORBI_PASSWORD_BCRYPT_ROUNDS || 12));
    const userMetadata = {
      ...metadata,
      customer_id: customerId,
      currency,
      role,
      registry_type: registryType,
      account_status: accountStatus,
      app_origin: origin || 'ORBI_MOBILE_V2026',
    };

    try {
      await getOrbiDatabase().query(
        `INSERT INTO auth.users (
           id, email, phone, encrypted_password, raw_user_meta_data,
           email_confirmed_at, phone_confirmed_at
         ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7)`,
        [
          userId,
          normalizedEmail || null,
          phone,
          passwordHash,
          JSON.stringify(userMetadata),
          accountStatus === 'active' && normalizedEmail ? new Date() : null,
          accountStatus === 'active' && phone ? new Date() : null,
        ],
      );

      return {
        data: {
          user: {
            id: userId,
            email: normalizedEmail || null,
            phone,
            full_name: metadata.full_name || 'New User',
            customer_id: customerId,
            registry_type: registryType,
            account_status: accountStatus,
          },
          session: null,
        },
        error: null,
      };
    } catch (error: any) {
      const duplicate = error?.code === '23505';
      return {
        data: null,
        error: { message: duplicate ? 'ACCOUNT_ALREADY_EXISTS' : String(error?.message || error) },
      };
    }
  }

  async login(identifier: string, password: string, metadata: LoginMetadata = {}) {
    const identity = await this.findIdentity(identifier);
    if (!identity || !(await bcrypt.compare(password, identity.encrypted_password))) {
      return { error: { message: 'INVALID_CREDENTIALS' } };
    }
    if (identity.account_status !== 'active') {
      return { error: { message: 'ACCOUNT_NOT_ACTIVE', account_status: identity.account_status } };
    }

    const client = await getOrbiDatabase().connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `UPDATE orbi_auth.refresh_sessions
         SET revoked_at = NOW(), revocation_reason = 'new_login'
         WHERE user_id = $1 AND revoked_at IS NULL`,
        [identity.id],
      );
      const refresh = await this.createRefreshSession(client, identity, metadata);
      await client.query(
        `UPDATE auth.users SET last_sign_in_at = NOW(), updated_at = NOW() WHERE id = $1`,
        [identity.id],
      );
      await client.query('COMMIT');

      const access = this.issueAccessToken(identity);
      const session = this.toSession(identity, access.token, access.expiresAt, refresh.token);
      return {
        user: session.user,
        session,
        access_token: access.token,
        refresh_token: refresh.token,
        biometric_setup_required: true,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async getSession(token?: string): Promise<Session | null> {
    if (!token) return null;
    try {
      const payload = jwt.verify(token, jwtSecret(), {
        algorithms: ['HS256'],
        issuer: issuer(),
        audience: audience(),
      }) as AccessClaims;
      if (payload.type !== 'access' || !payload.sub || !payload.jti) return null;

      const { rows: revokedRows } = await getOrbiDatabase().query(
        `SELECT 1 FROM orbi_auth.revoked_access_tokens
         WHERE jti = $1 AND expires_at > NOW()`,
        [payload.jti],
      );
      if (revokedRows.length > 0) return null;

      const identity = await this.getIdentity(payload.sub);
      if (!identity || identity.token_version !== payload.token_version) return null;
      if (identity.account_status === 'blocked' || identity.account_status === 'frozen') return null;
      return this.toSession(identity, token, Number(payload.exp || 0));
    } catch {
      return null;
    }
  }

  async refreshSession(refreshToken: string, metadata: LoginMetadata = {}) {
    const client = await getOrbiDatabase().connect();
    try {
      await client.query('BEGIN');
      const hash = tokenHash(refreshToken);
      const { rows } = await client.query<{
        id: string;
        user_id: string;
        family_id: string;
        device_fingerprint: string | null;
        expires_at: Date;
        revoked_at: Date | null;
        replaced_by_session_id: string | null;
      }>(
        `SELECT id, user_id, family_id, device_fingerprint, expires_at,
                revoked_at, replaced_by_session_id
         FROM orbi_auth.refresh_sessions
         WHERE token_hash = $1
         FOR UPDATE`,
        [hash],
      );
      const current = rows[0];
      if (!current || current.expires_at.getTime() <= Date.now()) {
        await client.query('ROLLBACK');
        return { error: { message: 'INVALID_REFRESH_TOKEN' } };
      }
      if (current.revoked_at || current.replaced_by_session_id) {
        await client.query(
          `UPDATE orbi_auth.refresh_sessions
           SET revoked_at = COALESCE(revoked_at, NOW()), revocation_reason = 'refresh_token_reuse'
           WHERE family_id = $1`,
          [current.family_id],
        );
        await client.query(
          `UPDATE auth.users SET token_version = token_version + 1, updated_at = NOW() WHERE id = $1`,
          [current.user_id],
        );
        await client.query('COMMIT');
        return { error: { message: 'SECURITY_ALERT: Refresh token reuse detected.' } };
      }
      if (
        metadata.fingerprint &&
        current.device_fingerprint &&
        metadata.fingerprint !== current.device_fingerprint
      ) {
        await client.query(
          `UPDATE orbi_auth.refresh_sessions
           SET revoked_at = NOW(), revocation_reason = 'device_mismatch'
           WHERE family_id = $1`,
          [current.family_id],
        );
        await client.query('COMMIT');
        return { error: { message: 'DEVICE_MISMATCH: Session terminated.' } };
      }

      const identity = await this.getIdentity(current.user_id, client);
      if (!identity || identity.account_status !== 'active') {
        await client.query('ROLLBACK');
        return { error: { message: 'IDENTITY_NOT_ACTIVE' } };
      }

      const next = await this.createRefreshSession(
        client,
        identity,
        {
          fingerprint: metadata.fingerprint || current.device_fingerprint || undefined,
          ip: metadata.ip,
        },
        current.family_id,
      );
      await client.query(
        `UPDATE orbi_auth.refresh_sessions
         SET revoked_at = NOW(), revocation_reason = 'rotated',
             replaced_by_session_id = $2, last_used_at = NOW()
         WHERE id = $1`,
        [current.id, next.id],
      );
      await client.query('COMMIT');

      const access = this.issueAccessToken(identity);
      return {
        session: this.toSession(identity, access.token, access.expiresAt, next.token),
        access_token: access.token,
        refresh_token: next.token,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async logout(accessToken?: string, refreshToken?: string) {
    const client = await getOrbiDatabase().connect();
    try {
      await client.query('BEGIN');
      if (refreshToken) {
        await client.query(
          `UPDATE orbi_auth.refresh_sessions
           SET revoked_at = NOW(), revocation_reason = 'logout'
           WHERE token_hash = $1 AND revoked_at IS NULL`,
          [tokenHash(refreshToken)],
        );
      }
      if (accessToken) {
        try {
          const payload = jwt.verify(accessToken, jwtSecret(), {
            algorithms: ['HS256'],
            issuer: issuer(),
            audience: audience(),
            ignoreExpiration: true,
          }) as AccessClaims;
          if (payload.jti && payload.exp) {
            await client.query(
              `INSERT INTO orbi_auth.revoked_access_tokens (jti, user_id, expires_at, reason)
               VALUES ($1, $2, to_timestamp($3), 'logout')
               ON CONFLICT (jti) DO NOTHING`,
              [payload.jti, payload.sub, payload.exp],
            );
          }
        } catch {
          // Logout remains idempotent for already-invalid access tokens.
        }
      }
      await client.query('COMMIT');
      return { success: true };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async getUserProfile(userId: string) {
    const identity = await this.getIdentity(userId);
    return {
      data: identity
        ? {
            id: identity.id,
            email: identity.email,
            phone: identity.phone,
            full_name: identity.full_name,
            customer_id: identity.customer_id,
            account_status: identity.account_status,
            role: identity.role,
            registry_type: identity.registry_type,
            app_origin: identity.app_origin,
            kyc_level: identity.kyc_level,
            kyc_status: identity.kyc_status,
            metadata: identity.raw_user_meta_data,
          }
        : null,
    };
  }
}
