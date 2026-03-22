
import { ClusterOrchestrator } from './ClusterService.js';
import { RegistryService } from './RegistryService.js';
import { Audit } from '../security/audit.js';
import { ResilienceEngine } from './ResilienceEngine.js';

/**
 * ORBI HEALTH MONITOR (V2.0)
 * ---------------------------
 * Proactive monitoring node that identifies silent failures
 * and triggers the Autonomous Pilot.
 */
class HealthMonitorService {
    private monitorInterval: any = null;

    public start() {
        if (this.monitorInterval) return;
        console.info("[HealthMonitor] Sentinel active. Monitoring cluster telemetry...");
        this.monitorInterval = setInterval(() => this.checkSystemHealth(), 60000);
    }

    private async checkSystemHealth() {
        const pods = ClusterOrchestrator.getPods();
        const flags = RegistryService.getSystemFlags();

        for (const pod of pods) {
            // Simulate health check logic
            const errorRate = parseFloat(pod.errorRate);
            if (errorRate > 5.0 && pod.status === 'RUNNING') {
                console.warn(`[HealthMonitor] High error rate detected on ${pod.name}: ${pod.errorRate}`);
                if (flags.autonomous_healing) {
                    await ClusterOrchestrator.tripCircuit(pod.id, "Error rate threshold exceeded (5.0%)");
                    await Audit.log('SECURITY', 'health-monitor', 'NODE_TRIPPED', { pod: pod.name, errorRate });
                }
            }
        }

        // Check Circuit Breakers
        const circuits = ResilienceEngine.getCircuitStates();
        const openCircuits = circuits.filter(c => c.state === 'OPEN');
        if (openCircuits.length > 0) {
            await Audit.log('INFRASTRUCTURE', 'health-monitor', 'CIRCUITS_OPEN', { count: openCircuits.length });
        }
    }

    public stop() {
        if (this.monitorInterval) clearInterval(this.monitorInterval);
        this.monitorInterval = null;
    }
}

export const HealthMonitor = new HealthMonitorService();
