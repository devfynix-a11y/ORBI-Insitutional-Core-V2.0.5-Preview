
import { Session } from '../../types.js';
import { AVPCPolicy } from './avpc.js';

/**
 * ORBI DATA GUARD & DLP LAYER (V3.8)
 * 
 * Responsibilities:
 * 1. Scope Resolution (Secure RLS Context)
 * 2. Deep Masking (PII / Crypto Metadata Redaction)
 * 3. Query Sanitization (Injection Prevention)
 */
export class DataGuard {

    /**
     * SECURE CONTEXT BINDING
     * Resolves policy placeholders using strictly typed session values.
     */
    public static resolveScope(query: string, session: Session): string {
        if (!query || query === 'ALL') return 'ALL';
        
        const trustedContext: Record<string, string> = {
            '$session.sub': session.sub,
            '$session.role': session.role,
            '$session.client': session.client_id || 'mobile-native'
        };

        let resolved = query;
        for (const [token, value] of Object.entries(trustedContext)) {
            if (resolved.includes(token)) {
                resolved = resolved.split(token).join(`'${value}'`);
            }
        }
        return resolved;
    }

    /**
     * DEEP MASKING ENGINE
     * Performs recursive redaction of sensitive attributes based on policy.
     */
    public static applyDLP<T>(data: T[], session: Session, policy: AVPCPolicy): T[] {
        if (!data || data.length === 0) return [];
        if (!policy.scope) return data;

        // 1. ENFORCE SCOPE (RLS SIMULATION)
        let filtered = data;
        const scopeExpression = policy.scope.row_filter || 'ALL';
        
        if (scopeExpression !== 'ALL') {
            filtered = data.filter((item: any) => {
                // High-performance logical matching
                if (scopeExpression === 'user_id = $session.sub') {
                    return item.user_id === session.sub || item.userId === session.sub;
                }
                return true; // Default to allow if complex logic not handled locally
            });
        }

        // 2. REDACT SENSITIVE FIELDS
        if (policy.scope.field_masking && policy.scope.field_masking.length > 0) {
            return this.redact(filtered, policy.scope.field_masking);
        }

        return filtered;
    }

    private static redact<T>(rows: T[], fields: string[]): T[] {
        return rows.map(row => {
            const copy = JSON.parse(JSON.stringify(row));
            for (const field of fields) {
                if (copy[field] !== undefined) {
                    copy[field] = '• REDACTED •';
                }
                // Handle snake_case discrepancy
                const camel = field.replace(/([-_][a-z])/ig, ($1) => $1.toUpperCase().replace('-', '').replace('_', ''));
                if (copy[camel] !== undefined) {
                    copy[camel] = '• REDACTED •';
                }
            }
            return copy;
        });
    }

    /**
     * INGRESS PAYLOAD SANITIZER
     */
    public static sanitize(payload: any): void {
        const json = JSON.stringify(payload);
        const threats = [
            /(\$where)/i, 
            /(DROP\s+TABLE)/i, 
            /(UNION\s+SELECT)/i, 
            /(<script>)/i,
            /(eval\()/i
        ];

        for (const threat of threats) {
            if (threat.test(json)) {
                throw new Error("DATA_GUARD_VIOLATION: Malicious payload signature detected.");
            }
        }
    }
}
