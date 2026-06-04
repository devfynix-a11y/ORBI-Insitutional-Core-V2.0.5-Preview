const GATEWAY_TIMEOUT_MS = Number(process.env.ORBI_PAYMENT_GATEWAY_READINESS_TIMEOUT_MS || 3500);

const normalizeBaseUrl = (value: string) => value.replace(/\/+$/, '');

const fetchJsonWithTimeout = async (url: string) => {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), GATEWAY_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        accept: 'application/json',
        'user-agent': 'orbi-core-admin-readiness/1.0',
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
    const baseUrl = normalizeBaseUrl(String(process.env.ORBI_GATEWAY_BASE_URL || '').trim());
    if (!baseUrl) {
      return {
        configured: false,
        reachable: false,
        baseUrl: null,
        message: 'ORBI_GATEWAY_BASE_URL is not configured.',
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
}
