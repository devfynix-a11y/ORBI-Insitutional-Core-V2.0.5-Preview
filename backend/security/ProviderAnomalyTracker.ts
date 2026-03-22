
import { Transaction, AuditEventType } from '../../types.js';
import { Audit } from './audit.js';
import { Messaging } from '../features/MessagingService.js';
import { getSupabase } from '../../services/supabaseClient.js';
import { SocketRegistry } from '../infrastructure/SocketRegistry.js';

/**
 * ORBI PROVIDER ANOMALY TRACKER (V5.5)
 * ------------------------------------
 * Advanced heuristic and statistical engine for detecting provider-level 
 * and transaction-level deviations.
 */
export class ProviderAnomalyTrackerService {
    
    /**
     * ANALYZE TRANSACTION
     * Performs multi-dimensional statistical analysis on a new transaction.
     */
    public async analyze(tx: Transaction, history: Transaction[]): Promise<{ isAnomaly: boolean, score: number, flags: string[] }> {
        const flags: string[] = [];
        let anomalyScore = 0;

        // 1. Z-Score Statistical Outlier Detection (Amount)
        const providerTxs = history.filter(t => t.walletId === tx.walletId);
        if (providerTxs.length > 10) {
            const amounts = providerTxs.map(t => t.amount);
            const mean = amounts.reduce((a, b) => a + b, 0) / amounts.length;
            const stdDev = Math.sqrt(amounts.map(x => Math.pow(x - mean, 2)).reduce((a, b) => a + b, 0) / amounts.length);
            
            const zScore = Math.abs((tx.amount - mean) / (stdDev || 1));
            if (zScore > 3) {
                anomalyScore += 40;
                flags.push(`STATISTICAL_OUTLIER_Z${zScore.toFixed(2)}`);
            }
        }

        // 2. Velocity Burst Detection
        const oneHourAgo = new Date(Date.now() - 3600000).getTime();
        const recentTxs = history.filter(t => new Date(t.date).getTime() > oneHourAgo);
        if (recentTxs.length > 20) {
            anomalyScore += 30;
            flags.push('HIGH_VELOCITY_CLUSTER');
        }

        // 3. Time-of-Day Heuristics
        const hour = new Date(tx.date).getHours();
        if (hour >= 1 && hour <= 4) {
            anomalyScore += 15;
            flags.push('UNUSUAL_HOUR_ACTIVITY');
        }

        // 4. Success Rate Degradation (Provider Level)
        const failedRecent = recentTxs.filter(t => t.status === 'failed').length;
        const failureRate = failedRecent / (recentTxs.length || 1);
        if (failureRate > 0.4) {
            anomalyScore += 25;
            flags.push(`PROVIDER_FAILURE_RATE_ELEVATED_${(failureRate * 100).toFixed(0)}%`);
        }

        // 5. Transaction Type Anomaly (User Level)
        const userTxs = history.filter(t => t.user_id === tx.user_id);
        if (userTxs.length > 15) {
            const typeCounts: Record<string, number> = {};
            userTxs.forEach(t => {
                const type = String(t.type);
                typeCounts[type] = (typeCounts[type] || 0) + 1;
            });
            
            const currentTypeCount = typeCounts[String(tx.type)] || 0;
            const typeFrequency = currentTypeCount / userTxs.length;
            
            // If this type of transaction makes up less than 5% of their history
            if (typeFrequency < 0.05) {
                const amounts = userTxs.map(t => t.amount);
                const mean = amounts.reduce((a, b) => a + b, 0) / amounts.length;
                
                // If it's a rare transaction type AND the amount is > 1.5x their average
                if (tx.amount > mean * 1.5) {
                    anomalyScore += 35;
                    flags.push(`RARE_TX_TYPE_HIGH_VALUE_${String(tx.type).toUpperCase()}`);
                } else {
                    anomalyScore += 15;
                    flags.push(`RARE_TX_TYPE_${String(tx.type).toUpperCase()}`);
                }
            }
        }

        const isAnomaly = anomalyScore >= 50;

        if (isAnomaly) {
            await this.handleAnomaly(tx, anomalyScore, flags);
        }

        return { isAnomaly, score: anomalyScore, flags };
    }

    /**
     * HANDLE DETECTED ANOMALY
     * Triggers automated alerts and forensic logging.
     */
    private async handleAnomaly(tx: Transaction, score: number, flags: string[]) {
        const sb = getSupabase();
        
        // 1. Log to Audit Trail
        await Audit.log('FRAUD', tx.user_id || 'SYSTEM', 'PROVIDER_ANOMALY_DETECTED', {
            txId: tx.id,
            score,
            flags,
            walletId: tx.walletId
        });

        // 2. Persist to Anomaly Table
        if (sb) {
            await sb.from('provider_anomalies').insert({
                transaction_id: tx.id,
                user_id: tx.user_id,
                wallet_id: tx.walletId,
                risk_score: score,
                detection_flags: flags,
                status: 'OPEN'
            });
        }

        // 3. Automated Alert to Security Team
        if (sb) {
            const { data: admins } = await sb.from('staff').select('id');
            if (admins) {
                for (const admin of admins) {
                    const { data: user } = await sb.from('users').select('language').eq('id', admin.id).maybeSingle();
                    const language = user?.language || 'en';
                    const subject = language === 'sw' ? `🚨 Hitilafu ya Hatari Kubwa: ${tx.id}` : `🚨 High Risk Anomaly: ${tx.id}`;
                    const body = language === 'sw' 
                        ? `Muamala kwenye akaunti ${tx.walletId} umesababisha alama ya hitilafu ya ${score}. Alama: ${flags.join(', ')}` 
                        : `A transaction on wallet ${tx.walletId} triggered an anomaly score of ${score}. Flags: ${flags.join(', ')}`;

                    await Messaging.dispatch(
                        admin.id, 
                        'security', 
                        subject,
                        body,
                        { sms: true, email: true }
                    );
                    
                    // Real-time WebSocket Alert
                    SocketRegistry.send(admin.id, {
                        type: 'SECURITY_ALERT',
                        event: 'PROVIDER_ANOMALY_DETECTED',
                        data: {
                            txId: tx.id,
                            score,
                            flags,
                            walletId: tx.walletId
                        }
                    });
                }
            }
        }
    }

    /**
     * GENERATE ANOMALY REPORT
     * Aggregates detected anomalies for executive review.
     */
    public async generateReport(days: number = 7): Promise<any> {
        const sb = getSupabase();
        if (!sb) return { error: "DB_OFFLINE" };

        const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
        
        const { data, error } = await sb
            .from('provider_anomalies')
            .select('*, transactions(amount, description, type)')
            .gte('created_at', startDate)
            .order('risk_score', { ascending: false });

        if (error) throw error;

        const summary = {
            total_anomalies: data.length,
            critical_count: data.filter(a => a.risk_score >= 80).length,
            top_flags: this.aggregateFlags(data),
            period_days: days
        };

        return { summary, details: data };
    }

    private aggregateFlags(data: any[]): Record<string, number> {
        const counts: Record<string, number> = {};
        data.forEach(a => {
            (a.detection_flags || []).forEach((f: string) => {
                counts[f] = (counts[f] || 0) + 1;
            });
        });
        return counts;
    }
}

export const ProviderAnomalyTracker = new ProviderAnomalyTrackerService();
