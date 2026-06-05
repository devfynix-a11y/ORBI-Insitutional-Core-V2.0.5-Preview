
import { Session, User, UserRole, Permission, UserSession } from '../types.js';
import { getSupabase, getAdminSupabase, createAuthenticatedClient } from '../services/supabaseClient.js';
import { Storage, STORAGE_KEYS } from '../backend/storage.js';
import { UUID, IdentityGenerator } from '../services/utils.js';
import { OTPService } from '../backend/security/otpService.js';
import { Audit } from '../backend/security/audit.js';
import { createHash } from 'crypto';
import { SecurityService } from './securityService.js';
import { Messaging } from '../backend/features/MessagingService.js';
import { ProvisioningService } from '../backend/features/ProvisioningService.js';
import { WalletService } from '../wealth/walletService.js';
import { parsePhoneNumber } from 'libphonenumber-js';
import { JWTNode } from '../backend/security/jwt.js';
import { DEFAULT_INSTITUTIONAL_APP_ORIGIN, TRUSTED_INSTITUTIONAL_APP_ORIGINS, TRUSTED_MOBILE_APP_ORIGINS } from '../backend/config/appIdentity.js';
import { buildPostgrestOrFilter } from '../backend/security/postgrest.js';

/**
 * ORBI AUTHENTICATION PROTOCOL (V24.5 Titanium Hardened)
 * ---------------------------------------------
 * Hardened for Zero-Trust Identity Quarantine.
 * Implements Full Banking Model Security:
 * - Refresh Token Rotation
 * - Reuse Detection
 * - Device Fingerprinting
 * - Login Anomaly Detection
 */
import { BruteForceService } from '../backend/src/services/bruteForce.service.js';

export class AuthService {
    private security = new SecurityService();
    private bruteForce = new BruteForceService();
    private readonly activationTtlMs = 24 * 60 * 60 * 1000;
    private readonly allowLocalSessionFallback =
        process.env.NODE_ENV !== 'production' &&
        process.env.ORBI_ALLOW_LOCAL_SESSION_FALLBACK === 'true';

    private hashToken(token: string): string {
        return createHash('sha256').update(token).digest('hex');
    }

    private async detectLoginAnomaly(userId: string, fingerprint: string, ip: string): Promise<boolean> {
        const sb = getSupabase();
        if (!sb) return false;

        // Check for new device/IP
        const { data: sessions } = await sb.from('user_sessions')
            .select('device_fingerprint, ip_address')
            .eq('user_id', userId)
            .order('created_at', { ascending: false })
            .limit(5);

        if (!sessions || sessions.length === 0) return false; // First login is not anomalous

        const knownDevice = sessions.some(s => s.device_fingerprint === fingerprint);
        const knownIP = sessions.some(s => s.ip_address === ip);

        if (!knownDevice && !knownIP) {
            // High risk: New device AND new IP
            return true;
        }
        return false;
    }

    private async revokeSessionChain(userId: string, tokenHash: string) {
        const sb = getSupabase();
        if (!sb) return;

        // Recursive revocation or just revoke all for user if reuse detected
        // For banking security, revoking all sessions for the user is safer upon reuse detection
        await sb.from('user_sessions')
            .update({ is_revoked: true })
            .eq('user_id', userId);
            
        // Also sign out from Supabase to invalidate JWTs
        const adminSb = getAdminSupabase();
        if (adminSb) {
            await adminSb.auth.admin.signOut(userId);
        }
    }

    private getPermissionsForRole(role: UserRole = 'USER', status: string = 'pending'): Permission[] {
        // Enforce total scope lockdown for non-active nodes
        if (status !== 'active') return [];

        const common: Permission[] = ['auth.login', 'auth.logout', 'user.read', 'user.update'];

        const adminOps: Permission[] = [
            'staff.read',
            'staff.write',
            'provider.read',
            'provider.write',
            'institutional_account.read',
            'institutional_account.write',
            'provider_routing.read',
            'provider_routing.write',
            'config.ledger.read',
            'config.ledger.write',
            'config.fx.read',
            'config.fx.write',
            'config.commissions.read',
            'config.commissions.write',
            'reconciliation.read',
            'reconciliation.run',
            'device.read',
            'device.trust.manage',
            'kyc.review',
            'document.review',
            'service_access.review',
        ];

        if (role === 'SUPER_ADMIN') {
            return [
                ...common,
                'user.freeze',
                'wallet.read', 'wallet.create', 'wallet.update', 'wallet.delete', 'wallet.credit', 'wallet.debit', 'wallet.freeze',
                'transaction.create', 'transaction.view', 'transaction.verify', 'transaction.reverse', 'transaction.delete',
                'ledger.read', 'ledger.write',
                'admin.approve', 'admin.freeze', 'admin.audit.read', 'admin.user.manage',
                'system.wallet.credit', 'system.wallet.debit',
                'auth.pwd_reset',
                ...adminOps,
            ];
        }

        switch (role) {
            case 'ADMIN':
                return [
                    ...common,
                    'wallet.read', 'wallet.update',
                    'transaction.view', 'transaction.verify',
                    'ledger.read',
                    'admin.approve', 'admin.audit.read', 'admin.user.manage',
                    'staff.read', 'staff.write',
                    'provider.read', 'provider.write',
                    'institutional_account.read', 'institutional_account.write',
                    'provider_routing.read', 'provider_routing.write',
                    'config.ledger.read', 'config.ledger.write',
                    'config.fx.read', 'config.fx.write',
                    'config.commissions.read', 'config.commissions.write',
                    'reconciliation.read', 'reconciliation.run',
                    'device.read', 'device.trust.manage',
                    'kyc.review', 'document.review', 'service_access.review',
                ];
            case 'HUMAN_RESOURCE':
                return [
                    ...common,
                    'user.freeze',
                    'admin.user.manage',
                    'admin.approve',
                    'staff.read', 'staff.write',
                ];
            case 'AUDIT':
                return [
                    ...common,
                    'wallet.read',
                    'transaction.view',
                    'ledger.read',
                    'admin.audit.read',
                    'reconciliation.read',
                    'staff.read',
                ];
            case 'ACCOUNTANT':
                return [
                    ...common,
                    'wallet.read',
                    'transaction.view',
                    'ledger.read',
                    'ledger.write',
                    'reconciliation.read',
                    'config.commissions.read',
                    'config.fx.read',
                ];
            case 'IT':
                return [
                    ...common,
                    'admin.audit.read',
                    'system.wallet.credit', 'system.wallet.debit',
                    'provider.read', 'provider.write',
                    'institutional_account.read', 'institutional_account.write',
                    'provider_routing.read', 'provider_routing.write',
                    'device.read', 'device.trust.manage',
                    'config.ledger.read',
                    'config.fx.read',
                ];
            case 'CUSTOMER_CARE':
                return [
                    ...common,
                    'transaction.view',
                    'kyc.review',
                    'document.review',
                    'service_access.review',
                ];
            case 'MERCHANT':
                return [
                    ...common,
                    'wallet.read',
                    'transaction.create',
                    'transaction.view',
                    'merchant.read',
                    'merchant.create',
                    'merchant.update',
                    'merchant.settlement',
                ];
            case 'AGENT':
                return [
                    ...common,
                    'wallet.read',
                    'transaction.create',
                    'transaction.view',
                    'agent.cash.deposit',
                    'agent.cash.withdraw',
                    'agent.float.manage',
                ];
            case 'CONSUMER':
            case 'USER':
                return [...common, 'wallet.read', 'wallet.create', 'wallet.update', 'wallet.delete', 'transaction.create', 'transaction.view', 'goal.read', 'goal.create', 'goal.update', 'goal.delete', 'category.read', 'category.create', 'category.update', 'category.delete', 'task.read', 'task.create', 'task.update', 'task.delete'];
            default: return [...common];
        }
    }

