import { createClient, SupabaseClient } from '@supabase/supabase-js';

const resolveEnvValue = (key: string): string | undefined => {
    if (typeof process !== 'undefined' && process.env) {
        return process.env[key];
    }
    return undefined;
};

const supabaseUrl = resolveEnvValue('SUPABASE_URL');
const supabaseKey = resolveEnvValue('SUPABASE_ANON_KEY');
const supabaseServiceKey = resolveEnvValue('SUPABASE_SERVICE_ROLE_KEY');

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

export const getSupabase = (): SupabaseClient | null => supabaseInstance;
export const getAdminSupabase = (): SupabaseClient | null => supabaseAdminInstance;

export const createAuthenticatedClient = (token: string): SupabaseClient | null => {
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
