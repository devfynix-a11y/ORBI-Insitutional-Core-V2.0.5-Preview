
/**
 * ORBI VIRTUAL PRIVATE CONTEXT (VPC) FIREWALL (V3.5)
 * Enforces deep packet inspection and Data Loss Prevention (DLP) for all cross-node traffic.
 * Optimized for high-throughput ledger synchronization with trusted node whitelisting.
 */

// Trusted operations that are explicitly allowed to return decrypted sensitive data
const TRUSTED_EGRESS_NODES = new Set([
    'data_load_all',
    'data_profile_upd',
    'data_discovery',
    'data_activity_read',
    'data_usr_msgs',
    'data_sys_msgs',
    'ledger_audit_read',
    'ledger_tx_view',
    'wealth_wallet_get'
]);

export const VPCLayer = {
    config: {
        active: true,
        maxPacketSize: 1024 * 1024 * 5, // 5MB limit for synchronizing large encrypted ledgers
        trustedOrigins: ['127.0.0.1', 'api.supabase.co', 'orbi.auth'],
    },

    /**
     * INGRESS INSPECTION
     * Analyzes incoming data packets for security compliance and payload integrity.
     */
    inspectIngress: async (payload: any, context: string) => {
        if (!VPCLayer.config.active) return true;
        
        const size = JSON.stringify(payload).length;
        if (size > VPCLayer.config.maxPacketSize) { 
            throw new Error(`VPC_OVERFLOW: Ingress packet [${size}b] exceeds node capacity.`);
        }

        // Entropy Check: Enforce minimum signature requirements for authentication packets
        if (context === 'auth_ingress' && payload.p && payload.p.length < 8) {
            throw new Error("VPC_POLICY_REJECTION: Insufficient payload entropy.");
        }

        return true;
    },

    /**
     * EGRESS PROTECTION (DLP)
     * Intercepts outgoing data to prevent accidental exfiltration of PII (Personally Identifiable Information).
     * Bypasses checks for authorized internal retrieval nodes.
     */
    inspectEgress: async (data: any, destination: string) => {
        if (!VPCLayer.config.active) return true;

        // 1. TRUSTED NODE BYPASS
        // Internal data loading operations are exempt from string-based DLP detection 
        // to allow legitimate account numbers and IDs to flow to the authenticated client.
        const opId = (destination || '').trim();
        if (TRUSTED_EGRESS_NODES.has(opId)) {
            return true;
        }

        const packet = JSON.stringify(data);
        
        // 2. CREDIT CARD PATTERN (DLP-01)
        // Scans for 13-16 digit numbers matching international CC issuance patterns.
        const ccPattern = /\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|6(?:011|5[0-9]{2})[0-9]{12}|(?:2131|1800|35\d{3})\d{11})\b/;
        
        if (ccPattern.test(packet)) {
            // Verify if the data is in the clear (doesn't contain our internal 'enc_v' encryption prefix)
            if (!packet.includes('enc_v')) {
                console.error(`[VPC:DLP] Critical: Intercepted unencrypted PII egress to ${opId}.`);
                throw new Error("VPC_DLP_VIOLATION: Data exfiltration blocked.");
            }
        }

        // 3. IDENTITY NODE LEAK (DLP-02)
        // Prevents privilege escalation by blocking raw role data egress to non-auth destinations.
        if (packet.includes('"role":"SUPER_ADMIN"') && !opId.includes('orbi.auth') && opId !== 'data_load_all') {
             throw new Error("VPC_DLP_VIOLATION: Administrative context leak intercepted.");
        }

        return true;
    }
};
