
import { Audit } from '../security/audit.js';
import { orbiGatewayService } from './orbiGatewayService.js';
import { Messaging } from '../features/MessagingService.js';

/**
 * SENTINEL MONITORING SERVICE (V1.0)
 * ----------------------------------
 * Handles real-time alerting for critical system events via ORBI GATEWAY.
 */
export class MonitoringService {
    private static ADMIN_EMAIL = process.env.ADMIN_ALERT_EMAIL || 'admin@orbi.io';
    private static ADMIN_PHONE = process.env.ADMIN_ALERT_PHONE;

    /**
     * SENDS A CRITICAL ALERT
     * Used for ledger discrepancies, security breaches, or system failures.
     */
    public static async notifyCritical(title: string, details: any) {
        const message = `🚨 *CRITICAL ALERT: ${title}* 🚨\n\n` +
                        `*Time:* ${new Date().toISOString()}\n` +
                        `*Details:* \`\`\`${JSON.stringify(details, null, 2)}\`\`\`\n` +
                        `*Action Required:* Immediate forensic investigation.`;

        console.error(`[Monitoring] CRITICAL: ${title}`, details);

        // Log to internal audit first
        await Audit.log('SECURITY', 'system', 'CRITICAL_MONITORING_ALERT', { title, details });

        // Route through Messaging Service for direct-to-app + escalation
        try {
            // We use 'system-admin' as a virtual ID, MessagingService should handle it or we fallback
            await Messaging.dispatch(
                'system-admin', 
                'security', 
                `🚨 CRITICAL: ${title}`, 
                message,
                { email: true, sms: !!this.ADMIN_PHONE, push: true }
            );
        } catch (e) {
            console.error('[Monitoring] Messaging dispatch failed, falling back to direct Gateway calls', e);
            // Fallback to direct Orbi Gateway calls if dispatch fails (e.g. user not found)
            await orbiGatewayService.sendEmail(
                this.ADMIN_EMAIL,
                `🚨 CRITICAL: ${title}`,
                message,
                undefined,
                'en',
                undefined,
                undefined,
                `alert-email-${Date.now()}`
            );

            if (this.ADMIN_PHONE) {
                await orbiGatewayService.sendSms(
                    this.ADMIN_PHONE,
                    `🚨 CRITICAL ORBI ALERT: ${title}. Check admin email for details.`,
                    'en',
                    undefined,
                    undefined,
                    `alert-sms-${Date.now()}`
                );
            }
        }
    }

    /**
     * SENDS A SYSTEM HEALTH UPDATE
     * Used for daily reports or successful reconciliation runs.
     */
    public static async notifyInfo(title: string, details: any) {
        console.info(`[Monitoring] INFO: ${title}`, details);
        
        // Route through Messaging Service
        try {
            await Messaging.dispatch(
                'system-admin',
                'info',
                `ℹ️ System Info: ${title}`,
                JSON.stringify(details),
                { email: true }
            );
        } catch (e) {
            console.error('[Monitoring] Messaging info dispatch failed, falling back to direct Gateway calls', e);
            await orbiGatewayService.sendEmail(
                this.ADMIN_EMAIL,
                `ℹ️ System Info: ${title}`,
                JSON.stringify(details),
                undefined,
                'en',
                undefined,
                undefined,
                `info-${Date.now()}`
            );
        }
    }
}
