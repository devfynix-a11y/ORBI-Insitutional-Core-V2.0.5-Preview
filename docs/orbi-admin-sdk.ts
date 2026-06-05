/**
 * ORBI Financial OS Admin Frontend SDK
 *
 * Copy this file into the admin frontend app as src/lib/orbi-admin-sdk.ts.
 * It intentionally uses only fetch and TypeScript so it can work in React,
 * Vite, Next.js, or an internal backend-for-frontend service.
 *
 * Security rules:
 * - Do not store provider secrets, monitor keys, or admin tokens in localStorage.
 * - Normal browser UI should not call monitor endpoints directly with ORBI_MONITOR_API_KEY.
 * - Commit mutations must be previewed and explicitly confirmed by the operator.
 */

export type OrbiRole =
  | 'SUPER_ADMIN'
  | 'ADMIN'
  | 'IT'
  | 'AUDIT'
  | 'ACCOUNTANT'
  | 'CUSTOMER_CARE'
  | 'HUMAN_RESOURCE'
  | 'FRAUD'
  | 'RISK_OFFICER'
  | 'MARKETING'
  | 'STAFF'
  | 'CONSUMER'
  | 'USER'
  | 'MERCHANT'
  | 'AGENT'
  | 'SYSTEM';

export type OrbiApiResult<T> = {
  success?: boolean;
  data?: T;
  error?: string;
  message?: string;
  [key: string]: unknown;
};

export type OrbiSdkConfig = {
  apiBaseUrl?: string;
  fallbackApiBaseUrl?: string;
  payGatewayBaseUrl?: string;
  appId: string;
  appOrigin: string;
  getToken?: () => string | null | Promise<string | null>;
  getDeviceId?: () => string | null | Promise<string | null>;
  getRole?: () => OrbiRole | string | null | Promise<OrbiRole | string | null>;
  getMonitorKey?: () => string | null | Promise<string | null>;
  enableSafeReadFallback?: boolean;
  includeRoleHeader?: boolean;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
  onRequest?: (request: { method: string; url: string; headers: Record<string, string> }) => void;
  onResponse?: (response: { method: string; url: string; status: number; ok: boolean }) => void;
  onError?: (error: unknown, request: { method: string; url: string }) => void;
};

export type RequestOptions = {
  query?: Record<string, unknown>;
  body?: unknown;
  idempotencyKey?: string;
  monitor?: boolean;
  gateway?: boolean;
  public?: boolean;
  fallbackSafeRead?: boolean;
  headers?: Record<string, string>;
};

export type AdminConfigBootstrapPayload = {
  mode: 'preview' | 'commit';
  fx?: {
    rates?: Record<string, number>;
    fee?: Record<string, unknown>;
  };
  providers?: Array<Record<string, unknown>>;
  partnerBanks?: Array<Record<string, unknown>>;
};

export type PaymentIntentPayload = Record<string, unknown>;
export type TransactionIssuePayload = { reason: string };
export type TransactionAuditPayload = { passed: boolean; notes?: string };
export type SupportTicketCreatePayload = {
  title: string;
  body: string;
  category?: string;
  priority?: string;
  customerId?: string;
  customerQuery?: string;
  assignedTo?: string | null;
  tags?: string[];
};
export type SupportTicketUpdatePayload = {
  status?: 'open' | 'in_progress' | 'resolved' | 'closed';
  assignedTo?: string | null;
  resolution?: string;
  internalNote?: string;
};

const DEFAULT_API_BASE_URL = 'https://api.orbifinancial.com';
const DEFAULT_FALLBACK_API_BASE_URL = 'https://go-api.orbifinancial.com';
const DEFAULT_PAY_GATEWAY_BASE_URL = 'https://pay.orbifinancial.com';

const makeTraceId = () => {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
  return `trace_${Date.now()}_${Math.random().toString(16).slice(2)}`;
};

