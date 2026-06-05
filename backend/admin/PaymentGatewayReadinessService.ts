const GATEWAY_TIMEOUT_MS = Number(process.env.ORBI_PAYMENT_GATEWAY_READINESS_TIMEOUT_MS || 3500);

const normalizeBaseUrl = (value: string) => value.replace(/\/+$/, '');

const fetchJsonWithTimeout = async (url: string, headers?: Record<string, string>) => {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), GATEWAY_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        accept: 'application/json',
        'user-agent': 'orbi-core-admin-readiness/1.0',
        ...(headers || {}),
      },
      signal: controller.signal,
    });
    const text = await response.text();
    const payload = text ? JSON.parse(text) : null;
    return {
      ok: response.ok,
      status: response.status,
      payload,
    };
  } finally {
    clearTimeout(timeout);
  }
};

export class PaymentGatewayReadinessService {
  static async inspect() {
    const baseUrl = normalizeBaseUrl(String(process.env.ORBI_PAY_GATEWAY_BASE_URL || '').trim());
    if (!baseUrl) {
      return {
        configured: false,
        reachable: false,
        baseUrl: null,
        message: 'ORBI_PAY_GATEWAY_BASE_URL is not configured.',
        providers: [],
      };
    }

    try {
      const ready = await fetchJsonWithTimeout(`${baseUrl}/ready`);
      const data = ready.payload?.data || ready.payload || {};
      return {
        configured: true,
        reachable: ready.ok,
        baseUrl,
        status: ready.status,
        message: ready.ok ? 'Payment gateway readiness loaded.' : 'Payment gateway returned a non-success readiness status.',
        providers: Array.isArray(data.providers) ? data.providers : [],
        mtlsEnabled: Boolean(data.mtlsEnabled),
        coreTarget: data.coreTarget || null,
        providerMode: data.providerMode || null,
      };
    } catch (error: any) {
      return {
        configured: true,
        reachable: false,
        baseUrl,
        message: error?.name === 'AbortError'
          ? `Payment gateway readiness timed out after ${GATEWAY_TIMEOUT_MS}ms.`
          : String(error?.message || error || 'PAYMENT_GATEWAY_UNREACHABLE'),
        providers: [],
      };
    }
  }

  static async discoverObpPaymentCapabilities(options: {
    providerCode?: string;
    bankId?: string;
    accountId?: string;
    viewId?: string;
    countryCode?: string;
    currency?: string;
  }) {
    const baseUrl = normalizeBaseUrl(String(process.env.ORBI_PAY_GATEWAY_BASE_URL || '').trim());
    if (!baseUrl) throw new Error('ORBI_PAY_GATEWAY_BASE_URL_NOT_CONFIGURED');

    const operatorKey = String(process.env.ORBI_PAY_GATEWAY_OPERATOR_DISCOVERY_API_KEY || '').trim();
    if (!operatorKey) throw new Error('ORBI_PAY_GATEWAY_OPERATOR_DISCOVERY_API_KEY_NOT_CONFIGURED');

    const providerCode = String(options.providerCode || 'nmb-obp-sandbox').trim();
    const url = new URL(`/v1/discovery/obp/${encodeURIComponent(providerCode)}/payment-capabilities`, `${baseUrl}/`);
    for (const [key, value] of Object.entries({
      bankId: options.bankId,
      accountId: options.accountId,
      viewId: options.viewId,
      countryCode: options.countryCode,
      currency: options.currency,
    })) {
      if (value) url.searchParams.set(key, value);
    }

    const result = await fetchJsonWithTimeout(url.toString(), {
      'x-orbi-pay-operator-key': operatorKey,
      'user-agent': 'orbi-core-payment-capability-discovery/1.0',
    });

    if (!result.ok || result.payload?.success === false) {
      throw new Error(result.payload?.error || `ORBI_PAY_GATEWAY_DISCOVERY_FAILED:${result.status}`);
    }

    return result.payload?.data || result.payload;
  }
}
