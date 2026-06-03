import { getAdminSupabase } from '../../services/supabaseClient.js';
import { UUID } from '../../services/utils.js';
import { Audit } from '../security/audit.js';
import { SocketRegistry } from './SocketRegistry.js';
import { logger } from './logger.js';

const operatorAlertLogger = logger.child({ component: 'operator_alert_service' });

export type OperatorAlertSeverity = 'INFO' | 'WARNING' | 'HIGH' | 'CRITICAL';

export type OperatorAlertAction = {
    id: string;
    label: string;
    type: 'navigate' | 'acknowledge' | 'resolve' | 'freeze_user' | 'open_case';
    target?: string;
    payload?: Record<string, any>;
};

export type CreateOperatorAlertInput = {
    title: string;
    body: string;
    severity?: OperatorAlertSeverity;
    eventCode: string;
    targetRoles?: string[];
    actorId?: string | null;
    transactionId?: string | number | null;
    resourceType?: string | null;
    resourceId?: string | null;
    metadata?: Record<string, any>;
    actions?: OperatorAlertAction[];
};

class OperatorAlertService {
    async create(input: CreateOperatorAlertInput) {
        const alert = {
            id: UUID.generate(),
            title: input.title,
            body: input.body,
            severity: input.severity || 'INFO',
            event_code: input.eventCode,
            target_roles: input.targetRoles?.length ? input.targetRoles : ['SUPER_ADMIN', 'ADMIN', 'RISK_OFFICER', 'AUDIT'],
            actor_id: input.actorId || null,
            transaction_id: input.transactionId ? String(input.transactionId) : null,
            resource_type: input.resourceType || null,
            resource_id: input.resourceId || null,
            metadata: input.metadata || {},
            actions: input.actions || [],
            status: 'UNREAD',
            created_at: new Date().toISOString(),
            read_at: null,
            resolved_at: null,
            resolved_by: null,
        };

        const sb = getAdminSupabase();
        if (sb) {
            try {
                await sb.from('operator_alerts').insert(alert);
            } catch (error: any) {
                operatorAlertLogger.warn('operator_alert.persist_failed', { error_message: error?.message, event_code: input.eventCode });
            }
        }

        SocketRegistry.broadcast({
            type: 'OPERATOR_ALERT',
            payload: this.toClientAlert(alert),
        });

        await Audit.log('SECURITY', input.actorId || 'system', 'OPERATOR_ALERT_CREATED', {
            alertId: alert.id,
            eventCode: input.eventCode,
            severity: alert.severity,
            targetRoles: alert.target_roles,
            resourceType: alert.resource_type,
            resourceId: alert.resource_id,
        }, alert.transaction_id || undefined).catch(() => {});

        return this.toClientAlert(alert);
    }

    async list(query: { role?: string; limit?: number; status?: string }) {
        const sb = getAdminSupabase();
        if (!sb) return [];

        const limit = Math.min(Math.max(Number(query.limit || 50), 1), 100);
        let request = sb
            .from('operator_alerts')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(limit);

        if (query.status && query.status !== 'ALL') request = request.eq('status', query.status);

        const { data, error } = await request;
        if (error) throw error;

        const role = String(query.role || '').toUpperCase();
        return (data || [])
            .filter((alert: any) => !role || !Array.isArray(alert.target_roles) || alert.target_roles.includes(role) || alert.target_roles.includes('ALL'))
            .map((alert: any) => this.toClientAlert(alert));
    }

    async markRead(alertId: string, actorId: string) {
        const sb = getAdminSupabase();
        if (sb) {
            await sb.from('operator_alerts').update({
                status: 'READ',
                read_at: new Date().toISOString(),
            }).eq('id', alertId);
        }
        await Audit.log('ADMIN', actorId, 'OPERATOR_ALERT_READ', { alertId }).catch(() => {});
        return { id: alertId, status: 'READ' };
    }

    async resolve(alertId: string, actorId: string, reason?: string) {
        const sb = getAdminSupabase();
        if (sb) {
            await sb.from('operator_alerts').update({
                status: 'RESOLVED',
                resolved_at: new Date().toISOString(),
                resolved_by: actorId,
                resolution_note: reason || null,
            }).eq('id', alertId);
        }
        await Audit.log('ADMIN', actorId, 'OPERATOR_ALERT_RESOLVED', { alertId, reason }).catch(() => {});
        return { id: alertId, status: 'RESOLVED' };
    }

    private toClientAlert(alert: any) {
        return {
            id: alert.id,
            title: alert.title,
            body: alert.body,
            severity: alert.severity,
            eventCode: alert.event_code,
            targetRoles: alert.target_roles || [],
            actorId: alert.actor_id,
            transactionId: alert.transaction_id,
            resourceType: alert.resource_type,
            resourceId: alert.resource_id,
            metadata: alert.metadata || {},
            actions: alert.actions || [],
            status: alert.status || 'UNREAD',
            createdAt: alert.created_at,
            readAt: alert.read_at,
            resolvedAt: alert.resolved_at,
        };
    }
}

export const operatorAlertService = new OperatorAlertService();