const cleanPath = (path: string) => path.startsWith('/') ? path : `/${path}`;

const buildUrl = (baseUrl: string, path: string, query?: Record<string, unknown>) => {
  const url = new URL(cleanPath(path), baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`);
  for (const [key, value] of Object.entries(query || {})) {
    if (value === undefined || value === null || value === '') continue;
    if (Array.isArray(value)) {
      for (const item of value) url.searchParams.append(key, String(item));
    } else {
      url.searchParams.set(key, String(value));
    }
  }
  return url.toString();
};

export class OrbiApiError extends Error {
  status: number;
  code?: string;
  payload?: unknown;

  constructor(status: number, code: string | undefined, message: string, payload?: unknown) {
    super(message);
    this.name = 'OrbiApiError';
    this.status = status;
    this.code = code;
    this.payload = payload;
  }
}

export class OrbiAdminSdk {
  private config: Required<Pick<OrbiSdkConfig, 'appId' | 'appOrigin' | 'enableSafeReadFallback' | 'timeoutMs'>> & OrbiSdkConfig;

  constructor(config: OrbiSdkConfig) {
    this.config = {
      apiBaseUrl: DEFAULT_API_BASE_URL,
      fallbackApiBaseUrl: DEFAULT_FALLBACK_API_BASE_URL,
      payGatewayBaseUrl: DEFAULT_PAY_GATEWAY_BASE_URL,
      enableSafeReadFallback: false,
      includeRoleHeader: true,
      timeoutMs: 15000,
      ...config,
    };
  }

  private async headers(options: RequestOptions = {}) {
    if (options.public) {
      return {
        ...options.headers,
      };
    }

    const token = await this.config.getToken?.();
    const deviceId = await this.config.getDeviceId?.();
    const role = this.config.includeRoleHeader ? await this.config.getRole?.() : null;
    const monitorKey = options.monitor ? await this.config.getMonitorKey?.() : null;

    const headers: Record<string, string> = {
      'x-orbi-app-id': this.config.appId,
      'x-orbi-app-origin': this.config.appOrigin,
      'x-orbi-trace': makeTraceId(),
      ...options.headers,
    };

    if (options.body !== undefined) headers['Content-Type'] = 'application/json';
    if (token) headers.Authorization = `Bearer ${token}`;
    if (deviceId) headers['x-orbi-device-id'] = deviceId;
    if (role) headers['x-orbi-user-role'] = String(role).toUpperCase();
    if (monitorKey) headers['x-orbi-monitor-key'] = monitorKey;
    if (options.idempotencyKey) headers['Idempotency-Key'] = options.idempotencyKey;

    return headers;
  }

  private async request<T>(method: string, path: string, options: RequestOptions = {}): Promise<T> {
    const baseUrl = options.gateway ? this.config.payGatewayBaseUrl! : this.config.apiBaseUrl!;
    const url = buildUrl(baseUrl, path, options.query);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      const headers = await this.headers(options);
      this.config.onRequest?.({ method, url, headers });

      const response = await (this.config.fetchImpl || fetch)(url, {
        method,
        headers,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
        signal: controller.signal,
      });

      this.config.onResponse?.({ method, url, status: response.status, ok: response.ok });
      const text = await response.text();
      const payload = this.parsePayload(text, response.headers.get('content-type'));
      if (!response.ok || payload?.success === false) {
        throw new OrbiApiError(
          response.status,
          payload?.error,
          payload?.message || payload?.error || `ORBI request failed: ${response.status}`,
          payload,
        );
      }
      return payload as T;
    } catch (error) {
      this.config.onError?.(error, { method, url });
      const canFallback =
        method.toUpperCase() === 'GET' &&
        this.config.enableSafeReadFallback &&
        options.fallbackSafeRead !== false &&
        !options.gateway &&
        !options.monitor &&
        Boolean(this.config.fallbackApiBaseUrl);

      if (!canFallback) throw error;
      return this.requestAgainstBase<T>(this.config.fallbackApiBaseUrl!, method, path, options);
    } finally {
      clearTimeout(timer);
    }
  }

  private async requestAgainstBase<T>(baseUrl: string, method: string, path: string, options: RequestOptions): Promise<T> {
    const url = buildUrl(baseUrl, path, options.query);
    const headers = await this.headers(options);
    this.config.onRequest?.({ method, url, headers });

    const response = await (this.config.fetchImpl || fetch)(url, {
      method,
      headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
    });
    this.config.onResponse?.({ method, url, status: response.status, ok: response.ok });
    const text = await response.text();
    const payload = this.parsePayload(text, response.headers.get('content-type'));
    if (!response.ok || payload?.success === false) {
      throw new OrbiApiError(response.status, payload?.error, payload?.message || payload?.error || `ORBI fallback failed: ${response.status}`, payload);
    }
    return payload as T;
  }

  private parsePayload(text: string, contentType: string | null) {
    if (!text) return {};
    const isJson = String(contentType || '').includes('application/json') || /^[\[{]/.test(text.trim());
    if (!isJson) return { success: true, data: text };
    try {
      return JSON.parse(text);
    } catch {
      return { success: false, error: 'INVALID_JSON_RESPONSE', message: text.slice(0, 500) };
    }
  }

  get<T>(path: string, query?: Record<string, unknown>, options?: RequestOptions) {
    return this.request<T>('GET', path, { ...options, query });
  }

  post<T>(path: string, body?: unknown, options?: RequestOptions) {
    return this.request<T>('POST', path, { ...options, body });
  }

  patch<T>(path: string, body?: unknown, options?: RequestOptions) {
    return this.request<T>('PATCH', path, { ...options, body });
  }

  put<T>(path: string, body?: unknown, options?: RequestOptions) {
    return this.request<T>('PUT', path, { ...options, body });
  }

  delete<T>(path: string, options?: RequestOptions) {
    return this.request<T>('DELETE', path, options);
  }

  health = {
    primary: () => this.get<Record<string, unknown>>('/health', undefined, { public: true, fallbackSafeRead: false }),
    ready: () => this.get<Record<string, unknown>>('/ready', undefined, { public: true, fallbackSafeRead: false }),
    deep: () => this.get<Record<string, unknown>>('/health/deep', undefined, { public: true, fallbackSafeRead: false }),
    fallback: () => this.requestAgainstBase<Record<string, unknown>>(this.config.fallbackApiBaseUrl!, 'GET', '/health', { public: true, fallbackSafeRead: false }),
    gateway: () => this.get<Record<string, unknown>>('/health', undefined, { gateway: true, public: true, fallbackSafeRead: false }),
    diagnose: async () => ({
      primary: await this.health.primary().catch((error) => ({ success: false, error })),
      fallback: await this.health.fallback().catch((error) => ({ success: false, error })),
      gateway: await this.health.gateway().catch((error) => ({ success: false, error })),
    }),
  };

  auth = {
    login: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/login', body),
    session: () => this.get<OrbiApiResult<unknown>>('/v1/auth/session'),
    refresh: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/refresh', body),
    logout: () => this.post<OrbiApiResult<unknown>>('/v1/auth/logout'),
    bootstrapState: () => this.get<OrbiApiResult<unknown>>('/v1/auth/bootstrap-state'),
    bootstrapAdmin: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/bootstrap-admin', body),
    otpInitiate: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/otp/initiate', body),
    verifySensitiveAction: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/verify', body),
    passkeyRegisterStart: (body?: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/passkey/register/start', body || {}),
    passkeyRegisterFinish: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/passkey/register/finish', body),
    passkeyLoginStart: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/passkey/login/start', body),
    passkeyLoginFinish: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/passkey/login/finish', body),
    pinEnroll: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/pin/enroll', body),
    pinUpdate: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/pin/update', body),
    pinLogin: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/auth/pin-login', body),
  };

  admin = {
    transactions: {
      list: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/admin/transactions', query),
      summary: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/transactions/summary', query),
      ledger: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/v1/admin/transactions/${id}/ledger`),
      lock: (id: string, body: TransactionIssuePayload) => this.post<OrbiApiResult<unknown>>(`/v1/admin/transactions/${id}/lock`, body),
      audit: (id: string, body: TransactionAuditPayload) => this.post<OrbiApiResult<unknown>>(`/v1/admin/transactions/${id}/audit`, body),
      approve: (id: string, body: TransactionIssuePayload) => this.post<OrbiApiResult<unknown>>(`/v1/admin/transactions/${id}/approve`, body),
      approveAudited: (body: TransactionIssuePayload) => this.post<OrbiApiResult<unknown>>('/v1/admin/transactions/approve-audited', body),
      reverse: (id: string, body: TransactionIssuePayload) => this.post<OrbiApiResult<unknown>>(`/v1/admin/transactions/${id}/reverse`, body),
    },
    users: {
      search: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/admin/users/search', query),
      registerManaged: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/admin/users/register', body),
      updateStatus: (id: string, body: { status: string; reason: string }) => this.patch<OrbiApiResult<unknown>>(`/v1/admin/users/${id}/status`, body),
      updateProfile: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/v1/admin/users/${id}/profile`, body),
      permissionsPreview: (query: { role: string; status?: string }) => this.get<OrbiApiResult<unknown>>('/v1/admin/permissions/preview', query),
    },
    staff: {
      list: () => this.get<OrbiApiResult<unknown[]>>('/v1/admin/staff'),
      create: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/admin/staff', body),
      update: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/v1/admin/staff/${id}`, body),
      resetPassword: (id: string, body: { password: string }) => this.post<OrbiApiResult<unknown>>(`/v1/admin/staff/${id}/reset-password`, body),
      activity: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/v1/admin/staff/${id}/activity`),
    },
    kyc: {
      requests: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/kyc/requests', query),
      review: (body: { requestId: string; decision: 'APPROVED' | 'REJECTED'; reason?: string }) => this.post<OrbiApiResult<unknown>>('/v1/admin/kyc/review', body),
    },
    documents: {
      list: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/documents', query),
      verify: (id: string, body: { status: string; rejection_reason?: string }) => this.patch<OrbiApiResult<unknown>>(`/v1/admin/documents/${id}/verify`, body),
    },
    devices: {
      list: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/devices', query),
      updateStatus: (id: string, body: { is_trusted?: boolean; status?: string }) => this.patch<OrbiApiResult<unknown>>(`/v1/admin/devices/${id}/status`, body),
    },
    serviceAccess: {
      requests: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/admin/service-access/requests', query),
      review: (id: string, body: { decision: 'APPROVED' | 'REJECTED'; review_note?: string }) => this.post<OrbiApiResult<unknown>>(`/v1/admin/service-access/requests/${id}/review`, body),
      links: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/service-links', query),
      commissions: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/service-commissions', query),
    },
    audit: {
      trail: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/admin/audit-trail', query),
      riskAlerts: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/admin/risk/alerts', query),
      geoHeatmap: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/risk/geo-heatmap', query),
      liveGeo: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/risk/live-geo', query),
      complianceNodeRiskDensity: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/admin/compliance/node-zones/risk-density', query),
    },
    support: {
      tickets: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/admin/support-tickets', query),
      createTicket: (body: SupportTicketCreatePayload) => this.post<OrbiApiResult<unknown>>('/v1/admin/support-tickets', body),
      updateTicket: (id: string, body: SupportTicketUpdatePayload) => this.patch<OrbiApiResult<unknown>>(`/v1/admin/support-tickets/${id}`, body),
      staffMessages: () => this.get<OrbiApiResult<unknown[]>>('/v1/admin/staff-messages'),
      sendStaffMessage: (body: { recipientId?: string; targetRole?: string; content: string }) => this.post<OrbiApiResult<unknown>>('/v1/admin/staff-messages', body),
      flagStaffMessage: (id: string) => this.patch<OrbiApiResult<unknown>>(`/v1/admin/staff-messages/${id}/flag`, {}),
    },
    messaging: {
      templates: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/admin/messaging/templates', query),
      previewTemplate: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/admin/messaging/templates/preview', body),
      previewAudience: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/admin/messaging/audience/preview', body),
      sendTemplate: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/admin/messaging/send-template', body),
      sendSystemSms: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/admin/messaging/send-system-sms', body),
    },
    reconciliation: {
      run: (body: { reason: string }) => this.post<OrbiApiResult<unknown>>('/v1/admin/reconciliation/run', body),
      reports: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/admin/reconciliation/reports', query),
    },
    config: {
      ledger: () => this.get<OrbiApiResult<unknown>>('/v1/admin/config/ledger'),
      saveLedger: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/admin/config/ledger', body),
      commissions: () => this.get<OrbiApiResult<unknown>>('/v1/admin/config/commissions'),
      saveCommissions: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/admin/config/commissions', body),
      fxRates: () => this.get<OrbiApiResult<unknown>>('/v1/admin/config/fx-rates'),
      saveFxRates: (body: Record<string, number>) => this.post<OrbiApiResult<unknown>>('/v1/admin/config/fx-rates', body),
      bootstrapPreview: (body: Omit<AdminConfigBootstrapPayload, 'mode'>) => this.post<OrbiApiResult<unknown>>('/api/admin/config/bootstrap', { ...body, mode: 'preview' }),
      bootstrapCommit: (body: Omit<AdminConfigBootstrapPayload, 'mode'>) => this.post<OrbiApiResult<unknown>>('/api/admin/config/bootstrap', { ...body, mode: 'commit' }),
    },
    providers: {
      partners: () => this.get<OrbiApiResult<unknown[]>>('/api/admin/partners'),
      gatewayReadiness: () => this.get<OrbiApiResult<unknown>>('/api/admin/payment-gateway/readiness'),
      createPartner: (body: unknown) => this.post<OrbiApiResult<unknown>>('/api/admin/partners', body),
      updatePartner: (id: string, body: unknown) => this.put<OrbiApiResult<unknown>>(`/api/admin/partners/${id}`, body),
      deletePartner: (id: string) => this.delete<OrbiApiResult<unknown>>(`/api/admin/partners/${id}`),
      routingRules: () => this.get<OrbiApiResult<unknown[]>>('/api/admin/provider-routing-rules'),
      createRoutingRule: (body: unknown) => this.post<OrbiApiResult<unknown>>('/api/admin/provider-routing-rules', body),
      updateRoutingRule: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/api/admin/provider-routing-rules/${id}`, body),
      deleteRoutingRule: (id: string) => this.delete<OrbiApiResult<unknown>>(`/api/admin/provider-routing-rules/${id}`),
      platformFees: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/api/admin/platform-fees', query),
      createPlatformFee: (body: unknown) => this.post<OrbiApiResult<unknown>>('/api/admin/platform-fees', body),
      updatePlatformFee: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/api/admin/platform-fees/${id}`, body),
      institutionalAccounts: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/api/admin/institutional-payment-accounts', query),
      createInstitutionalAccount: (body: unknown) => this.post<OrbiApiResult<unknown>>('/api/admin/institutional-payment-accounts', body),
      updateInstitutionalAccount: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/api/admin/institutional-payment-accounts/${id}`, body),
    },
    operationalAccounts: {
      list: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/api/admin/platform-operational-accounts', query),
      create: (body: unknown) => this.post<OrbiApiResult<unknown>>('/api/admin/platform-operational-accounts', body),
      update: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/api/admin/platform-operational-accounts/${id}`, body),
      ledger: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/api/admin/platform-operational-accounts/${id}/ledger`),
      fund: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/api/admin/platform-operational-accounts/${id}/fund`, body),
      payout: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/api/admin/platform-operational-accounts/${id}/payout`, body),
      refund: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/api/admin/platform-operational-accounts/${id}/refund`, body),
    },
    kms: {
      health: () => this.get<OrbiApiResult<unknown>>('/v1/admin/kms/health'),
      diagnose: (body: { masterKey?: string }) => this.post<OrbiApiResult<unknown>>('/v1/admin/kms/diagnose', body),
      rewrap: (body: { confirm: 'REWRAP_KEYS'; newMasterKey?: string }) => this.post<OrbiApiResult<unknown>>('/v1/admin/kms/rewrap', body),
    },
  };

  monitor = {
    operationalHealth: () => this.get<OrbiApiResult<unknown>>('/api/admin/monitor/operational-health', undefined, { monitor: true, fallbackSafeRead: false }),
    operationalMetrics: () => this.get<OrbiApiResult<unknown>>('/api/admin/monitor/operational-metrics', undefined, { monitor: true, fallbackSafeRead: false }),
    prometheusMetrics: () => this.get<string>('/api/admin/monitor/operational-metrics/prometheus', undefined, { monitor: true, fallbackSafeRead: false }),
    snapshotMetrics: () => this.post<OrbiApiResult<unknown>>('/api/admin/monitor/operational-metrics/snapshot', {}, { monitor: true }),
    ledgerHealth: () => this.get<OrbiApiResult<unknown>>('/api/admin/monitor/ledger-health', undefined, { monitor: true, fallbackSafeRead: false }),
    walletForensics: (walletId: string) => this.get<OrbiApiResult<unknown>>(`/api/admin/monitor/wallet-forensics/${walletId}`, undefined, { monitor: true, fallbackSafeRead: false }),
  };

  finance = {
    dashboard: () => this.get<OrbiApiResult<unknown>>('/v1/dashboard'),
    userDashboard: () => this.get<OrbiApiResult<unknown>>('/v1/user/dashboard'),
    wallets: () => this.get<OrbiApiResult<unknown[]>>('/v1/wallets'),
    createWallet: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/wallets', body),
    deleteWallet: (id: string) => this.delete<OrbiApiResult<unknown>>(`/v1/wallets/${id}`),
    lockWallet: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wallets/${id}/lock`, body),
    unlockWallet: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wallets/${id}/unlock`, body),
    linkedWallets: () => this.get<OrbiApiResult<unknown[]>>('/v1/wallets/linked'),
    sovereignWallets: () => this.get<OrbiApiResult<unknown[]>>('/v1/wallets/sovereign'),
    paymentMethods: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/payment-methods', query),
    previewTransaction: (body: PaymentIntentPayload) => this.post<OrbiApiResult<unknown>>('/v1/transactions/preview', body),
    settleTransaction: (body: PaymentIntentPayload, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>('/v1/transactions/settle', body, { idempotencyKey }),
    transactions: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/transactions', query),
    receipt: (id: string) => this.get<OrbiApiResult<unknown>>(`/v1/transactions/${id}/receipt`),
    fxQuote: (query: { from: string; to: string; amount: number | string }) => this.get<OrbiApiResult<unknown>>('/v1/fx/quote', query),
  };

  commerce = {
    merchantCategories: () => this.get<OrbiApiResult<unknown[]>>('/v1/merchants/categories'),
    merchants: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/merchants', query),
    createMerchantAccount: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/merchants/accounts', body),
    myMerchantAccount: () => this.get<OrbiApiResult<unknown>>('/v1/merchants/accounts/my'),
    merchantAccount: (id: string) => this.get<OrbiApiResult<unknown>>(`/v1/merchants/accounts/${id}`),
    updateMerchantSettlement: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/v1/merchants/accounts/${id}/settlement`, body),
    merchantTransactions: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/merchant/transactions', query),
    merchantWallets: () => this.get<OrbiApiResult<unknown[]>>('/v1/merchant/wallets'),
    registerMerchantCustomer: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/merchant/customers/register', body),
    merchantCustomers: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/merchant/customers', query),
    merchantPaymentPreview: (body: PaymentIntentPayload) => this.post<OrbiApiResult<unknown>>('/v1/merchant/payments/preview', body),
    merchantPaymentSettle: (body: PaymentIntentPayload, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>('/v1/merchant/payments/settle', body, { idempotencyKey }),
    orbiPayPreview: (body: PaymentIntentPayload) => this.post<OrbiApiResult<unknown>>('/v1/payments/orbi-pay/preview', body),
    orbiPaySettle: (body: PaymentIntentPayload, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>('/v1/payments/orbi-pay/settle', body, { idempotencyKey }),
    billProviders: () => this.get<OrbiApiResult<unknown[]>>('/v1/payments/bills/providers'),
    billPreview: (body: PaymentIntentPayload) => this.post<OrbiApiResult<unknown>>('/v1/payments/bills/preview', body),
    billSettle: (body: PaymentIntentPayload, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>('/v1/payments/bills/settle', body, { idempotencyKey }),
    agentTransactions: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/agent/transactions', query),
    agentWallets: () => this.get<OrbiApiResult<unknown[]>>('/v1/agent/wallets'),
    agentLookup: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown>>('/v1/agent/lookup', query),
    registerAgentCustomer: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/agent/customers/register', body),
    agentCustomers: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/agent/customers', query),
    agentCommissions: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/agent/commissions', query),
    agentCashDepositPreview: (body: PaymentIntentPayload) => this.post<OrbiApiResult<unknown>>('/v1/agent/cash/deposit/preview', body),
    agentCashDepositSettle: (body: PaymentIntentPayload, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>('/v1/agent/cash/deposit/settle', body, { idempotencyKey }),
    agentCashWithdrawPreview: (body: PaymentIntentPayload) => this.post<OrbiApiResult<unknown>>('/v1/agent/cash/withdraw/preview', body),
    agentCashWithdrawSettle: (body: PaymentIntentPayload, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>('/v1/agent/cash/withdraw/settle', body, { idempotencyKey }),
  };

  externalFunds = {
    preview: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/external-funds/preview', body),
    createDepositIntent: (body: unknown, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>('/v1/external-funds/deposit-intents', body, { idempotencyKey }),
    settle: (body: unknown, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>('/v1/external-funds/settle', body, { idempotencyKey }),
    movements: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/external-funds/movements', query),
    movement: (id: string) => this.get<OrbiApiResult<unknown>>(`/v1/external-funds/movements/${id}`),
  };

  gateway = {
    providers: () => this.get<OrbiApiResult<unknown[]>>('/v1/gateway/providers'),
    initiatePayment: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/gateway/payment/initiate', body),
    settlePayment: (orderId: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/gateway/payment/${orderId}/settle`, body),
    refundPayment: (orderId: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/gateway/payment/${orderId}/refund`, body),
    orders: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/gateway/orders', query),
    order: (orderId: string) => this.get<OrbiApiResult<unknown>>(`/v1/gateway/order/${orderId}`),
    settlementStatus: (settlementId: string) => this.get<OrbiApiResult<unknown>>(`/v1/gateway/settlement/${settlementId}/status`),
    confirmSettlement: (settlementId: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/gateway/settlement/${settlementId}/confirm`, body),
    disputeSettlement: (settlementId: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/gateway/settlement/${settlementId}/dispute`, body),
    settlements: (query?: Record<string, unknown>) => this.get<OrbiApiResult<unknown[]>>('/v1/gateway/settlements', query),
    schedulerHealth: () => this.get<OrbiApiResult<unknown>>('/v1/gateway/scheduler/health'),
  };

  wealth = {
    summary: () => this.get<OrbiApiResult<unknown>>('/v1/wealth/summary'),
    goals: () => this.get<OrbiApiResult<unknown[]>>('/v1/goals'),
    createGoal: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/goals', body),
    updateGoal: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/v1/goals/${id}`, body),
    deleteGoal: (id: string) => this.delete<OrbiApiResult<unknown>>(`/v1/goals/${id}`),
    allocateGoal: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/goals/${id}/allocate`, body),
    withdrawGoal: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/goals/${id}/withdraw`, body),
    billReserves: () => this.get<OrbiApiResult<unknown[]>>('/v1/wealth/bill-reserves'),
    createBillReserve: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/wealth/bill-reserves', body),
    updateBillReserve: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/v1/wealth/bill-reserves/${id}`, body),
    deleteBillReserve: (id: string) => this.delete<OrbiApiResult<unknown>>(`/v1/wealth/bill-reserves/${id}`),
    sharedPots: () => this.get<OrbiApiResult<unknown[]>>('/v1/wealth/shared-pots'),
    createSharedPot: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/wealth/shared-pots', body),
    updateSharedPot: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/v1/wealth/shared-pots/${id}`, body),
    sharedPotMembers: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/v1/wealth/shared-pots/${id}/members`),
    sharedPotInvitations: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/v1/wealth/shared-pots/${id}/invitations`),
    mySharedPotInvitations: () => this.get<OrbiApiResult<unknown[]>>('/v1/wealth/shared-pot-invitations'),
    inviteSharedPot: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-pots/${id}/invitations`, body),
    respondSharedPotInvitation: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-pot-invitations/${id}/respond`, body),
    contributeSharedPot: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-pots/${id}/contribute`, body),
    withdrawSharedPot: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-pots/${id}/withdraw`, body),
    sharedBudgets: () => this.get<OrbiApiResult<unknown[]>>('/v1/wealth/shared-budgets'),
    createSharedBudget: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/wealth/shared-budgets', body),
    updateSharedBudget: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/v1/wealth/shared-budgets/${id}`, body),
    sharedBudgetMembers: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/v1/wealth/shared-budgets/${id}/members`),
    sharedBudgetTransactions: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/v1/wealth/shared-budgets/${id}/transactions`),
    sharedBudgetInvitations: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/v1/wealth/shared-budgets/${id}/invitations`),
    mySharedBudgetInvitations: () => this.get<OrbiApiResult<unknown[]>>('/v1/wealth/shared-budget-invitations'),
    inviteSharedBudget: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-budgets/${id}/invitations`, body),
    respondSharedBudgetInvitation: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-budget-invitations/${id}/respond`, body),
    sharedBudgetApprovals: (id: string) => this.get<OrbiApiResult<unknown[]>>(`/v1/wealth/shared-budgets/${id}/approvals`),
    respondSharedBudgetApproval: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-budget-approvals/${id}/respond`, body),
    sharedBudgetSpendPreview: (id: string, body: unknown) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-budgets/${id}/spend/preview`, body),
    sharedBudgetSpendSettle: (id: string, body: unknown, idempotencyKey: string) => this.post<OrbiApiResult<unknown>>(`/v1/wealth/shared-budgets/${id}/spend/settle`, body, { idempotencyKey }),
    allocationRules: () => this.get<OrbiApiResult<unknown[]>>('/v1/wealth/allocation-rules'),
    createAllocationRule: (body: unknown) => this.post<OrbiApiResult<unknown>>('/v1/wealth/allocation-rules', body),
    updateAllocationRule: (id: string, body: unknown) => this.patch<OrbiApiResult<unknown>>(`/v1/wealth/allocation-rules/${id}`, body),
  };
}
