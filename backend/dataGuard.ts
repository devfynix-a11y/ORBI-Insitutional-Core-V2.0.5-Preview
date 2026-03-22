
import { Session } from '../types.js';
import { AVPCPolicy } from './avpc.js';

/**
 * DATA GUARD LAYER
 * 
 * Golden Rule: No service talks to DB directly without passing through here.
 * Responsibilities:
 * 1. Scope Enforcement (Row Level Security)
 * 2. Field Masking (DLP)
 * 3. Query Sanitization
 */
export class DataGuard {

    /**
     * Wraps a read operation with security controls.
     * @param data The raw data fetched from storage/DB
     * @param session The user session requesting data
     * @param policy The egress policy defining scope
     */
    public static applyEgressFilter<T>(data: T[], session: Session, policy: AVPCPolicy): T[] {
        if (!data || data.length === 0) return [];

        // 1. Row Scope (Filter)
        // Simulate SQL WHERE clause logic in memory for the hybrid backend
        let filteredData = data;
        
        if (policy.scope?.row_filter) {
            if (policy.scope.row_filter === 'user_id = $session.sub') {
                // Strict ownership check
                filteredData = data.filter((item: any) => item.user_id === session.sub || item.userId === session.sub);
            } 
            else if (policy.scope.row_filter === 'ALL') {
                // Admin/System Access - No filter
            }
            else {
                // Default fail-safe
                console.warn(`DataGuard: Unknown filter '${policy.scope.row_filter}'. Applying strict default.`);
                filteredData = data.filter((item: any) => item.user_id === session.sub);
            }
        }

        // 2. Field Masking (Projection)
        if (policy.scope?.field_masking && policy.scope.field_masking.length > 0) {
            return filteredData.map(item => {
                const maskedItem = { ...item };
                policy.scope!.field_masking!.forEach(field => {
                    if ((maskedItem as any)[field]) {
                        // Apply masking (e.g. replace with stars or remove)
                        (maskedItem as any)[field] = '********'; // DLP Redaction
                        // Or simply delete: delete (maskedItem as any)[field];
                    }
                });
                return maskedItem;
            });
        }

        return filteredData;
    }

    /**
     * Validates input data before writing to persistence.
     * Prevents SQL Injection patterns in NoSQL/JSON blobs and enforces structure.
     */
    public static validateIngressData(data: any): boolean {
        const json = JSON.stringify(data);
        
        // Block Dangerous Patterns (Simulated SQLi/NoSQLi)
        const dangerousPatterns = [
            /(\$where)/i,       // Mongo injection
            /(;DROP TABLE)/i,   // SQL injection
            /(OR 1=1)/i,        // Logic bypass
            /(<script>)/i       // XSS storage
        ];

        for (const pattern of dangerousPatterns) {
            if (pattern.test(json)) {
                throw new Error("DataGuard: Malicious payload detected in write operation.");
            }
        }

        return true;
    }
}
