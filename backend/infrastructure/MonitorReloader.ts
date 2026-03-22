
import { Audit } from '../security/audit.js';
import { Storage } from '../storage.js';
import { MonitoringEndpoint } from '../../types.js';

/**
 * MONITORING RELOAD PROTOCOL (V1.2)
 * ---------------------------------
 * Implements Configuration Reload signals for monitoring clusters.
 */
class MonitorReloaderService {
    private readonly ENDPOINTS_KEY = 'dps_monitoring_endpoints';
    
    public async notifyReload(configKey: string) {
        console.info(`[Monitor] Notifying reload for: ${configKey}`);
        
        await this.pulseExternalEndpoints(configKey);

        await Audit.log('INFRASTRUCTURE', 'SYSTEM', 'CONFIG_RELOAD_TRIGGERED', { 
            configKey, 
            ts: new Date().toISOString() 
        });
    }

    private async pulseExternalEndpoints(configKey: string) {
        const endpoints = this.getEndpoints();
        const active = endpoints.filter(e => e.status === 'ACTIVE');

        const pulses = active.map(async (ep) => {
            try {
                const controller = new AbortController();
                const timeoutId = setTimeout(() => controller.abort(), 5000);

                const response = await fetch(ep.url, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': ep.auth_header || '',
                        'X-DPS-Event': 'CONFIG_RELOAD',
                        'X-DPS-Config': configKey
                    },
                    signal: controller.signal
                });

                clearTimeout(timeoutId);

                if (response.ok) {
                    console.info(`[Monitor] Reload successful for ${ep.name}`);
                } else {
                    throw new Error(`Endpoint responded with ${response.status}`);
                }
            } catch (e: any) {
                console.warn(`[Monitor] Reload pulse failed for ${ep.name}: ${e.message}`);
            }
        });

        await Promise.allSettled(pulses);
    }

    public getEndpoints(): MonitoringEndpoint[] {
        const raw = Storage.getItem(this.ENDPOINTS_KEY);
        if (!raw) return this.getDefaultEndpoints();
        return JSON.parse(raw);
    }

    private getDefaultEndpoints(): MonitoringEndpoint[] {
        return [
            { 
                id: 'prom-01', 
                name: 'Prometheus Primary', 
                url: 'https://prometheus:9090/-/reload', 
                type: 'PROMETHEUS', 
                status: 'ACTIVE' 
            },
            { 
                id: 'graf-01', 
                name: 'Grafana Alerting', 
                url: 'https://grafana:3000/api/admin/provisioning/dashboards/reload', 
                type: 'GRAFANA', 
                status: 'ACTIVE' 
            }
        ];
    }
}

export const MonitorReloader = new MonitorReloaderService();