    public describePermissionsForRole(role: UserRole = 'USER', status: string = 'pending'): Permission[] {
        return this.getPermissionsForRole(role, status);
    }

    private isActiveStatus(status?: string | null): boolean {
        return String(status || '').trim().toLowerCase() === 'active';
    }

    private isConfirmationPendingStatus(status?: string | null): boolean {
        return ['pending', 'pending_confirmation', 'unconfirmed', 'inactive'].includes(
            String(status || '').trim().toLowerCase(),
        );
    }

    private maskContact(contact?: string | null): string {
        const value = String(contact || '').trim();
        if (!value) return '';
        if (value.includes('@')) {
            const [name, domain] = value.split('@');
            return `${name.slice(0, 2)}***@${domain}`;
        }
        return value.length <= 6 ? '***' : `${value.slice(0, 4)}***${value.slice(-3)}`;
    }

    private normalizePhoneIdentifier(identifier: string): string {
        const value = String(identifier || '').trim();
        if (!value || value.includes('@')) return value;
        try {
            const phoneNumber = parsePhoneNumber(value, 'TZ');
            if (phoneNumber && phoneNumber.isValid()) return phoneNumber.format('E.164');
        } catch (e) {
            // Fall through to compact E.164-style normalization.
        }
        return value.startsWith('+') ? value : '+' + value.replace(/\s/g, '');
    }

    private async resolveIdentityForChallenge(identifier: string): Promise<{
        userId: string;
        table: 'users' | 'staff';
        email?: string | null;
        phone?: string | null;
        fullName?: string | null;
        language?: string | null;
        status?: string | null;
        registryType?: string | null;
        customerId?: string | null;
    } | null> {
        const sb = getAdminSupabase();
        if (!sb) return null;

        const rawIdentifier = String(identifier || '').trim();
        if (!rawIdentifier) return null;
        const normalizedIdentifier = this.normalizePhoneIdentifier(rawIdentifier);
        const isEmail = rawIdentifier.includes('@');
        const filters: Array<{ column: string; operator: 'eq'; value: unknown }> = isEmail
            ? [{ column: 'email', operator: 'eq', value: rawIdentifier.toLowerCase() }]
            : [
                { column: 'phone', operator: 'eq', value: normalizedIdentifier },
                { column: 'customer_id', operator: 'eq', value: rawIdentifier },
            ];

        for (const table of ['users', 'staff'] as const) {
            const { data } = await sb
                .from(table)
                .select('id, full_name, email, phone, language, account_status, registry_type, customer_id')
                .or(buildPostgrestOrFilter(filters))
                .maybeSingle();
            if (data) {
                return {
                    userId: data.id,
                    table,
                    email: data.email,
                    phone: data.phone,
                    fullName: data.full_name,
                    language: data.language,
                    status: data.account_status,
                    registryType: data.registry_type || (table === 'staff' ? 'STAFF' : 'CONSUMER'),
                    customerId: data.customer_id,
                };
            }
        }

        return null;
    }

    private preferredChallengeContact(identity: { email?: string | null; phone?: string | null }, fallback?: string): { contact: string; type: 'sms' | 'email' } | null {
        const phone = String(identity.phone || '').trim();
        const email = String(identity.email || '').trim();
        const fallbackValue = String(fallback || '').trim();
        if (phone) return { contact: phone, type: 'sms' };
        if (email) return { contact: email, type: 'email' };
        if (fallbackValue) return { contact: fallbackValue, type: fallbackValue.includes('@') ? 'email' : 'sms' };
        return null;
    }

    private normalizeActivationContact(contact: string): { contact: string; type: 'sms' | 'email'; column: 'phone' | 'email' } {
        const value = String(contact || '').trim();
        if (!value) throw new Error('MISSING_CONTACT');
        if (value.includes('@')) {
            return { contact: value.toLowerCase(), type: 'email', column: 'email' };
        }
        return { contact: this.normalizePhoneIdentifier(value), type: 'sms', column: 'phone' };
    }

