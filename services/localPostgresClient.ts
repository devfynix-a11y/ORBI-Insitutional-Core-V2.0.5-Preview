import type pg from 'pg';
import { getOrbiDatabase, withOrbiTransaction, type OrbiRequestContext } from './orbiDatabase.js';

type QueryResult<T = any> = {
  data: T | null;
  error: any | null;
  count?: number | null;
};

type Filter = {
  column: string;
  operator: string;
  value: unknown;
};

const identifierPattern = /^[A-Za-z_][A-Za-z0-9_]*$/;

const quoteIdentifier = (value: string): string => {
  if (!identifierPattern.test(value)) {
    throw new Error(`UNSAFE_DATABASE_IDENTIFIER:${value}`);
  }
  return `"${value}"`;
};

const splitTopLevel = (value: string): string[] => {
  const parts: string[] = [];
  let depth = 0;
  let current = '';
  for (const character of value) {
    if (character === '(') depth += 1;
    if (character === ')') depth -= 1;
    if (character === ',' && depth === 0) {
      parts.push(current);
      current = '';
      continue;
    }
    current += character;
  }
  if (current.trim()) parts.push(current);
  return parts.map((part) => part.trim()).filter(Boolean);
};

const parseColumns = (selection: string): string => {
  const normalized = String(selection || '*').trim();
  if (!normalized || normalized === '*') return '*';

  return splitTopLevel(normalized)
    .map((column) => {
      if (column.includes('(') || column.includes('!')) {
        throw new Error(`LOCAL_POSTGRES_NESTED_SELECT_UNSUPPORTED:${column}`);
      }
      const [alias, source] = column.includes(':')
        ? column.split(':', 2).map((part) => part.trim())
        : [null, column.trim()];
      const quotedSource = quoteIdentifier(source);
      return alias ? `${quotedSource} AS ${quoteIdentifier(alias)}` : quotedSource;
    })
    .join(', ');
};

const normalizeError = (error: any) => ({
  message: String(error?.message || error),
  code: error?.code,
  details: error?.detail,
  hint: error?.hint,
});

class LocalPostgresQueryBuilder implements PromiseLike<QueryResult> {
  private action: 'select' | 'insert' | 'update' | 'upsert' | 'delete' = 'select';
  private selection = '*';
  private rows: Record<string, any>[] = [];
  private filters: Filter[] = [];
  private orGroups: Filter[][] = [];
  private orderBy: { column: string; ascending: boolean }[] = [];
  private rowLimit: number | null = null;
  private rowOffset: number | null = null;
  private singleMode: 'single' | 'maybeSingle' | null = null;
  private countMode: 'exact' | null = null;
  private head = false;
  private returningRequested = false;
  private conflictColumns: string[] = [];

  constructor(
    private readonly table: string,
    private readonly context: OrbiRequestContext,
  ) {
    quoteIdentifier(table);
  }

  select(columns = '*', options: { count?: 'exact'; head?: boolean } = {}) {
    this.selection = columns;
    this.countMode = options.count || null;
    this.head = options.head === true;
    this.returningRequested = true;
    return this;
  }

  insert(values: Record<string, any> | Record<string, any>[]) {
    this.action = 'insert';
    this.rows = Array.isArray(values) ? values : [values];
    return this;
  }

  update(values: Record<string, any>) {
    this.action = 'update';
    this.rows = [values];
    return this;
  }

  upsert(
    values: Record<string, any> | Record<string, any>[],
    options: { onConflict?: string } = {},
  ) {
    this.action = 'upsert';
    this.rows = Array.isArray(values) ? values : [values];
    this.conflictColumns = String(options.onConflict || '')
      .split(',')
      .map((column) => column.trim())
      .filter(Boolean);
    return this;
  }

  delete() {
    this.action = 'delete';
    return this;
  }

  eq(column: string, value: unknown) { return this.addFilter(column, 'eq', value); }
  neq(column: string, value: unknown) { return this.addFilter(column, 'neq', value); }
  gt(column: string, value: unknown) { return this.addFilter(column, 'gt', value); }
  gte(column: string, value: unknown) { return this.addFilter(column, 'gte', value); }
  lt(column: string, value: unknown) { return this.addFilter(column, 'lt', value); }
  lte(column: string, value: unknown) { return this.addFilter(column, 'lte', value); }
  like(column: string, value: unknown) { return this.addFilter(column, 'like', value); }
  ilike(column: string, value: unknown) { return this.addFilter(column, 'ilike', value); }
  is(column: string, value: unknown) { return this.addFilter(column, 'is', value); }
  in(column: string, value: unknown[]) { return this.addFilter(column, 'in', value); }
  contains(column: string, value: unknown) { return this.addFilter(column, 'contains', value); }
  match(values: Record<string, unknown>) {
    for (const [column, value] of Object.entries(values)) this.eq(column, value);
    return this;
  }

