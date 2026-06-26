import { createClient, SupabaseClient } from '@supabase/supabase-js';
import {
    createLocalAuthenticatedClient,
    getLocalPostgresClient,
} from './localPostgresClient.js';

const resolveEnvValue = (key: string): string | undefined => {
    if (typeof process !== 'undefined' && process.env) {
        return process.env[key];
    }
    return undefined;
};

const supabaseUrl = resolveEnvValue('SUPABASE_URL');
const supabaseKey = resolveEnvValue('SUPABASE_ANON_KEY');
const supabaseServiceKey = resolveEnvValue('SUPABASE_SERVICE_ROLE_KEY');
const usesLocalPostgres = String(resolveEnvValue('ORBI_DATA_PROVIDER') || '')
    .trim()
    .toLowerCase() === 'local';

let supabaseInstance: SupabaseClient | null = null;
let supabaseAdminInstance: SupabaseClient | null = null;

if (supabaseUrl && supabaseKey && supabaseUrl !== 'undefined') {
    try {
        supabaseInstance = createClient(supabaseUrl, supabaseKey, {
            auth: {
                persistSession: false,
                autoRefreshToken: true
            }
        });
        console.info("[System] Headless Cloud Link Initialized.");
    } catch (error) {
        console.error("[System] Cloud Link Fault.");
    }
}

if (supabaseUrl && supabaseServiceKey && supabaseUrl !== 'undefined') {
    try {
        supabaseAdminInstance = createClient(supabaseUrl, supabaseServiceKey, {
            auth: {
                persistSession: false,
                autoRefreshToken: false
            }
        });
        console.info("[System] Admin Cloud Link Initialized.");
    } catch (error) {
        console.error("[System] Admin Cloud Link Fault.");
    }
}

export const getSupabase = (): SupabaseClient | null => {
    if (usesLocalPostgres) return getLocalPostgresClient() as unknown as SupabaseClient;
    return supabaseInstance;
};

export const getAdminSupabase = (): SupabaseClient | null => {
    if (usesLocalPostgres) return getLocalPostgresClient() as unknown as SupabaseClient;
    return supabaseAdminInstance;
};

export const createAuthenticatedClient = (token: string): SupabaseClient | null => {
    if (usesLocalPostgres) {
        const parts = token.split('.');
        if (parts.length !== 3) return null;
        try {
            const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
            return createLocalAuthenticatedClient({
                userId: typeof payload.sub === 'string' ? payload.sub : null,
                role: typeof payload.role === 'string' ? payload.role : 'authenticated',
                claims: payload,
            }) as unknown as SupabaseClient;
        } catch {
            return null;
        }
    }
    if (supabaseUrl && supabaseKey) {
        return createClient(supabaseUrl, supabaseKey, {
            global: {
                headers: { Authorization: `Bearer ${token}` }
            },
            auth: {
                persistSession: false,
                autoRefreshToken: false
            }
        });
    }
    return null;
};
