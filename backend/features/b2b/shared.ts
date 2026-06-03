import { getAdminSupabase, getSupabase } from '../../supabaseClient.js';

export type B2BQuery = Record<string, unknown>;

export const b2bDb = () => {
  const sb = getAdminSupabase() || getSupabase();
  if (!sb) throw new Error('DB_OFFLINE');
  return sb;
};

export const asString = (value: unknown, fallback = ''): string => {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed || fallback;
};

export const asNumber = (value: unknown, fallback = 0): number => {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
};

export const isoDaysAgo = (days: number): string => {
  const safeDays = Number.isFinite(days) ? Math.max(1, Math.min(365, Math.floor(days))) : 30;
  return new Date(Date.now() - safeDays * 24 * 60 * 60 * 1000).toISOString();
};

export const limitFromQuery = (value: unknown, fallback = 100, max = 500): number => {
  const parsed = asNumber(value, fallback);
  return Math.max(1, Math.min(max, Math.floor(parsed)));
};

export const metadataNumber = (metadata: unknown, keys: string[], fallback = 0): number => {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) return fallback;
  const source = metadata as Record<string, unknown>;
  for (const key of keys) {
    const value = asNumber(source[key], Number.NaN);
    if (Number.isFinite(value)) return value;
  }
  return fallback;
};
