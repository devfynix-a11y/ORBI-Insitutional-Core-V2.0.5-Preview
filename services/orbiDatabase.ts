import pg from 'pg';

const { Pool } = pg;
export type OrbiDatabaseClient = pg.PoolClient;

export type OrbiRequestContext = {
  userId?: string | null;
  role?: string;
  claims?: Record<string, unknown>;
};

let pool: pg.Pool | null = null;

const databaseUrl = () => String(process.env.DATABASE_URL || '').trim();

export const getOrbiDatabase = (): pg.Pool => {
  if (pool) return pool;

  const connectionString = databaseUrl();
  if (!connectionString) {
    throw new Error('DATABASE_URL_REQUIRED');
  }

  pool = new Pool({
    connectionString,
    max: Number(process.env.ORBI_DATABASE_POOL_MAX || 20),
    idleTimeoutMillis: Number(process.env.ORBI_DATABASE_IDLE_TIMEOUT_MS || 30000),
    connectionTimeoutMillis: Number(process.env.ORBI_DATABASE_CONNECT_TIMEOUT_MS || 5000),
    ssl: process.env.ORBI_DATABASE_SSL === 'true'
      ? { rejectUnauthorized: process.env.ORBI_DATABASE_SSL_REJECT_UNAUTHORIZED !== 'false' }
      : false,
  });

  pool.on('error', (error) => {
    console.error('[OrbiDatabase] Idle client failure:', error);
  });

  return pool;
};

export const closeOrbiDatabase = async (): Promise<void> => {
  if (!pool) return;
  const activePool = pool;
  pool = null;
  await activePool.end();
};

export const withOrbiTransaction = async <T>(
  operation: (client: OrbiDatabaseClient) => Promise<T>,
  context: OrbiRequestContext = {},
): Promise<T> => {
  const client = await getOrbiDatabase().connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'SELECT orbi_auth.set_request_context($1::uuid, $2::text, $3::jsonb)',
      [
        context.userId || null,
        context.role || (context.userId ? 'authenticated' : 'service_role'),
        JSON.stringify(context.claims || {}),
      ],
    );
    const result = await operation(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
};
