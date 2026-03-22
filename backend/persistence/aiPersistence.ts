
import { AIReport } from '../../types.js';
import { getSupabase } from '../../services/supabaseClient.js';
import { UUID } from '../../services/utils.js';
import { Storage } from '../storage.js';

/**
 * AI SERVICE PERSISTENCE (V1.0)
 * Handles historical storage of cognitive analysis.
 */
export class AIServicePersistence {
    private readonly STORAGE_KEY = 'orbi_ai_reports_history';

    public async saveReport(userId: string, report: AIReport): Promise<AIReport> {
        const reportId = UUID.generate();
        const fullReport = { ...report, id: reportId, user_id: userId };

        const sb = getSupabase();
        if (sb) {
            try {
                await sb.from('ai_reports').insert({
                    id: reportId,
                    user_id: userId,
                    score: report.health.score,
                    health_level: report.health.healthLevel,
                    report_data: report, // JSONB
                    created_at: new Date().toISOString()
                });
            } catch (e) {
                console.warn("[AIPersistence] Cloud insert failed, using local vault.");
            }
        }

        const history = this.getLocalHistory();
        history.unshift(fullReport);
        Storage.setItem(this.STORAGE_KEY, JSON.stringify(history.slice(0, 50)));

        return fullReport;
    }

    public async getReports(userId: string): Promise<AIReport[]> {
        const sb = getSupabase();
        if (sb) {
            try {
                const { data } = await sb.from('ai_reports')
                    .select('report_data')
                    .eq('user_id', userId)
                    .order('created_at', { ascending: false })
                    .limit(20);
                
                if (data && data.length > 0) {
                    return data.map(d => d.report_data);
                }
            } catch (e) {}
        }

        return this.getLocalHistory().filter(r => r.user_id === userId);
    }

    private getLocalHistory(): AIReport[] {
        try {
            return JSON.parse(Storage.getItem(this.STORAGE_KEY) || '[]');
        } catch (e) { return []; }
    }
}
