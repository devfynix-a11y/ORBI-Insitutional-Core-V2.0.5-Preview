import { getAdminSupabase } from '../../services/supabaseClient.js';
import { UUID } from '../../services/utils.js';
import { Transaction } from '../../types.js';
import { FXEngine } from '../ledger/FXEngine.js';
import { ConfigClient } from '../infrastructure/RulesConfigClient.js';
import { orbiTalkGatewayService } from '../infrastructure/orbiTalkGatewayService.js';
import { operatorAlertService } from '../infrastructure/OperatorAlertService.js';
import { Audit } from './audit.js';

export interface AMLAlert {
    id: string;
    transaction_id: string;
    user_id: string;
    risk_score: number;
    reason: string;
    status: 'PENDING' | 'INVESTIGATING' | 'CLEARED' | 'BLOCKED';
    created_at: string;
}

export class RiskComplianceEngine {
    
    /**
     * Transaction Monitoring for AML (Anti-Money Laundering)
     * Checks a transaction against rules and flags it if suspicious.
     */
    static async monitorTransaction(tx: Transaction): Promise<AMLAlert | null> {
        let riskScore = 0;
        let reasons: string[] = [];
        const sb = getAdminSupabase();

        if (!sb) {
            console.error("[AML] Critical Fault: Database offline. Cannot monitor transaction.");
            return null;
        }

        // Normalize amount to USD for consistent AML rule checking
        const txCurrency = (tx.currency || '').toUpperCase();
        if (!txCurrency) {
            throw new Error('CURRENCY_REQUIRED: Transaction currency is required for AML checks.');
        }
        const amountInUSD = await FXEngine.convertToUSD(tx.amount, txCurrency);

        // Rule 1: High value transaction (Normalized to USD)
        if (amountInUSD > 10000) {
            riskScore += 50;
            reasons.push(`High value transaction exceeding $10,000 USD (Original: ${tx.amount} ${txCurrency}, Eqv: $${amountInUSD.toFixed(2)} USD)`);
        }

        await this.dispatchDynamicBrokerNotification(tx, amountInUSD, txCurrency).catch((error) => {
            console.error('[AML] Dynamic broker notification dispatch failed:', error);
        });

        // Rule 2: Structuring / Smurfing (Transactions just below reporting threshold)
        if (amountInUSD >= 9000 && amountInUSD <= 10000) {
            riskScore += 40;
            reasons.push(`Potential structuring: Amount $${amountInUSD.toFixed(2)} USD is just below the $10,000 reporting threshold`);
        }

        // Rule 3: Rapid successive transactions (Velocity Check)
        if (tx.user_id) {
            try {
                // Check transactions in the last 24 hours
                const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
                const { data: recentTxs, error } = await sb
                    .from('transactions')
                    .select('id, amount, currency')
                    .eq('user_id', tx.user_id)
                    .gte('created_at', oneDayAgo);

                if (!error && recentTxs) {
                    // Check transaction count
                    if (recentTxs.length >= 5) {
                        riskScore += 30;
                        reasons.push(`High transaction velocity: ${recentTxs.length} transactions in the last 24 hours`);
                    }
                    
                    // Check cumulative volume in USD
                    let volumeUSD = 0;
                    for (const rTx of recentTxs) {
                        const relatedCurrency = (rTx.currency || '').toUpperCase();
                        if (!relatedCurrency) {
                            throw new Error('CURRENCY_REQUIRED: Historical transaction currency is required for AML checks.');
                        }
                        volumeUSD += await FXEngine.convertToUSD(Number(rTx.amount || 0), relatedCurrency);
                    }
                    
                    if (volumeUSD + amountInUSD > 15000) {
                        riskScore += 40;
                        reasons.push(`High cumulative volume: Exceeded $15,000 USD in the last 24 hours (Total Eqv: $${(volumeUSD + amountInUSD).toFixed(2)} USD)`);
                    }
                }
            } catch (e) {
                console.error("[AML] Velocity check failed:", e);
            }
        }

        // Rule 4: Cross-border or high-risk jurisdictions
        const highRiskCountries = ['PRK', 'IRN', 'SYR', 'CUB', 'MMR', 'AFG', 'SSD'];
        const txCountry = tx.metadata?.country || tx.metadata?.destination_country;
        if (txCountry && highRiskCountries.includes(String(txCountry).toUpperCase())) {
            riskScore += 80;
            reasons.push(`High-risk jurisdiction involved: ${txCountry}`);
        }

        // Rule 5: Unusual time of transaction (e.g., flagged by client metadata)
        if (tx.metadata?.is_unusual_time) {
            riskScore += 20;
            reasons.push("Transaction flagged as occurring at an unusual time");
        }

        // Generate alert if risk score is significant (e.g., >= 50)
        if (riskScore >= 50) {
            const alert: AMLAlert = {
                id: UUID.generate(),
                transaction_id: String(tx.id),
                user_id: tx.user_id || 'UNKNOWN',
                risk_score: riskScore,
                reason: reasons.join(' | '),
                status: 'PENDING',
                created_at: new Date().toISOString()
            };

            await this.logAMLAlert(alert);
            await this.applyAutoFreezeIfConfigured(tx, riskScore, reasons, amountInUSD).catch((error) => {
                console.error('[AML] Auto-freeze enforcement failed:', error);
            });
            return alert;
        }

        return null;
    }