    private async assertActivationContactAvailable(contact: string, excludeUserId: string) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error('DB_OFFLINE');
        const normalized = this.normalizeActivationContact(contact);
        for (const table of ['users', 'staff'] as const) {
            const { data, error } = await sb
                .from(table)
                .select('id')
                .eq(normalized.column, normalized.contact)
                .neq('id', excludeUserId)
                .maybeSingle();
            if (error) throw error;
            if (data) throw new Error(`${normalized.column === 'email' ? 'EMAIL' : 'PHONE'}_ALREADY_IN_USE`);
        }
        return normalized;
    }

    private async issueAccountActivationChallenge(
        identity: {
            userId: string;
            table: 'users' | 'staff';
            email?: string | null;
            phone?: string | null;
            fullName?: string | null;
            language?: string | null;
            status?: string | null;
            registryType?: string | null;
            customerId?: string | null;
        },
        fallback?: string,
        replacementContact?: string,
    ) {
        const sb = getAdminSupabase();
        if (!sb) throw new Error('DB_OFFLINE');

        let forcedContact: { contact: string; type: 'sms' | 'email'; column: 'phone' | 'email' } | null = null;
        if (replacementContact && replacementContact.trim()) {
            forcedContact = await this.assertActivationContactAvailable(replacementContact, identity.userId);
            await sb.from(identity.table).update({
                [forcedContact.column]: forcedContact.contact,
            }).eq('id', identity.userId);
            await sb.auth.admin.updateUserById(identity.userId, {
                ...(forcedContact.column === 'email' ? { email: forcedContact.contact, email_confirm: false } : {}),
                ...(forcedContact.column === 'phone' ? { phone: forcedContact.contact, phone_confirm: false } : {}),
                user_metadata: {
                    email: forcedContact.column === 'email' ? forcedContact.contact : identity.email,
                    phone: forcedContact.column === 'phone' ? forcedContact.contact : identity.phone,
                },
            });
            if (forcedContact.column === 'email') identity.email = forcedContact.contact;
            if (forcedContact.column === 'phone') identity.phone = forcedContact.contact;
        }

        const challengeContact = forcedContact || this.preferredChallengeContact(identity, fallback);
        if (!challengeContact) return { success: false, error: 'NO_CONTACT_AVAILABLE' };

        const result = await OTPService.generateAndSend(
            identity.userId,
            challengeContact.contact,
            'ACCOUNT_ACTIVATION',
            challengeContact.type,
            'ORBI Account Activation',
        );

        if (!result.deliverySent) {
            return {
                success: false,
                confirmationRequired: true,
                error: 'OTP_DELIVERY_FAILED: ORBI could not deliver the activation code by SMS/email. Check ORBI Talk Gateway configuration and delivery logs.',
                requestId: result.requestId,
                deliveryType: result.deliveryType,
                deliveryContact: this.maskContact(result.deliveryContact || challengeContact.contact),
            };
        }

        return {
            success: true,
            confirmationRequired: true,
            requestId: result.requestId,
            deliveryType: result.deliveryType,
            deliveryContact: this.maskContact(result.deliveryContact || challengeContact.contact),
            expiresInSeconds: 300,
        };
    }

    async cleanupExpiredUnconfirmedAccounts() {
        const sb = getAdminSupabase();
        if (!sb) return { terminated: 0 };

        const now = new Date().toISOString();
        let terminated = 0;

        for (const table of ['users', 'staff'] as const) {
            const { data } = await sb
                .from(table)
                .select('id, account_status, created_at, activation_expires_at')
                .in('account_status', ['pending_confirmation', 'unconfirmed', 'inactive'])
                .not('activation_expires_at', 'is', null)
                .lt('activation_expires_at', now);

            for (const row of data || []) {
                const { error } = await sb.auth.admin.deleteUser(row.id);
                if (!error) {
                    terminated += 1;
                    await this.security.logActivity(row.id, 'UNCONFIRMED_ACCOUNT_TERMINATED', 'success', `Expired ${table} identity removed after activation window`);
                }
            }
        }

        return { terminated };
    }

    private async resolveNodeStatus(
        userId: string,
        registryType: 'STAFF' | 'CONSUMER' | 'MERCHANT' | 'AGENT' = 'STAFF',
    ): Promise<{ status: string, kyc_level: number, kyc_status: string, id_type?: string, id_number?: string }> {
        const sb = getAdminSupabase();
        
        // 1. Supabase Check
        if (sb) {
            try {
                const table = registryType === 'STAFF' ? 'staff' : 'users';
                const selectColumns = registryType === 'STAFF'
                    ? 'account_status'
                    : 'account_status, kyc_level, kyc_status, id_type, id_number';
                const { data, error } = await sb.from(table)
                    .select(selectColumns)
                    .eq('id', userId)
                    .maybeSingle() as any;
                
                if (error || !data) return { status: 'pending', kyc_level: 0, kyc_status: 'unverified' };
                
                return {
                    status: data.account_status || 'pending',
                    kyc_level: data.kyc_level || 0,
                    kyc_status: data.kyc_status || 'unverified',
                    id_type: data.id_type,
                    id_number: data.id_number
                };
            } catch (e) {
                return { status: 'pending', kyc_level: 0, kyc_status: 'error' };
            }
        }

        // 2. Local Fallback
        const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        const user = users.find(u => u.id === userId);
        if (user) {
            return {
                status: user.account_status || 'active',
                kyc_level: user.kyc_level || 0,
                kyc_status: user.kyc_status || 'unverified',
                id_type: user.id_type,
                id_number: user.id_number
            };
        }

        return { status: 'active', kyc_level: 1, kyc_status: 'pending' };
    }

    public async mapSession(sbSession: any): Promise<Session> {
        // Handle both full session object (from login) and user-only object (from getUser)
        const user = sbSession.user || sbSession;
        const meta = user.user_metadata || {};
        const AUTHORIZED_ORIGIN =
            process.env.ORBI_WEB_ORIGIN ||
            process.env.ORBI_INSTITUTIONAL_APP_ORIGIN ||
            process.env.ORBI_CORE_APP_ORIGIN ||
            DEFAULT_INSTITUTIONAL_APP_ORIGIN;
        
        // HARDENING: Cluster Origin Enforcement
        const origin = meta.app_origin;
        const ALLOWED_ORIGINS = Array.from(new Set([AUTHORIZED_ORIGIN, ...TRUSTED_INSTITUTIONAL_APP_ORIGINS, ...TRUSTED_MOBILE_APP_ORIGINS]));
        
        if (origin && !ALLOWED_ORIGINS.includes(origin)) {
            throw new Error(`ACCESS_DENIED: Identity node originates from unauthorized cluster [${origin}].`);
        }

        const registryType = meta.registry_type || 'STAFF';
        const nodeState = await this.resolveNodeStatus(user.id, registryType);
        const liveStatus = nodeState.status;

        // HARDENING: Immediate Quarantine Check
        if (liveStatus === 'frozen' || liveStatus === 'blocked') {
            Storage.removeItem(STORAGE_KEYS.USER_SESSION);
            throw new Error(`IDENTITY_LOCKED: Your Account has been temporary ${liveStatus.toUpperCase()} by the System security, please contact us if the issue persist more than 24HRS`);
        }

        const session: Session = {
            user: {
                id: user.id,
                email: user.email,
                full_name: meta.full_name || 'Customer',
                phone: meta.phone,
                customer_id: meta.customer_id,
                role: (meta.role as UserRole) || 'USER',
                account_status: liveStatus,
                kyc_level: nodeState.kyc_level,
                kyc_status: nodeState.kyc_status,
                id_type: nodeState.id_type,
                id_number: nodeState.id_number,
                registry_type: registryType,
                app_origin: origin
            },
            access_token: sbSession.access_token || '',
            refresh_token: sbSession.refresh_token || '',
            expires_at: sbSession.expires_at || 0,
            token_type: 'Bearer',
            sub: user.id,
            iss: 'orbi-auth-v25',
            exp: sbSession.expires_at || Math.floor(Date.now() / 1000) + 3600,
            role: (meta.role as UserRole) || 'USER',
            permissions: [] // Default to empty, will be resolved by RBAC if needed
        };

        Storage.setItem(STORAGE_KEYS.USER_SESSION, JSON.stringify(session));
        
        return session;
    }
    
    async getSession(token?: string): Promise<Session | null> {
        const sb = getSupabase();
        const adminSb = getAdminSupabase();
        
        // 1. Validate provided token against Supabase Auth
        if (sb && token) {
            const { data: { user }, error } = await sb.auth.getUser(token);
            
            if (user && !error) {
                try {
                    // Construct a session object since getUser only returns the user
                    const sessionData = {
                        access_token: token,
                        token_type: 'Bearer',
                        user: user,
                        expires_at: Math.floor(Date.now() / 1000) + 3600 // Assume valid for 1h if getUser succeeds
                    };
                    return await this.mapSession(sessionData);
                } catch (e: any) {
                    console.error("[AuthService] Session mapping failed:", e);
                    return null;
                }
            }
        }

        // 1b. Validate internally signed access tokens
        if (token) {
            type InternalAccessPayload = {
                sub: string;
                device?: string;
                exp?: number;
                jti?: string;
                type?: string;
            };

            const payload = await JWTNode.verify<InternalAccessPayload>(token);
            if (payload?.sub && (!payload.type || payload.type === 'access') && adminSb) {
                try {
                    const { data: userData } = await adminSb.auth.admin.getUserById(payload.sub);
                    const authUser = userData?.user;
                    if (authUser) {
                        const sessionData = {
                            access_token: token,
                            token_type: 'Bearer',
                            user: authUser,
                            expires_at: payload.exp || Math.floor(Date.now() / 1000) + 900,
                        };
                        return await this.mapSession(sessionData);
                    }
                } catch (e: any) {
                    console.error("[AuthService] Internal JWT session resolution failed:", e);
                    return null;
                }
            }
        }

        // 2. Fallback to local storage (Legacy/Testing only)
        if (this.allowLocalSessionFallback) {
            const local = Storage.getItem(STORAGE_KEYS.USER_SESSION);
            if (local) {
                try {
                    const s = JSON.parse(local) as Session;
                    if (s.exp > Date.now() / 1000) return s;
                } catch (e) { Storage.removeItem(STORAGE_KEYS.USER_SESSION); }
            }
        }
        return null;
    }

    private async registerOrValidateDevice(userId: string, fingerprint: string, userAgent?: string): Promise<'trusted' | 'untrusted' | 'blocked' | 'new'> {
        const sb = getSupabase();
        if (!sb) return 'new';

        // 1. Enforce Device Limit (Max 2 Accounts per Device)
        const { count, error } = await sb.from('user_devices')
            .select('user_id', { count: 'exact', head: true })
            .eq('device_fingerprint', fingerprint)
            .neq('user_id', userId); // Count OTHER users on this device

        if (count !== null && count >= 2) {
            throw new Error('DEVICE_LIMIT_EXCEEDED: This device is already linked to the maximum number of accounts (2).');
        }

        const { data: device } = await sb.from('user_devices')
            .select('*')
            .eq('user_id', userId)
            .eq('device_fingerprint', fingerprint)
            .maybeSingle();

        if (device) {
            if (device.status === 'blocked') return 'blocked';
            
            // Update last active
            await sb.from('user_devices').update({ 
                last_active_at: new Date().toISOString(),
                user_agent: userAgent || device.user_agent 
            }).eq('id', device.id);

            return device.is_trusted ? 'trusted' : 'untrusted';
        } else {
            // Register new device
            await sb.from('user_devices').insert({
                user_id: userId,
                device_fingerprint: fingerprint,
                user_agent: userAgent,
                device_type: 'unknown', // Could parse UA
                is_trusted: false,
                status: 'active'
            });
            return 'new';
        }
    }

    async login(e: string, p: string, metadata?: { fingerprint?: string, ip?: string, userAgent?: string }) { 
        const sb = getSupabase();
        if (!sb) return { error: { message: "ORBI Cluster Offline" } };
        await this.cleanupExpiredUnconfirmedAccounts();
        
        // Lookup user ID for brute force protection
        let userId = null;
        const { data: user } = await sb
            .from('users')
            .select('id')
            .or(buildPostgrestOrFilter([
                { column: 'email', operator: 'eq', value: e },
                { column: 'phone', operator: 'eq', value: e },
            ]))
            .maybeSingle();
        if (user) userId = user.id;

        if (userId) {
            const { locked, reason, retryAfter } = await this.bruteForce.isLocked(userId);
            if (locked) {
                return { error: { message: `ACCOUNT_LOCKED: ${reason}. Please try again in ${Math.ceil(retryAfter! / 1000)} seconds.` } };
            }
        }
        
        let res;
        if (e && typeof e === 'string' && e.includes('@')) {
            res = await sb.auth.signInWithPassword({ email: e, password: p });
        } else {
            // Assume phone
            let formattedPhone = e;
            if (!formattedPhone.startsWith('+')) {
                formattedPhone = '+' + formattedPhone;
            }
            res = await sb.auth.signInWithPassword({ phone: formattedPhone, password: p });
        }
        if (res.data?.session) {
            try {
                // Clear brute force attempts on success
                if (userId) {
                    await this.bruteForce.clearAttempts(userId);
                }

                const mapped = await this.mapSession(res.data.session);

                if (!this.isActiveStatus(mapped.user.account_status)) {
                    await sb.auth.signOut().catch(() => {});
                    return {
                        error: {
                            message: 'ACCOUNT_NOT_ACTIVATED: Confirm your email or phone OTP before accessing ORBI services.',
                            code: 'ACCOUNT_NOT_ACTIVATED',
                            account_status: mapped.user.account_status,
                        },
                    };
                }
                
                // Banking Security: Anomaly Detection & Session Tracking
                if (metadata?.fingerprint && metadata?.ip) {
                    // 1. Device Binding Check
                    const deviceStatus = await this.registerOrValidateDevice(mapped.user.id, metadata.fingerprint, metadata.userAgent);
                    
                    if (deviceStatus === 'blocked') {
                        throw new Error('DEVICE_BLOCKED: This device is explicitly blocked from accessing your account.');
                    }

                    // 2. Single Active Device Policy (Logout previous sessions)
                    if (deviceStatus === 'new' || deviceStatus === 'untrusted') {
                        // Revoke all other sessions for this user to enforce single active device
                        await sb.from('user_sessions')
                            .update({ is_revoked: true })
                            .eq('user_id', mapped.user.id)
                            .neq('device_fingerprint', metadata.fingerprint); // Keep current device if it had a session (though unlikely for 'new')
                        
                        console.log(`[Auth] Enforced Single Device Policy for user ${mapped.user.id}`);
                    }

                    const isAnomalous = await this.detectLoginAnomaly(mapped.user.id, metadata.fingerprint, metadata.ip);
                    
                    if (isAnomalous || deviceStatus === 'new') {
                        console.warn(`[Auth] Login anomaly detected for user ${mapped.user.id}`);
                        
                        const language = mapped.user.user_metadata?.language || 'en';
                        const subject = language === 'sw' ? 'Kifaa Kipya Kimegunduliwa' : 'New Device Detected';
                        const body = language === 'sw' 
                            ? `Kuingia kutoka kifaa kipya (IP: ${metadata.ip}). Kama huyu hakuwa wewe, funga akaunti yako mara moja.` 
                            : `Login from new device (IP: ${metadata.ip}). If this wasn't you, freeze your account immediately.`;

                        // NOTIFICATION: Security Alert via Push
                        await Messaging.dispatch(
                            mapped.user.id,
                            'security',
                            subject,
                            body,
                            { sms: true }
                        );

                        await this.security.logActivity(mapped.user.id, 'login', 'warning', `New device detected: ${metadata.fingerprint}`, undefined, metadata.fingerprint);
                    } else {
                        // STANDARD LOGIN: No user notification (to reduce noise), just audit log
                        console.log(`[Auth] Standard login processed for user ${mapped.user.id} (No Notification Sent)`);
                        // Parse User Agent for cleaner log
                        let deviceName = 'Unknown Device';
                        if (metadata.userAgent) {
                            if (metadata.userAgent.includes('Android')) deviceName = 'Android Device';
                            else if (metadata.userAgent.includes('iPhone')) deviceName = 'iPhone';
                            else if (metadata.userAgent.includes('iPad')) deviceName = 'iPad';
                            else if (metadata.userAgent.includes('Windows')) deviceName = 'Windows PC';
                            else if (metadata.userAgent.includes('Macintosh')) deviceName = 'Mac';
                            else if (metadata.userAgent.includes('Linux')) deviceName = 'Linux Device';
                            else deviceName = 'Web Browser';
                        }
                        
                        await this.security.logActivity(mapped.user.id, 'login', 'success', `Login via ${deviceName}`, undefined, metadata.fingerprint);
                    }

                    // Update User Last Active Timestamp (Critical for "Last Seen")
                    await sb.from('users').update({ 
                        last_active: new Date().toISOString() 
                    }).eq('id', mapped.user.id);

                    // PROVISIONING: Ensure user has default infrastructure
                    await ProvisioningService.provisionUser(mapped.user.id, mapped.user.user_metadata?.full_name || 'Customer');

                    // Store Session
                    const tokenHash = this.hashToken(res.data.session.refresh_token);
                    await sb.from('user_sessions').insert({
                        user_id: mapped.user.id,
                        refresh_token_hash: tokenHash,
                        device_fingerprint: metadata.fingerprint,
                        ip_address: metadata.ip,
                        user_agent: metadata.userAgent,
                        expires_at: new Date((res.data.session.expires_at || Date.now() / 1000 + 3600) * 1000).toISOString()
                    });
                } else {
                    // Log generic login if no metadata
                    await this.security.logActivity(mapped.user.id, 'login', 'success', 'Login without device metadata');
                }

                // Check if 2FA is required
                if (mapped.user.user_metadata?.two_factor_enabled) {
                    return { 
                        two_factor_required: true, 
                        userId: mapped.user.id, 
                        phone: mapped.user.user_metadata?.phone,
                        temp_session: mapped 
                    };
                }

                // MANDATORY BIOMETRIC CHECK
                // If user has no authenticators, force setup
                const authenticators = mapped.user.user_metadata?.authenticators || [];
                const biometricRequired = authenticators.length === 0;

                return { 
                    user: mapped.user, 
                    session: mapped,
                    access_token: mapped.access_token,
                    biometric_setup_required: biometricRequired // Flag for frontend to trigger registration
                };
            } catch (err: any) {
                if (userId) {
                    await this.bruteForce.recordFailedAttempt(userId);
                }
                return { error: { message: err.message } };
            }
        }
        const authErrorMessage = String(res.error?.message || '');
        if (/email\s+not\s+confirmed|not\s+confirmed|confirm/i.test(authErrorMessage)) {
            const identity = await this.resolveIdentityForChallenge(e).catch(() => null);
            return {
                error: {
                    message: 'ACCOUNT_NOT_ACTIVATED: Confirm your email or phone OTP before accessing ORBI services.',
                    code: 'ACCOUNT_NOT_ACTIVATED',
                    account_status: identity?.status || 'pending_confirmation',
                },
            };
        }
        return { error: res.error };
    }

    async refreshSession(refreshToken: string, metadata?: { fingerprint?: string, ip?: string }) {
        const sb = getSupabase();
        if (!sb) return { error: { message: "DB_OFFLINE" } };

        const tokenHash = this.hashToken(refreshToken);

        // 1. Verify Token in DB
        const { data: sessionRecord } = await sb.from('user_sessions')
            .select('*')
            .eq('refresh_token_hash', tokenHash)
            .maybeSingle();

        if (!sessionRecord) {
            // Token not found - could be forged or very old
            return { error: { message: "INVALID_REFRESH_TOKEN" } };
        }

        // 2. Reuse Detection
        if (sessionRecord.replaced_by) {
            // CRITICAL: Token reuse detected! Revoke everything.
            await this.revokeSessionChain(sessionRecord.user_id, tokenHash);
            
            const { data: user } = await sb.from('users').select('language').eq('id', sessionRecord.user_id).maybeSingle();
            const language = user?.language || 'en';
            const subject = language === 'sw' ? 'MUHIMU: Udukuzi wa Kipindi Umezuiwa' : 'CRITICAL: Session Hijack Blocked';
            const body = language === 'sw' 
                ? 'Matumizi ya kipindi maradufu yamegunduliwa. Vifaa vyote vimetolewa kwa usalama wako.' 
                : 'Duplicate session usage detected. All devices have been logged out for your safety.';

            // NOTIFICATION: Critical Security Alert via Push
            await Messaging.dispatch(
                sessionRecord.user_id,
                'security',
                subject,
                body,
                { sms: true }
            );
            await this.security.logActivity(sessionRecord.user_id, 'security_update', 'blocked', 'Token reuse detected - Session Chain Revoked', undefined, metadata?.fingerprint);

            return { error: { message: "SECURITY_ALERT: Token reuse detected. All sessions revoked." } };
        }

        // 3. Revocation Check
        if (sessionRecord.is_revoked) {
            return { error: { message: "SESSION_REVOKED" } };
        }

        // 4. Device Verification
        if (metadata?.fingerprint && sessionRecord.device_fingerprint !== metadata.fingerprint) {
            // Fingerprint mismatch - potential theft
            await this.revokeSessionChain(sessionRecord.user_id, tokenHash);
            
            const { data: user } = await sb.from('users').select('language').eq('id', sessionRecord.user_id).maybeSingle();
            const language = user?.language || 'en';
            const subject = language === 'sw' ? 'Kipindi Kimekatishwa' : 'Session Terminated';
            const body = language === 'sw' 
                ? 'Tofauti ya alama ya kidole ya kifaa imegunduliwa. Tafadhali ingia tena.' 
                : 'Device fingerprint mismatch detected. Please login again.';

            await Messaging.dispatch(
                sessionRecord.user_id,
                'security',
                subject,
                body,
                { sms: true }
            );
            await this.security.logActivity(sessionRecord.user_id, 'security_update', 'failed', 'Device fingerprint mismatch', undefined, metadata?.fingerprint);

            return { error: { message: "DEVICE_MISMATCH: Session terminated." } };
        }

        // 5. Perform Refresh via Supabase
        const { data, error } = await sb.auth.refreshSession({ refresh_token: refreshToken });
        
        if (error || !data.session) {
            return { error: error || { message: "Refresh failed" } };
        }

        // 6. Rotation: Invalidate old, store new
        const newTokenHash = this.hashToken(data.session.refresh_token);
        
        // Mark old as replaced
        await sb.from('user_sessions')
            .update({ replaced_by: newTokenHash })
            .eq('id', sessionRecord.id);

        // Create new session record
        await sb.from('user_sessions').insert({
            user_id: sessionRecord.user_id,
            refresh_token_hash: newTokenHash,
            device_fingerprint: sessionRecord.device_fingerprint,
            ip_address: metadata?.ip || sessionRecord.ip_address,
            user_agent: sessionRecord.user_agent,
            expires_at: new Date((data.session.expires_at || Date.now() / 1000 + 3600) * 1000).toISOString()
        });

        const mapped = await this.mapSession(data.session);

        // Update User Last Active Timestamp
        await sb.from('users').update({ 
            last_active: new Date().toISOString() 
        }).eq('id', mapped.user.id);

        return { session: mapped };
    }

    async logout(token?: string, refreshToken?: string) {
        const sb = getSupabase();
        const adminSb = getAdminSupabase();

        if (refreshToken && sb) {
            const tokenHash = this.hashToken(refreshToken);
            await sb.from('user_sessions')
                .update({ is_revoked: true })
                .eq('refresh_token_hash', tokenHash);
        }

        let resolvedUserId: string | null = null;
        let resolvedEmail: string | null = null;

        if (token && sb) {
            const { data: { user } } = await sb.auth.getUser(token);
            if (user) {
                resolvedUserId = user.id;
                resolvedEmail = user.email || null;
            }
        }

        if (!resolvedUserId && token) {
            const payload = await JWTNode.verify<{ sub?: string; jti?: string; type?: string }>(token);
            if (payload?.jti) {
                await JWTNode.revoke(payload.jti);
            }
            if (payload?.sub) {
                resolvedUserId = payload.sub;
                if (adminSb) {
                    const { data } = await adminSb.auth.admin.getUserById(payload.sub);
                    resolvedEmail = data?.user?.email || null;
                }
            }
        }

        if (resolvedUserId && sb) {
            await sb.from('user_sessions')
                .update({ is_revoked: true })
                .eq('user_id', resolvedUserId);
        }

        if (resolvedUserId) {
            await Audit.log('IDENTITY', resolvedUserId, 'LOGOUT', { email: resolvedEmail });
            if (adminSb) {
                await adminSb.auth.admin.signOut(resolvedUserId).catch(() => {});
            }
        }

        Storage.removeItem(STORAGE_KEYS.USER_SESSION);
    }

    async registerBiometric(userId: string, credential: any) {
        const sb = getSupabase();
        if (sb) {
            const { data, error } = await sb.auth.updateUser({
                data: { 
                    biometric_credential: credential,
                    security_biometric_enabled: true 
                }
            });
            return { data, error };
        }
        
        // Local fallback
        let users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        const idx = users.findIndex(u => u.id === userId);
        if (idx >= 0) {
            users[idx].biometric_credential = credential;
            users[idx].security_biometric_enabled = true;
            Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
            return { success: true };
        }
        return { error: "User not found" };
    }

    async signUp(e: string, p: string, m?: any) {
        const sb = getSupabase();
        if (sb) {
            try {
                await this.cleanupExpiredUnconfirmedAccounts();
                const normalizedCurrency = typeof m?.currency === 'string'
                    ? m.currency.trim().toUpperCase()
                    : '';
                if (!normalizedCurrency) {
                    return { data: null, error: { message: "CURRENCY_REQUIRED: Account currency is mandatory at signup." } };
                }

                // Generate customer_id if not provided
                const customerId = m?.customer_id || IdentityGenerator.generateCustomerID();
                
                // HARDENING: Role & Registry Enforcement based on Origin
                let role: UserRole = 'USER';
                let registryType: 'STAFF' | 'CONSUMER' | 'MERCHANT' | 'AGENT' = 'CONSUMER';
                const origin = m?.app_origin;
                const requestedRole = (m?.role as UserRole) || 'USER';
                const staffRoles: UserRole[] = [
                    'SUPER_ADMIN',
                    'ADMIN',
                    'IT',
                    'AUDIT',
                    'ACCOUNTANT',
                    'CUSTOMER_CARE',
                    'HUMAN_RESOURCE',
                ];

                if (TRUSTED_MOBILE_APP_ORIGINS.includes(origin)) {
                    // Mobile app signups start as ordinary public users.
                    // Merchant/agent access is granted later through ORBI review.
                    role = 'USER';
                    registryType = 'CONSUMER';
                } else if (TRUSTED_INSTITUTIONAL_APP_ORIGINS.includes(origin)) {
                    role = requestedRole;
                    if (staffRoles.includes(requestedRole)) {
                        registryType = 'STAFF';
                    } else if (requestedRole === 'MERCHANT') {
                        registryType = 'MERCHANT';
                    } else if (requestedRole === 'AGENT') {
                        registryType = 'AGENT';
                    } else {
                        registryType = 'CONSUMER';
                    }
                } else {
                    // Default fallback for unknown origins
                    role = 'USER';
                    registryType = 'CONSUMER';
                }

                // Format phone number
                let formattedPhone = m?.phone;
                if (formattedPhone) {
                    try {
                        const phoneNumber = parsePhoneNumber(formattedPhone, 'TZ');
                        if (phoneNumber.isValid()) {
                            formattedPhone = phoneNumber.format('E.164');
                        } else {
                            throw new Error('Invalid phone number format');
                        }
                    } catch (err) {
                        return { data: null, error: { message: "Invalid phone number provided." } };
                    }
                }

                const signupIdentifiers = [
                    ...(e && typeof e === 'string' && e.trim() ? [e.trim()] : []),
                    ...(formattedPhone ? [formattedPhone] : []),
                ];
                for (const identifier of signupIdentifiers) {
                    const existingIdentity = await this.resolveIdentityForChallenge(identifier);
                    if (!existingIdentity) continue;
                    if (this.isActiveStatus(existingIdentity.status)) {
                        return { data: null, error: { message: "ACCOUNT_ALREADY_EXISTS: This email or phone is already linked to an active ORBI account." } };
                    }
                    if (!this.isConfirmationPendingStatus(existingIdentity.status)) {
                        return { data: null, error: { message: `ACCOUNT_NOT_CONFIRMABLE: Current status is ${existingIdentity.status || 'unknown'}.` } };
                    }

                    const activationChallenge = await this.issueAccountActivationChallenge(
                        existingIdentity,
                        identifier,
                    );
                    await this.security.logActivity(existingIdentity.userId, 'ACCOUNT_ACTIVATION_RESENT_FOR_EXISTING_PENDING_IDENTITY', 'success', 'Duplicate signup detected and routed to activation');
                    return {
                        data: {
                            user: {
                                id: existingIdentity.userId,
                                email: existingIdentity.email,
                                phone: existingIdentity.phone,
                                full_name: existingIdentity.fullName,
                                registry_type: existingIdentity.registryType,
                                account_status: existingIdentity.status,
                                existingPendingActivation: true,
                                activation: activationChallenge,
                            },
                            session: null,
                            existingPendingActivation: true,
                            activation: activationChallenge,
                        },
                        error: null,
                    };
                }

                // Enforce single phone number across all identities
                if (formattedPhone) {
                    const adminSb = getAdminSupabase();
                    const checkClient = adminSb || sb;
                    if (checkClient) {
                        const { data: userMatch, error: userMatchError } = await checkClient
                            .from('users')
                            .select('id')
                            .eq('phone', formattedPhone)
                            .maybeSingle();
                        if (userMatchError) {
                            console.warn('[AuthService] Phone uniqueness check failed (users):', userMatchError.message);
                        }
                        if (userMatch) {
                            return { data: null, error: { message: "PHONE_ALREADY_IN_USE: This phone number is already linked to another account." } };
                        }

                        const { data: staffMatch, error: staffMatchError } = await checkClient
                            .from('staff')
                            .select('id')
                            .eq('phone', formattedPhone)
                            .maybeSingle();
                        if (staffMatchError) {
                            console.warn('[AuthService] Phone uniqueness check failed (staff):', staffMatchError.message);
                        }
                        if (staffMatch) {
                            return { data: null, error: { message: "PHONE_ALREADY_IN_USE: This phone number is already linked to another account." } };
                        }
                    }
                }

                const nationality = m?.nationality || 'Tanzania';
                const language = m?.language || (nationality === 'Tanzania' ? 'sw' : 'en');

                const activationExpiresAt = new Date(Date.now() + this.activationTtlMs).toISOString();
                const accountStatus = 'pending_confirmation';
                const metadata = { 
                    ...m, 
                    phone: formattedPhone, 
                    customer_id: customerId, 
                    currency: normalizedCurrency,
                    language: language,
                    account_status: accountStatus,
                    auth_confirmed_at: null,
                    activation_expires_at: activationExpiresAt,
                    role,
                    registry_type: registryType
                };

                const signUpPayload: any = { password: p, options: { data: metadata } };
                if (e && typeof e === 'string' && e.includes('@')) {
                    signUpPayload.email = e;
                } else if (formattedPhone) {
                    signUpPayload.phone = formattedPhone;
                } else {
                    return { data: null, error: { message: "Either email or phone is required for registration." } };
                }

                console.info(`[AuthService] Attempting signUp for ${e || formattedPhone}...`);
                const res = await sb.auth.signUp(signUpPayload);

                if (res.error) {
                    console.error("[AuthService] Supabase signUp error:", res.error);
                    return { data: null, error: res.error };
                }

                if (res.data?.user) {
                    console.info(`[AuthService] User created: ${res.data.user.id}. Populating profile...`);
                    const adminSb = getAdminSupabase();
                    let targetClient = adminSb;

                    if (!adminSb) {
                        console.warn("[AuthService] Admin client not available. Falling back to authenticated client.");
                        if (res.data.session) {
                            targetClient = createAuthenticatedClient(res.data.session.access_token);
                        }
                        if (!targetClient) {
                            targetClient = sb;
                        }
                    }
                    
                    const targetTable = registryType === 'STAFF' ? 'staff' : 'users';
                    
                    const profileData: any = {
                        id: res.data.user.id,
                        full_name: m?.full_name || 'New User',
                        email: (e && typeof e === 'string' && e.includes('@')) ? e : null,
                        customer_id: customerId,
                        phone: formattedPhone,
                        nationality: nationality,
                        currency: normalizedCurrency,
                        language: language,
                        account_status: accountStatus,
                        auth_confirmed_at: null,
                        activation_expires_at: activationExpiresAt,
                        registry_type: registryType,
                        app_origin: origin
                    };

                    if (registryType === 'STAFF' || targetTable === 'users') {
                        profileData.role = role;
                    }
                    
                    if (targetTable === 'users') {
                        profileData.address = m?.address;
                    }

                    const { error: profileError } = await targetClient!.from(targetTable).upsert(profileData, { onConflict: 'id' });

                    if (profileError) {
                        console.error("[AuthService] Profile creation failed:", profileError);
                        if (adminSb) {
                            console.info(`[AuthService] Rolling back auth user ${res.data.user.id}...`);
                            await adminSb.auth.admin.deleteUser(res.data.user.id);
                        }
                        return { data: null, error: profileError };
                    }

                    const activationContact = this.preferredChallengeContact(
                        { email: profileData.email, phone: formattedPhone },
                        e || formattedPhone,
                    );
                    let activationChallenge: any = null;
                    if (activationContact) {
                        activationChallenge = await OTPService.generateAndSend(
                            res.data.user.id,
                            activationContact.contact,
                            'ACCOUNT_ACTIVATION',
                            activationContact.type,
                            'ORBI Account Activation',
                        );
                    }

                    await this.security.logActivity(res.data.user.id, 'ACCOUNT_CREATED_PENDING_CONFIRMATION', 'success', `Created ${registryType.toLowerCase()} identity pending OTP activation`);
                    (res.data.user as any).activation = {
                        required: true,
                        expires_at: activationExpiresAt,
                        requestId: activationChallenge?.requestId,
                        deliveryType: activationChallenge?.deliveryType,
                        deliveryContact: this.maskContact(activationChallenge?.deliveryContact || activationContact?.contact),
                    };
                }

                if (res.data?.session) {
                    return { data: { user: res.data.user, session: await this.mapSession(res.data.session) }, error: null };
                }
                return { data: { user: res.data?.user, session: null }, error: res.error };
            } catch (err: any) {
                console.error("[AuthService] Registration protocol interrupted:", err);
                const errorMessage = err instanceof Error ? err.message : (typeof err === 'string' ? err : (err?.message || JSON.stringify(err) || "Registration protocol interrupted."));
                return { data: null, error: { message: errorMessage } };
            }
        }
        return { error: { message: "Cloud Node Offline" } };
    }

    async initiateAccountConfirmation(identifier: string, replacementContact?: string) {
        await this.cleanupExpiredUnconfirmedAccounts();
        const identity = await this.resolveIdentityForChallenge(identifier);
        if (!identity) return { success: true, confirmationRequired: true };
        if (this.isActiveStatus(identity.status)) {
            return { success: true, confirmationRequired: false, status: 'active' };
        }
        if (!this.isConfirmationPendingStatus(identity.status)) {
            return { success: false, error: `ACCOUNT_NOT_CONFIRMABLE: Current status is ${identity.status || 'unknown'}.` };
        }

        return this.issueAccountActivationChallenge(identity, identifier, replacementContact);
    }

    async confirmAccount(identifier: string, requestId: string, code: string) {
        await this.cleanupExpiredUnconfirmedAccounts();
        const identity = await this.resolveIdentityForChallenge(identifier);
        if (!identity) return { success: false, error: 'IDENTITY_NOT_FOUND' };
        if (this.isActiveStatus(identity.status)) return { success: true, status: 'active', alreadyActive: true };
        if (!this.isConfirmationPendingStatus(identity.status)) {
            return { success: false, error: `ACCOUNT_NOT_CONFIRMABLE: Current status is ${identity.status || 'unknown'}.` };
        }

        const valid = await OTPService.verify(requestId, code, identity.userId);
        if (!valid) return { success: false, error: 'INVALID_OTP' };

        const sb = getAdminSupabase();
        if (!sb) return { success: false, error: 'DB_OFFLINE' };

        const activatedAt = new Date().toISOString();
        await sb.from(identity.table).update({
            account_status: 'active',
            auth_confirmed_at: activatedAt,
            activation_method: identity.phone ? 'sms_email_otp' : 'email_otp',
            activation_expires_at: null,
        }).eq('id', identity.userId);

        const { data: authData } = await sb.auth.admin.getUserById(identity.userId);
        await sb.auth.admin.updateUserById(identity.userId, {
            email_confirm: Boolean(authData.user?.email || identity.email),
            phone_confirm: Boolean(authData.user?.phone || identity.phone),
            user_metadata: {
                ...(authData.user?.user_metadata || {}),
                account_status: 'active',
                auth_confirmed_at: activatedAt,
                activation_method: identity.phone ? 'sms_email_otp' : 'email_otp',
            },
        });

        const provisionResult = await ProvisioningService.provisionUser(
            identity.userId,
            identity.fullName || 'Customer',
            identity.customerId || undefined,
        );
        if (provisionResult.status === 'failed') {
            console.error(`[AuthService] Activation provisioning failed for user ${identity.userId}:`, provisionResult.error);
        }

        const walletService = new WalletService();
        const wallets = await walletService.fetchForUser(identity.userId);
        await Messaging.sendWelcomeMessage({
            id: identity.userId,
            email: identity.email,
            phone: identity.phone,
            user_metadata: {
                full_name: identity.fullName,
                language: identity.language,
                registry_type: identity.registryType,
            },
        }, wallets);

        await this.security.logActivity(identity.userId, 'ACCOUNT_ACTIVATED', 'success', 'Identity confirmed by OTP and activated');
        return { success: true, status: 'active', provisioned: provisionResult.status !== 'failed' };
    }

    async generateSessionForUser(userId: string): Promise<Session | null> {
        const sb = getSupabase();
        let user: any;

        if (sb) {
            const { data, error } = await sb.auth.admin.getUserById(userId);
            if (error || !data.user) return null;
            user = data.user;
        } else {
            const users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
            user = users.find(u => u.id === userId);
        }

        if (!user) return null;

        // Generate Session
        const session: Session = {
            access_token: 'local-jwt-' + UUID.generate(),
            token_type: 'Bearer',
            user: {
                id: user.id,
                email: user.email,
                user_metadata: { 
                    ...user.user_metadata, 
                    app_origin: user.user_metadata?.app_origin || DEFAULT_INSTITUTIONAL_APP_ORIGIN 
                },
                role: (user.user_metadata?.role || 'USER') as UserRole
            },
            sub: user.id,
            iss: 'orbi.auth',
            exp: Date.now() / 1000 + (24 * 60 * 60), // 24h
            expires_at: Date.now() / 1000 + (24 * 60 * 60),
            role: (user.user_metadata?.role || 'USER') as UserRole,
            permissions: this.getPermissionsForRole((user.user_metadata?.role || 'USER') as UserRole, 'active')
        };

        // Store locally (Single session mode for this architecture)
        Storage.setItem(STORAGE_KEYS.USER_SESSION, JSON.stringify(session));
        
        return session;
    }

    async initiatePhoneLogin(phone: string) { 
        let formattedPhone = phone;
        try {
            const phoneNumber = parsePhoneNumber(phone, 'TZ');
            if (phoneNumber && phoneNumber.isValid()) {
                formattedPhone = phoneNumber.format('E.164');
            } else {
                formattedPhone = phone.startsWith('+') ? phone : '+' + phone.replace(/\s/g, '');
            }
        } catch (e) {
            formattedPhone = phone.startsWith('+') ? phone : '+' + phone.replace(/\s/g, '');
        }

        // Production: Trigger Push/Log challenge
        const { requestId, deliveryType, deliveryContact } = await OTPService.generateAndSend('system', formattedPhone, 'PHONE_LOGIN');
        return { success: true, requestId, deliveryType, deliveryContact }; 
    }

    async verifyPhoneLogin(phone: string, token: string, requestId?: string) { 
        let formattedPhone = phone;
        try {
            const phoneNumber = parsePhoneNumber(phone, 'TZ');
            if (phoneNumber && phoneNumber.isValid()) {
                formattedPhone = phoneNumber.format('E.164');
            } else {
                formattedPhone = phone.startsWith('+') ? phone : '+' + phone.replace(/\s/g, '');
            }
        } catch (e) {
            formattedPhone = phone.startsWith('+') ? phone : '+' + phone.replace(/\s/g, '');
        }

        const isProduction = process.env.NODE_ENV === 'production';
        
        if (isProduction && !requestId) {
             return { success: false, error: 'SECURITY_VIOLATION: Direct OTP injection not permitted in production.' };
        }

        if (requestId) {
            const isValid = await OTPService.verify(requestId, token, 'system');
            if (!isValid) return { success: false, error: 'IDENTITY_CHALLENGE_FAILED: Incorrect verification code.' };
        } else if (token !== '123456') {
             return { success: false, error: 'IDENTITY_CHALLENGE_FAILED: Incorrect verification code.' };
        }

        let users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        let user = users.find(u => u.phone === formattedPhone);
        
        if (user?.account_status === 'blocked' || user?.account_status === 'frozen') {
            return { success: false, error: 'IDENTITY_LOCKED' };
        }

        let isNewUser = false;
        if (!user) {
            isNewUser = true;
            user = {
                id: UUID.generate(), phone: formattedPhone, 
                role: 'USER' as UserRole, created_at: new Date().toISOString(),
                customer_id: IdentityGenerator.generateCustomerID(users.length + 1),
                account_status: 'active',
                language: 'sw' // Default to sw for phone login (Tanzania)
            };
            users.push(user);
            Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
        }

        const session: Session = {
            access_token: 'local-jwt-' + UUID.generate(),
            token_type: 'Bearer',
            user: {
                id: user.id,
                email: user.email,
                user_metadata: { 
                    ...user, 
                    app_origin: user.app_origin || DEFAULT_INSTITUTIONAL_APP_ORIGIN 
                },
                role: user.role || 'USER'
            },
            sub: user.id,
            iss: 'orbi.auth',
            exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60),
            expires_at: Math.floor(Date.now() / 1000) + (24 * 60 * 60),
            role: user.role || 'USER',
            permissions: this.getPermissionsForRole((user.role || 'USER') as UserRole, 'active')
        };
        Storage.setItem(STORAGE_KEYS.USER_SESSION, JSON.stringify(session));
        return { success: true, user: session.user, session, isNewUser };
    }

    async getUserProfile(userId: string) {
        const sb = getAdminSupabase();
        if (sb) {
            const { data, error } = await sb.from('users').select('*, metadata').eq('id', userId).single();
            if (error) return { error };
            
            // Flatten metadata for UI convenience if needed, but keeping it explicit as requested
            return { data };
        }
        // Fallback for local storage if needed, but primary is supabase
        let users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        const user = users.find(u => u.id === userId);
        return { data: user || null };
    }

    async updatePassword(password: string) {
        const sb = getSupabase();
        if (sb) return await sb.auth.updateUser({ password });
        return { data: null, error: new Error("Cloud synchronization required.") };
    }

    async completePasswordReset(password: string, identifier?: string, requestId?: string, code?: string) {
        if (identifier && requestId && code) {
            const identity = await this.resolveIdentityForChallenge(identifier);
            if (!identity) return { data: null, error: new Error('IDENTITY_NOT_FOUND') };
            const valid = await OTPService.verify(requestId, code, identity.userId);
            if (!valid) return { data: null, error: new Error('INVALID_OTP') };
            const sb = getAdminSupabase();
            if (!sb) return { data: null, error: new Error('DB_OFFLINE') };
            const result = await sb.auth.admin.updateUserById(identity.userId, { password });
            if (!result.error) {
                try {
                    await sb.from('user_sessions').update({ is_revoked: true }).eq('user_id', identity.userId);
                } catch (e) {
                    console.warn('[AuthService] Password reset session revocation failed:', e);
                }
                await this.security.logActivity(identity.userId, 'PASSWORD_RESET_COMPLETED', 'success', 'User completed OTP-confirmed password reset');
            }
            return result;
        }

        const result = await this.updatePassword(password);
        if (!result.error) {
            await this.security.logActivity('system', 'PASSWORD_RESET_COMPLETED', 'success', 'User completed password reset');
        }
        return result;
    }

    async initiatePasswordReset(identifier: string) {
        await this.cleanupExpiredUnconfirmedAccounts();
        const identity = await this.resolveIdentityForChallenge(identifier);
        if (!identity) {
            return { data: { requestId: null, deliveryContact: null }, error: null };
        }
        if (!this.isActiveStatus(identity.status)) {
            return { data: null, error: new Error('ACCOUNT_NOT_ACTIVE: Confirm your account before resetting the password.') };
        }
        const challengeContact = this.preferredChallengeContact(identity, identifier);
        if (!challengeContact) return { data: null, error: new Error('NO_CONTACT_AVAILABLE') };

        const result = await OTPService.generateAndSend(
            identity.userId,
            challengeContact.contact,
            'PASSWORD_RESET',
            challengeContact.type,
            'ORBI Password Reset',
        );
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

    async deleteAccount() { 
        const session = await this.getSession();
        if (session?.sub) { return { success: true }; }
        return { success: false, error: "Context Required" }; 
    }

    async completeProfile(phone: string, updates: any) { 
        if (Object.prototype.hasOwnProperty.call(updates || {}, 'currency')) {
            const normalizedCurrency = typeof updates?.currency === 'string'
                ? updates.currency.trim().toUpperCase()
                : '';
            if (!normalizedCurrency) {
                return { success: false, error: "CURRENCY_REQUIRED: Account currency cannot be empty." };
            }
            updates = { ...updates, currency: normalizedCurrency };
        }
        let users = Storage.getFromDB<any>(STORAGE_KEYS.CUSTOM_USERS);
        const idx = users.findIndex(u => u.phone === phone);
        if (idx >= 0) {
            users[idx] = { ...users[idx], ...updates };
            Storage.saveToDB(STORAGE_KEYS.CUSTOM_USERS, users);
            return { success: true };
        }
        return { success: false, error: "Identification failed." }; 
    }
}
