import axios from 'axios';
import { getAdminSupabase, getSupabase } from '../supabaseClient.js';

export type LiquidityRateRequest = {
  fromCurrency: string;
  toCurrency: string;
  amount?: number;
};

export type LiquidityRateSnapshot = {
  fromCurrency: string;
  toCurrency: string;
  rate: number;
  providerCode: string;
  source: string;
  asOf: string;
  expiresAt: string;
  bidRate?: number;
  askRate?: number;
  corridorId?: string | null;
  settlementMode?: string | null;
};

export interface LiquidityProviderAdapter {
  getRate(request: LiquidityRateRequest): Promise<LiquidityRateSnapshot>;
}

const CACHE_TTL_MS = Math.max(
  Number(process.env.ORBI_FX_LIQUIDITY_CACHE_TTL_MS || 60000),
  5000,
);

const normalizeCurrency = (value: string) => String(value || '').trim().toUpperCase();

const assertCurrencyPair = (fromCurrency: string, toCurrency: string) => {
  const from = normalizeCurrency(fromCurrency);
  const to = normalizeCurrency(toCurrency);
  if (!/^[A-Z]{3}$/.test(from) || !/^[A-Z]{3}$/.test(to)) {
    throw new Error(`FX_CURRENCY_INVALID:${from || 'UNKNOWN'}:${to || 'UNKNOWN'}`);
  }
  return { from, to };
};

class OpenExchangeRateProviderAdapter implements LiquidityProviderAdapter {
  private ratesCache: Record<string, number> = {};
  private lastFetch = 0;

  private readonly baseUrl =
    process.env.ORBI_FX_OPEN_ER_API_BASE_URL || 'https://open.er-api.com/v6/latest/USD';

  async getRate(request: LiquidityRateRequest): Promise<LiquidityRateSnapshot> {
    const { from, to } = assertCurrencyPair(request.fromCurrency, request.toCurrency);
    if (from === to) return this.snapshot(from, to, 1);

    await this.refreshRates();
    const rateFrom = from === 'USD' ? 1 : this.ratesCache[from];
    const rateTo = to === 'USD' ? 1 : this.ratesCache[to];
    if (!rateFrom || !rateTo) {
      throw new Error(`FX_RATE_NOT_AVAILABLE:${from}:${to}`);
    }

    return this.snapshot(from, to, rateTo / rateFrom);
  }

  private async refreshRates() {
    if (Date.now() - this.lastFetch < CACHE_TTL_MS && Object.keys(this.ratesCache).length > 0) {
      return;
    }

    try {
      const response = await axios.get(this.baseUrl, { timeout: 7000 });
      const rates = response.data?.rates;
      if (!rates || typeof rates !== 'object') {
        throw new Error('INVALID_PROVIDER_PAYLOAD');
      }

      this.ratesCache = { USD: 1, ...rates };
      this.lastFetch = Date.now();
    } catch (error: any) {
      throw new Error(`FX_LIQUIDITY_PROVIDER_UNAVAILABLE:OPEN_ER_API:${error?.message || 'UNKNOWN'}`);
    }
  }

  private snapshot(fromCurrency: string, toCurrency: string, rate: number): LiquidityRateSnapshot {
    const asOf = new Date();
    return {
      fromCurrency,
      toCurrency,
      rate: Number(rate.toFixed(8)),
      providerCode: 'OPEN_ER_API',
      source: 'LIQUIDITY_PROVIDER',
      asOf: asOf.toISOString(),
      expiresAt: new Date(asOf.getTime() + CACHE_TTL_MS).toISOString(),
    };
  }
}

type FxCorridor = {
  id: string;
  from_currency: string;
  to_currency: string;
  rate_provider_code: string;
  settlement_mode: string;
  min_amount?: number | string | null;
  max_amount?: number | string | null;
  status: string;
};

class SandboxStaticLiquidityProviderAdapter implements LiquidityProviderAdapter {
  private readonly rates: Record<string, number> = {
    USD: 1,
    EUR: 0.92,
    GBP: 0.78,
    TZS: 2600,
    KES: 129,
    UGX: 3700,
    RWF: 1450,
    ZAR: 18.5,
    NGN: 1500,
    GHS: 15.4,
  };