    /**
     * Log an AML alert to the database
     */
    static async logAMLAlert(alert: AMLAlert) {
        const sb = getAdminSupabase();
        if (sb) {
            await sb.from('aml_alerts').insert(alert);
        } else {
            console.error("[AML] Critical Fault: Database offline. Cannot log alert.", alert);
        }
    }

    private static async dispatchDynamicBrokerNotification(tx: Transaction, amountInUSD: number, txCurrency: string) {
        const config = await ConfigClient.getRuleConfig();
        const brokerConfig = config?.broker_notifications || config?.rules?.broker_notifications;
        if (!brokerConfig || brokerConfig.enabled === false) return;

        const thresholdUsd = Number(brokerConfig.thresholdUsd || 0);
        if (!thresholdUsd || amountInUSD < thresholdUsd) return;

        const transactionId = String(tx.id || 'UNKNOWN');
        const eventCode = String(brokerConfig.eventCode || 'DYNAMIC_BROKER_LIMIT_EXCEEDED');
        const amountLabel = `${Number(tx.amount || 0).toLocaleString()} ${txCurrency}`;
        const usdLabel = `$${amountInUSD.toLocaleString(undefined, { maximumFractionDigits: 2 })}`;
        const thresholdLabel = `$${thresholdUsd.toLocaleString(undefined, { maximumFractionDigits: 2 })}`;
        const subject = `ORBI high-value transaction alert ${transactionId}`;
        const body = [
            `${eventCode}: Single transaction amount exceeded the dynamic broker threshold.`,
            `Transaction: ${transactionId}`,
            `Actor: ${tx.user_id || 'UNKNOWN'}`,
            `Amount: ${amountLabel} (${usdLabel} USD equivalent)`,
            `Threshold: ${thresholdLabel}`,
            `Type: ${tx.type || 'UNKNOWN'}`,
            `Status: ${tx.status || 'UNKNOWN'}`,
            `Time: ${new Date().toISOString()}`,
        ].join('\n');

        await Audit.log('SECURITY', tx.user_id || 'system', eventCode, {
            transactionId,
            amount: tx.amount,
            currency: txCurrency,
            amountUsd: amountInUSD,
            thresholdUsd,
            emailEnabled: brokerConfig.email?.enabled === true,
            slackEnabled: brokerConfig.slack?.enabled === true,
            slackChannel: brokerConfig.slack?.channel || null,
        }, transactionId);

        await operatorAlertService.create({
            title: `High-value transaction exceeded ${thresholdLabel}`,
            body,
            severity: amountInUSD >= thresholdUsd * 2 ? 'CRITICAL' : 'HIGH',
            eventCode,
            actorId: tx.user_id || null,
            transactionId,
            resourceType: 'transaction',
            resourceId: transactionId,
            metadata: {
                amount: tx.amount,
                currency: txCurrency,
                amountUsd: amountInUSD,
                thresholdUsd,
                transactionType: tx.type,
                status: tx.status,
            },
            actions: [
                { id: 'review-transaction', label: 'Review transaction', type: 'navigate', target: 'transactions', payload: { search: transactionId } },
                { id: 'open-risk', label: 'Open risk dashboard', type: 'navigate', target: 'risk' },
                { id: 'open-case', label: 'Create support case', type: 'open_case', target: 'support', payload: { transactionId } },
            ],
        });

        const emailRecipients = Array.isArray(brokerConfig.email?.recipients)
            ? brokerConfig.email.recipients.filter(Boolean)
            : [];
        if (brokerConfig.email?.enabled === true && emailRecipients.length > 0) {
            await Promise.allSettled(emailRecipients.map((recipient: string) =>
                orbiTalkGatewayService.sendEmail(
                    recipient,
                    subject,
                    body,
                    undefined,
                    'en',
                    undefined,
                    undefined,
                    `${eventCode.toLowerCase()}-${transactionId}-${Date.now()}`
                )
            ));
        }

        if (brokerConfig.slack?.enabled === true) {
            await this.sendSlackBrokerNotification(body, brokerConfig.slack?.channel);
        }
    }