  not(column: string, operator: string, value: unknown) {
    return this.addFilter(column, `not.${operator}`, value);
  }

  or(expression: string | string[]) {
    const value = Array.isArray(expression) ? expression.join(',') : expression;
    const group = splitTopLevel(value).map((part) => this.parseOrFilter(part));
    this.orGroups.push(group);
    return this;
  }

  order(column: string, options: { ascending?: boolean } = {}) {
    quoteIdentifier(column);
    this.orderBy.push({ column, ascending: options.ascending !== false });
    return this;
  }

  limit(value: number) {
    this.rowLimit = Math.max(0, Number(value));
    return this;
  }

  range(from: number, to: number) {
    this.rowOffset = Math.max(0, Number(from));
    this.rowLimit = Math.max(0, Number(to) - this.rowOffset + 1);
    return this;
  }

  single() {
    this.singleMode = 'single';
    this.rowLimit = 2;
    return this;
  }

  maybeSingle() {
    this.singleMode = 'maybeSingle';
    this.rowLimit = 2;
    return this;
  }

  then<TResult1 = QueryResult, TResult2 = never>(
    onfulfilled?: ((value: QueryResult) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null,
  ): PromiseLike<TResult1 | TResult2> {
    return this.execute().then(onfulfilled, onrejected);
  }

  private addFilter(column: string, operator: string, value: unknown) {
    quoteIdentifier(column);
    this.filters.push({ column, operator, value });
    return this;
  }

  private parseOrFilter(value: string): Filter {
    const match = value.match(/^([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z]+)\.(.*)$/);
    if (!match) throw new Error(`LOCAL_POSTGRES_OR_FILTER_UNSUPPORTED:${value}`);
    const [, column, operator, rawValue] = match;
    let parsedValue: unknown = rawValue;
    if (rawValue === 'null') parsedValue = null;
    if (rawValue === 'true') parsedValue = true;
    if (rawValue === 'false') parsedValue = false;
    return { column, operator, value: parsedValue };
  }

  private buildFilterSql(values: unknown[]): string {
    const clauses = this.filters.map((filter) => this.filterSql(filter, values));
    for (const group of this.orGroups) {
      clauses.push(`(${group.map((filter) => this.filterSql(filter, values)).join(' OR ')})`);
    }
    return clauses.length ? ` WHERE ${clauses.join(' AND ')}` : '';
  }

  private filterSql(filter: Filter, values: unknown[]): string {
    const column = quoteIdentifier(filter.column);
    const negated = filter.operator.startsWith('not.');
    const operator = negated ? filter.operator.slice(4) : filter.operator;

    if (operator === 'is') {
      const isNull = filter.value === null || filter.value === 'null';
      const sql = `${column} IS ${isNull ? 'NULL' : String(filter.value).toUpperCase()}`;
      return negated ? `NOT (${sql})` : sql;
    }

    if (operator === 'in') {
      const items = Array.isArray(filter.value) ? filter.value : [];
      if (items.length === 0) return negated ? 'TRUE' : 'FALSE';
      const placeholders = items.map((item) => {
        values.push(item);
        return `$${values.length}`;
      });
      return `${column} ${negated ? 'NOT ' : ''}IN (${placeholders.join(', ')})`;
    }

    values.push(filter.value);
    const placeholder = `$${values.length}`;
    const operators: Record<string, string> = {
      eq: '=',
      neq: '<>',
      gt: '>',
      gte: '>=',
      lt: '<',
      lte: '<=',
      like: 'LIKE',
      ilike: 'ILIKE',
      contains: '@>',
    };
    const sqlOperator = operators[operator];
    if (!sqlOperator) throw new Error(`LOCAL_POSTGRES_FILTER_UNSUPPORTED:${operator}`);
    const valueExpression = operator === 'contains' ? `${placeholder}::jsonb` : placeholder;
    const sql = `${column} ${sqlOperator} ${valueExpression}`;
    return negated ? `NOT (${sql})` : sql;
  }

  private async execute(): Promise<QueryResult> {
    try {
      return await withOrbiTransaction(async (client) => this.executeWithClient(client), this.context);
    } catch (error) {
      return { data: null, error: normalizeError(error), count: null };
    }
  }

  private async executeWithClient(client: pg.PoolClient): Promise<QueryResult> {
    const table = `public.${quoteIdentifier(this.table)}`;
    const values: unknown[] = [];
    let sql: string;

    if (this.action === 'select') {
      const filterSql = this.buildFilterSql(values);
      if (this.head && this.countMode === 'exact') {
        const result = await client.query(`SELECT COUNT(*)::bigint AS count FROM ${table}${filterSql}`, values);
        return { data: null, error: null, count: Number(result.rows[0]?.count || 0) };
      }
      sql = `SELECT ${parseColumns(this.selection)} FROM ${table}${filterSql}`;
    } else if (this.action === 'insert' || this.action === 'upsert') {
      if (this.rows.length === 0) return { data: [], error: null, count: 0 };
      const columns = [...new Set(this.rows.flatMap((row) => Object.keys(row)))];
      const columnSql = columns.map(quoteIdentifier).join(', ');
      const rowSql = this.rows.map((row) => {
        const placeholders = columns.map((column) => {
          values.push(row[column] === undefined ? null : row[column]);
          return `$${values.length}`;
        });
        return `(${placeholders.join(', ')})`;
      });
      sql = `INSERT INTO ${table} (${columnSql}) VALUES ${rowSql.join(', ')}`;
      if (this.action === 'upsert') {
        if (this.conflictColumns.length === 0) {
          sql += ' ON CONFLICT DO NOTHING';
        } else {
          const conflictSql = this.conflictColumns.map(quoteIdentifier).join(', ');
          const updates = columns
            .filter((column) => !this.conflictColumns.includes(column))
            .map((column) => `${quoteIdentifier(column)} = EXCLUDED.${quoteIdentifier(column)}`);
          sql += ` ON CONFLICT (${conflictSql}) DO ${updates.length ? `UPDATE SET ${updates.join(', ')}` : 'NOTHING'}`;
        }
      }
    } else if (this.action === 'update') {
      const row = this.rows[0] || {};
      const assignments = Object.entries(row).map(([column, value]) => {
        values.push(value);
        return `${quoteIdentifier(column)} = $${values.length}`;
      });
      if (assignments.length === 0) return { data: null, error: null, count: 0 };
      sql = `UPDATE ${table} SET ${assignments.join(', ')}${this.buildFilterSql(values)}`;
    } else {
      sql = `DELETE FROM ${table}${this.buildFilterSql(values)}`;
    }

    if (this.action !== 'select' && this.returningRequested) {
      sql += ` RETURNING ${parseColumns(this.selection)}`;
    }
    if (this.action === 'select') {
      if (this.orderBy.length) {
        sql += ` ORDER BY ${this.orderBy
          .map((item) => `${quoteIdentifier(item.column)} ${item.ascending ? 'ASC' : 'DESC'}`)
          .join(', ')}`;
      }
      if (this.rowLimit !== null) sql += ` LIMIT ${this.rowLimit}`;
      if (this.rowOffset !== null) sql += ` OFFSET ${this.rowOffset}`;
    }

    const result = await client.query(sql, values);
    const count = this.countMode === 'exact' ? result.rowCount : null;
    if (this.singleMode) {
      if (result.rows.length === 0 && this.singleMode === 'maybeSingle') {
        return { data: null, error: null, count };
      }
      if (result.rows.length !== 1) {
        throw new Error(
          this.singleMode === 'single'
            ? `PGRST116:Expected one row, received ${result.rows.length}`
            : `PGRST116:Expected zero or one row, received ${result.rows.length}`,
        );
      }
      return { data: result.rows[0], error: null, count };
    }

    return {
      data: this.head || (this.action !== 'select' && !this.returningRequested)
        ? null
        : result.rows,
      error: null,
      count,
    };
  }
}

export class LocalPostgresClient {
  readonly auth = {
    getSession: async () => ({
      data: { session: null },
      error: null,
    }),
    admin: {
      getUserById: async (userId: string) => {
        try {
          const result = await getOrbiDatabase().query(
            `
              SELECT id, email, phone, raw_app_meta_data, raw_user_meta_data,
                     email_confirmed_at, phone_confirmed_at, created_at, updated_at
              FROM auth.users
              WHERE id = $1::uuid
            `,
            [userId],
          );
          const row = result.rows[0];
          return {
            data: {
              user: row
                ? {
                    id: row.id,
                    email: row.email,
                    phone: row.phone,
                    app_metadata: row.raw_app_meta_data || {},
                    user_metadata: row.raw_user_meta_data || {},
                    email_confirmed_at: row.email_confirmed_at,
                    phone_confirmed_at: row.phone_confirmed_at,
                    created_at: row.created_at,
                    updated_at: row.updated_at,
                  }
                : null,
            },
            error: row ? null : { message: 'USER_NOT_FOUND' },
          };
        } catch (error) {
          return { data: { user: null }, error: normalizeError(error) };
        }
      },
      updateUserById: async (userId: string, attributes: Record<string, any>) => {
        try {
          const result = await getOrbiDatabase().query(
            `
              UPDATE auth.users
              SET
                email = COALESCE($2, email),
                phone = COALESCE($3, phone),
                raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || $4::jsonb,
                raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || $5::jsonb,
                updated_at = NOW()
              WHERE id = $1::uuid
              RETURNING id, email, phone, raw_app_meta_data, raw_user_meta_data,
                        email_confirmed_at, phone_confirmed_at, created_at, updated_at
            `,
            [
              userId,
              attributes.email || null,
              attributes.phone || null,
              JSON.stringify(attributes.app_metadata || {}),
              JSON.stringify(attributes.user_metadata || {}),
            ],
          );
          const row = result.rows[0];
          return {
            data: {
              user: row
                ? {
                    id: row.id,
                    email: row.email,
                    phone: row.phone,
                    app_metadata: row.raw_app_meta_data || {},
                    user_metadata: row.raw_user_meta_data || {},
                    email_confirmed_at: row.email_confirmed_at,
                    phone_confirmed_at: row.phone_confirmed_at,
                    created_at: row.created_at,
                    updated_at: row.updated_at,
                  }
                : null,
            },
            error: row ? null : { message: 'USER_NOT_FOUND' },
          };
        } catch (error) {
          return { data: { user: null }, error: normalizeError(error) };
        }
      },
    },
  };

