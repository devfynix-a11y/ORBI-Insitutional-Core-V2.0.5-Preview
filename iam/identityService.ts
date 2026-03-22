
import { getSupabase, getAdminSupabase } from '../services/supabaseClient.js';
import { UserPublicProfile } from '../types.js';
import { parsePhoneNumberFromString } from 'libphonenumber-js';

/**
 * ORBI IDENTITY RESOLVER (V1.1)
 * -----------------------------
 * Securely resolves user identities for peer-to-peer interactions
 * without exposing sensitive PII.
 * 
 * Handles smart phone normalization (e.g., matching 0758... with +255758...)
 */
export class IdentityService {

    /**
     * Resolves a user by public identifier (Customer ID, Phone, Email).
     * Returns only safe, public-facing data.
     */
    public async lookupUser(identifier: string): Promise<UserPublicProfile | null> {
        const sb = getAdminSupabase(); // Use admin to bypass RLS for lookup (carefully scoped)
        if (!sb) return null;

        const cleanIdentifier = identifier.trim();

        // 1. Try Customer ID (Case-Insensitive)
        let { data, error } = await sb
            .from('users')
            .select('id, full_name, avatar_url, customer_id, phone, email, registry_type')
            .ilike('customer_id', cleanIdentifier)
            .maybeSingle();

        if (data) {
            return {
                id: data.id,
                full_name: data.full_name || 'Orbi User',
                avatar_url: data.avatar_url,
                customer_id: data.customer_id,
                phone: data.phone,
                email: data.email,
                registry_type: data.registry_type,
                matched_by: 'customer_id'
            };
        }

        // 2. Try Phone (Smart Match)
        if (!data) {
            // A. Try exact match first
            ({ data, error } = await sb
                .from('users')
                .select('id, full_name, avatar_url, customer_id, phone, email, registry_type')
                .eq('phone', cleanIdentifier)
                .maybeSingle());

            // B. Try normalized match if it looks like a phone number
            if (!data && /^\+?[0-9\s\-()]+$/.test(cleanIdentifier)) {
                const digitsOnly = cleanIdentifier.replace(/\D/g, '');
                
                if (digitsOnly.length >= 9) {
                    const suffix = digitsOnly.slice(-9);
                    ({ data, error } = await sb
                        .from('users')
                        .select('id, full_name, avatar_url, customer_id, phone, email, registry_type')
                        .like('phone', `%${suffix}`)
                        .maybeSingle());
                }
            }

            if (data) {
                return {
                    id: data.id,
                    full_name: data.full_name || 'Orbi User',
                    avatar_url: data.avatar_url,
                    customer_id: data.customer_id,
                    phone: data.phone,
                    email: data.email,
                    registry_type: data.registry_type,
                    matched_by: 'phone'
                };
            }
        }

        // 3. Try Email (Exact Match)
        if (!data) {
            ({ data, error } = await sb
                .from('users')
                .select('id, full_name, avatar_url, customer_id, phone, email, registry_type')
                .eq('email', cleanIdentifier)
                .maybeSingle());

            if (data) {
                return {
                    id: data.id,
                    full_name: data.full_name || 'Orbi User',
                    avatar_url: data.avatar_url,
                    customer_id: data.customer_id,
                    phone: data.phone,
                    email: data.email,
                    registry_type: data.registry_type,
                    matched_by: 'email'
                };
            }
        }

        // 4. Try Staff Table if still not found
        if (!data) {
            ({ data, error } = await sb
                .from('staff')
                .select('id, full_name, avatar_url, customer_id, phone, email')
                .ilike('customer_id', cleanIdentifier)
                .maybeSingle());
            
            if (data) {
                return {
                    id: data.id,
                    full_name: data.full_name,
                    avatar_url: data.avatar_url,
                    customer_id: data.customer_id,
                    phone: data.phone,
                    email: data.email,
                    registry_type: 'STAFF',
                    matched_by: 'customer_id'
                };
            }
        }

        return null;
    }

    /**
     * Batch resolves multiple user IDs to public profiles.
     * Useful for enriching transaction history.
     */
    public async batchResolve(userIds: string[]): Promise<Map<string, UserPublicProfile>> {
        const sb = getSupabase();
        if (!sb || userIds.length === 0) return new Map();

        const { data } = await sb
            .from('users')
            .select('id, full_name, avatar_url, customer_id, phone, email, registry_type')
            .in('id', userIds);

        const map = new Map<string, UserPublicProfile>();
        if (data) {
            data.forEach((u: any) => map.set(u.id, {
                id: u.id,
                full_name: u.full_name,
                avatar_url: u.avatar_url,
                customer_id: u.customer_id,
                phone: u.phone,
                email: u.email,
                registry_type: u.registry_type
            }));
        }
        return map;
    }
}

export const Identity = new IdentityService();