    private static async sendSlackBrokerNotification(text: string, channel?: string) {
        const webhookUrl = process.env.ORBI_SLACK_WEBHOOK_URL || process.env.SLACK_WEBHOOK_URL;
        if (!webhookUrl) {
            console.warn('[AML] Slack broker notification enabled but no ORBI_SLACK_WEBHOOK_URL is configured.');
            return;
        }

        const response = await fetch(webhookUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                text,
                ...(channel ? { channel } : {}),
            }),
        });

        if (!response.ok) {
            throw new Error(`SLACK_WEBHOOK_FAILED_${response.status}`);
        }
    }

    private static async applyAutoFreezeIfConfigured(tx: Transaction, riskScore: number, reasons: string[], amountInUSD: number) {
        const config = await ConfigClient.getRuleConfig();
        const autoFreeze = config?.auto_freeze || config?.rules?.auto_freeze;
        if (!autoFreeze || autoFreeze.enabled !== true) return;

        const threshold = Number(autoFreeze.riskScoreThreshold || 90);
        if (!threshold || riskScore < threshold) return;
        if (!tx.user_id) return;

        const sb = getAdminSupabase();
        if (!sb) return;

        const action = String(autoFreeze.action || 'SUSPEND_USER').toUpperCase();
        const shouldFreeze = action !== 'REQUIRE_REVIEW';

        if (shouldFreeze) {
            const statusReason = `Auto-freeze triggered by transaction ${tx.id}: risk score ${riskScore} met configured threshold ${threshold}. ${reasons.join(' | ')}`;
            const statusPatch = {
                account_status: 'frozen',
                status_reason: statusReason,
                status_reason_code: 'AUTO_FREEZE_RISK_THRESHOLD',
                status_changed_at: new Date().toISOString(),
                status_changed_by: 'orbi-risk-engine',
            };
            await Promise.allSettled([
                sb.from('users').update(statusPatch).eq('id', tx.user_id),
                sb.from('staff').update(statusPatch).eq('id', tx.user_id),
            ]);
        }

        await Audit.log('SECURITY', tx.user_id, 'AUTO_FREEZE_RISK_THRESHOLD_TRIGGERED', {
            transactionId: tx.id,
            riskScore,
            threshold,
            amountUsd: amountInUSD,
            reasons,
            action,
            accountFrozen: shouldFreeze,
        }, String(tx.id));

        await operatorAlertService.create({
            title: shouldFreeze ? `Account auto-frozen after risk score ${riskScore}` : `Manual review required after risk score ${riskScore}`,
            body: `ORBI ${shouldFreeze ? 'auto-froze' : 'flagged'} account ${tx.user_id} because transaction ${tx.id} reached risk score ${riskScore}, meeting the configured threshold ${threshold}. Reasons: ${reasons.join(' | ')}`,
            severity: 'CRITICAL',
            eventCode: 'AUTO_FREEZE_RISK_THRESHOLD_TRIGGERED',
            actorId: tx.user_id,
            transactionId: String(tx.id),
            resourceType: 'user',
            resourceId: tx.user_id,
            targetRoles: Array.isArray(autoFreeze.targetRoles) ? autoFreeze.targetRoles : ['SUPER_ADMIN', 'ADMIN', 'RISK_OFFICER', 'FRAUD'],
            metadata: {
                riskScore,
                threshold,
                amountUsd: amountInUSD,
                reasons,
                action,
                accountFrozen: shouldFreeze,
            },
            actions: [
                { id: 'review-user', label: 'Review user', type: 'navigate', target: 'users', payload: { search: tx.user_id } },
                { id: 'review-transaction', label: 'Review transaction', type: 'navigate', target: 'transactions', payload: { search: String(tx.id) } },
                { id: 'resolve-alert', label: 'Mark resolved', type: 'resolve' },
            ],
        });
    }

    /**
     * Get pending AML alerts
     */
    static async getPendingAlerts(): Promise<AMLAlert[]> {
        const sb = getAdminSupabase();
        if (sb) {
            const { data } = await sb.from('aml_alerts').select('*').eq('status', 'PENDING');
            return data || [];
        }
        return [];
    }

    /**
     * Update AML alert status
     */
    static async updateAlertStatus(alertId: string, status: 'INVESTIGATING' | 'CLEARED' | 'BLOCKED') {
        const sb = getAdminSupabase();
        if (sb) {
            await sb.from('aml_alerts').update({ status }).eq('id', alertId);
        }
    }

    /**
     * Generate Regulatory Report (e.g., Suspicious Activity Report - SAR)
     */
    static async generateRegulatoryReport(startDate: string, endDate: string) {
        const sb = getAdminSupabase();
        let alerts: AMLAlert[] = [];
        
        if (sb) {
            const { data } = await sb.from('aml_alerts')
                .select('*')
                .gte('created_at', startDate)
                .lte('created_at', endDate);
            alerts = data || [];
        }

        return {
            report_id: UUID.generate(),
            period: { start: startDate, end: endDate },
            total_alerts: alerts.length,
            high_risk_alerts: alerts.filter(a => a.risk_score >= 50).length,
            blocked_transactions: alerts.filter(a => a.status === 'BLOCKED').length,
            generated_at: new Date().toISOString()
        };
    }
}