  constructor(private readonly context: OrbiRequestContext = { role: 'service_role' }) {}

  from(table: string) {
    return new LocalPostgresQueryBuilder(table, this.context);
  }

  async rpc(name: string, args: Record<string, unknown> = {}): Promise<QueryResult> {
    try {
      quoteIdentifier(name);
      const entries = Object.entries(args);
      return await withOrbiTransaction(async (client) => {
        const signatureResult = await client.query<{
          proargnames: string[] | null;
          argument_types: string;
          pronargs: number;
          pronargdefaults: number;
        }>(
          `
            SELECT
              p.proargnames,
              oidvectortypes(p.proargtypes) AS argument_types,
              p.pronargs,
              p.pronargdefaults
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND p.proname = $1
          `,
          [name],
        );

        const requestedNames = entries.map(([key]) => key).sort();
        const signature = signatureResult.rows.find((candidate) => {
          const inputNames = (candidate.proargnames || []).slice(0, candidate.pronargs);
          const requiredNames = inputNames.slice(
            0,
            Math.max(0, candidate.pronargs - candidate.pronargdefaults),
          );
          return requestedNames.every((value) => inputNames.includes(value))
            && requiredNames.every((value) => requestedNames.includes(value));
        });
        if (!signature) throw new Error(`LOCAL_POSTGRES_RPC_SIGNATURE_NOT_FOUND:${name}`);

        const argumentNames = (signature.proargnames || []).slice(0, signature.pronargs);
        const argumentTypes = signature.argument_types
          .split(',')
          .map((value) => value.trim());
        const typeByName = new Map(
          argumentNames.map((argumentName, index) => [argumentName, argumentTypes[index]]),
        );
        const values = entries.map(([key, value]) => {
          const argumentType = typeByName.get(key);
          if (argumentType === 'json' || argumentType === 'jsonb') {
            return JSON.stringify(value ?? null);
          }
          return value;
        });
        const namedArguments = entries
          .map(([key], index) => {
            const argumentType = typeByName.get(key);
            if (!argumentType || !/^[A-Za-z0-9_ ."\[\]]+$/.test(argumentType)) {
              throw new Error(`LOCAL_POSTGRES_RPC_TYPE_UNSAFE:${name}:${key}`);
            }
            return `${quoteIdentifier(key)} => $${index + 1}::${argumentType}`;
          })
          .join(', ');
        const result = await client.query(
          `SELECT * FROM public.${quoteIdentifier(name)}(${namedArguments})`,
          values,
        );
        if (result.rows.length === 1 && result.fields.length === 1 && result.fields[0].name === name) {
          return { data: result.rows[0][name], error: null };
        }
        return { data: result.rows, error: null };
      }, this.context);
    } catch (error) {
      return { data: null, error: normalizeError(error) };
    }
  }
}

let serviceClient: LocalPostgresClient | null = null;

export const getLocalPostgresClient = (): LocalPostgresClient => {
  if (!serviceClient) serviceClient = new LocalPostgresClient({ role: 'service_role' });
  return serviceClient;
};

export const createLocalAuthenticatedClient = (
  context: OrbiRequestContext,
): LocalPostgresClient => new LocalPostgresClient(context);

export const pingLocalPostgres = async (): Promise<boolean> => {
  const result = await getOrbiDatabase().query('SELECT 1 AS ok');
  return result.rows[0]?.ok === 1;
};
