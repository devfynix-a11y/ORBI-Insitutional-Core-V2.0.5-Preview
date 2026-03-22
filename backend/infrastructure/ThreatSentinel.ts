
import { ThreatEvent, FalcoAgent } from '../../types.js';
import { UUID } from '../../services/utils.js';

/**
 * SOVEREIGN THREAT SENTINEL (V1.0)
 * Simulation logic for Falco Kubernetes Agents.
 */
class ThreatSentinelService {
    private agents: FalcoAgent[] = [
        { id: 'agt-01', node_name: 'node-pool-alpha-1', status: 'ACTIVE', version: '0.37.0', kernel_module: 'READY', events_per_sec: 42 },
        { id: 'agt-02', node_name: 'node-pool-alpha-2', status: 'ACTIVE', version: '0.37.0', kernel_module: 'READY', events_per_sec: 38 },
        { id: 'agt-03', node_name: 'node-pool-beta-1', status: 'DEGRADED', version: '0.36.2', kernel_module: 'FAULT', events_per_sec: 12 },
        { id: 'agt-04', node_name: 'node-pool-beta-2', status: 'ACTIVE', version: '0.37.0', kernel_module: 'READY', events_per_sec: 45 }
    ];

    private threatHistory: ThreatEvent[] = [];

    private rules = [
        "Terminal shell in container",
        "Sensitive file read (e.g. /etc/shadow)",
        "Unexpected network connection",
        "Inbound connection to docker.sock",
        "Directory traversal attempt",
        "Binary execution from /tmp"
    ];

    constructor() {
        this.startThreatSimulator();
    }

    private startThreatSimulator() {
        setInterval(() => {
            if (Math.random() > 0.7) {
                this.generateEvent();
            }
        }, 5000);
    }

    private generateEvent() {
        const event: ThreatEvent = {
            id: UUID.generate(),
            timestamp: new Date().toISOString(),
            priority: Math.random() > 0.9 ? 'CRITICAL' : Math.random() > 0.6 ? 'WARNING' : 'NOTICE',
            rule: this.rules[Math.floor(Math.random() * this.rules.length)],
            output: "Detect behavior that violates sovereign runtime policy.",
            container: `orbi-core-${Math.random().toString(36).substring(7)}`,
            node: this.agents[Math.floor(Math.random() * this.agents.length)].node_name
        };
        this.threatHistory.unshift(event);
        if (this.threatHistory.length > 50) this.threatHistory.pop();
    }

    public getAgents(): FalcoAgent[] { return this.agents; }
    public getHistory(): ThreatEvent[] { return this.threatHistory; }
}

export const ThreatSentinel = new ThreatSentinelService();
