import test, { TestContext } from 'node:test';
import assert from 'node:assert/strict';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import {
  getLocalPostgresClient,
  type LocalPostgresClient,
} from '../../services/localPostgresClient.js';

export type DbIntegrationOptions = {
  requireWrites?: boolean;
  requiredEnv?: string[];
};

export const dbIntegrationEnabled = process.env.ORBI_RUN_DB_INTEGRATION === 'true';
export const dbIntegrationWritesEnabled = process.env.ORBI_DB_INTEGRATION_ALLOW_WRITES === 'true';
export const dbIntegrationProvider = String(
  process.env.ORBI_DB_INTEGRATION_PROVIDER
    || process.env.ORBI_DATA_PROVIDER
    || 'supabase',
).trim().toLowerCase();

export type DbIntegrationClient = SupabaseClient | LocalPostgresClient;

export function hasDbIntegrationConfig(): boolean {
  if (dbIntegrationProvider === 'local') {
    return !!(process.env.ORBI_DB_INTEGRATION_DATABASE_URL || process.env.DATABASE_URL);
  }
  return !!process.env.SUPABASE_URL && !!process.env.SUPABASE_SERVICE_ROLE_KEY;
}

export function hasRequiredEnv(keys: string[] = []): boolean {
  return keys.every((key) => !!process.env[key]);
}

export function createDbIntegrationClient(): DbIntegrationClient {
  if (dbIntegrationProvider === 'local') {
    const connectionString = process.env.ORBI_DB_INTEGRATION_DATABASE_URL || process.env.DATABASE_URL;
    assert.ok(connectionString, 'ORBI_DB_INTEGRATION_DATABASE_URL or DATABASE_URL is required');
    process.env.DATABASE_URL = connectionString;
    return getLocalPostgresClient();
  }

  assert.ok(process.env.SUPABASE_URL, 'SUPABASE_URL is required for DB integration tests');
  assert.ok(process.env.SUPABASE_SERVICE_ROLE_KEY, 'SUPABASE_SERVICE_ROLE_KEY is required for DB integration tests');

  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export function requireEnv(name: string): string {
  const value = process.env[name];
  assert.ok(value, `${name} is required for this DB integration test`);
  return value;
}

export function dbIntegrationTest(
  name: string,
  fn: (t: TestContext, client: DbIntegrationClient) => Promise<void> | void,
  options: DbIntegrationOptions = {},
) {
  const shouldSkip =
    !dbIntegrationEnabled ||
    !hasDbIntegrationConfig() ||
    (options.requireWrites && !dbIntegrationWritesEnabled) ||
    !hasRequiredEnv(options.requiredEnv || []);

  test(name, { skip: shouldSkip }, async (t) => {
    const client = createDbIntegrationClient();
    try {
      await fn(t, client);
    } catch (error: any) {
      const message = String(error?.message || '');
      const details = String(error?.actual?.details || error?.actual?.message || '');
      const combined = `${message} ${details}`.toLowerCase();
      if (
        combined.includes('fetch failed')
        || combined.includes('eai_again')
        || combined.includes('dns')
        || combined.includes('econnrefused')
      ) {
        t.skip('DB integration skipped due to transient connectivity failure');
        return;
      }
      throw error;
    }
  });
}