  async getRate(request: LiquidityRateRequest): Promise<LiquidityRateSnapshot> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('FX_SANDBOX_PROVIDER_NOT_ALLOWED_IN_PRODUCTION');
    }

    const { from, to } = assertCurrencyPair(request.fromCurrency, request.toCurrency);
    const rateFrom = from === 'USD' ? 1 : this.rates[from];
    const rateTo = to === 'USD' ? 1 : this.rates[to];
    if (!rateFrom || !rateTo) throw new Error(`FX_SANDBOX_RATE_NOT_AVAILABLE:${from}:${to}`);

    const asOf = new Date();
    return {
      fromCurrency: from,
      toCurrency: to,
      rate: Number((rateTo / rateFrom).toFixed(8)),
      providerCode: 'SANDBOX_STATIC',
      source: 'SANDBOX_LIQUIDITY_SIMULATOR',
      asOf: asOf.toISOString(),
      expiresAt: new Date(asOf.getTime() + CACHE_TTL_MS).toISOString(),
    };
  }
}

class LiquidityProviderRegistry {
  private readonly providers: Record<string, LiquidityProviderAdapter>;

  constructor() {
    this.providers = {
      OPEN_ER_API: new OpenExchangeRateProviderAdapter(),
      SANDBOX_STATIC: new SandboxStaticLiquidityProviderAdapter(),
    };
  }

  async getRate(request: LiquidityRateRequest) {
    const corridor = await this.resolveCorridor(request);
    const providerCode = String(
      corridor?.rate_provider_code ||
      process.env.ORBI_FX_LIQUIDITY_PROVIDER ||
      'OPEN_ER_API',
    ).trim().toUpperCase();
    if (providerCode === 'SANDBOX_STATIC') {
      const snapshot = await this.providers.SANDBOX_STATIC.getRate(request);
      return this.attachCorridor(snapshot, corridor);
    }

    const provider = this.providers[providerCode];
    if (!provider) throw new Error(`FX_LIQUIDITY_PROVIDER_NOT_SUPPORTED:${providerCode}`);
    const snapshot = await provider.getRate(request);
    return this.attachCorridor(snapshot, corridor);
  }

  private attachCorridor(snapshot: LiquidityRateSnapshot, corridor: FxCorridor | null): LiquidityRateSnapshot {
    return {
      ...snapshot,
      corridorId: corridor?.id || null,
      settlementMode: corridor?.settlement_mode || null,
    };
  }

  private async resolveCorridor(request: LiquidityRateRequest): Promise<FxCorridor | null> {
    const { from, to } = assertCurrencyPair(request.fromCurrency, request.toCurrency);
    const requireRegistry = String(process.env.ORBI_FX_REQUIRE_CORRIDOR_REGISTRY || 'true').toLowerCase() !== 'false';
    const sb = getAdminSupabase() || getSupabase();
    if (!sb) {
      if (requireRegistry) throw new Error('FX_CORRIDOR_REGISTRY_UNAVAILABLE');
      return null;
    }

    const { data, error } = await sb
      .from('fx_corridors')
      .select('id, from_currency, to_currency, rate_provider_code, settlement_mode, min_amount, max_amount, status')
      .eq('from_currency', from)
      .eq('to_currency', to)
      .eq('status', 'ACTIVE')
      .order('priority', { ascending: true })
      .limit(1)
      .maybeSingle();

    if (error) throw new Error(`FX_CORRIDOR_LOOKUP_FAILED:${error.message}`);
    if (!data) throw new Error(`FX_CORRIDOR_NOT_AVAILABLE:${from}:${to}`);

    const amount = Number(request.amount || 0);
    const minAmount = Number(data.min_amount || 0);
    const maxAmount = Number(data.max_amount || 0);
    if (amount > 0 && minAmount > 0 && amount < minAmount) {
      throw new Error(`FX_AMOUNT_BELOW_CORRIDOR_MINIMUM:${from}:${to}`);
    }
    if (amount > 0 && maxAmount > 0 && amount > maxAmount) {
      throw new Error(`FX_AMOUNT_ABOVE_CORRIDOR_MAXIMUM:${from}:${to}`);
    }

    return data as FxCorridor;
  }
}

export const liquidityProviderRegistry = new LiquidityProviderRegistry();
