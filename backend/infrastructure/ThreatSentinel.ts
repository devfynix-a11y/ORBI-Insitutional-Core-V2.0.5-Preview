
import { ThreatEvent, FalcoAgent } from '../../types.js';

/**
 * SOVEREIGN THREAT SENTINEL (V1.0)
 * Runtime view for externally reported Falco Kubernetes agent state and events.
 */
class ThreatSentinelService {
    private agents: FalcoAgent[] = [];
    private threatHistory: ThreatEvent[] = [];

    public updateAgents(agents: FalcoAgent[]): void {
        this.agents = agents;
    }

    public recordEvent(event: ThreatEvent): void {
        this.threatHistory.unshift(event);
        if (this.threatHistory.length > 50) this.threatHistory.pop();
    }

    public getAgents(): FalcoAgent[] { return this.agents; }
    public getHistory(): ThreatEvent[] { return this.threatHistory; }
}

export const ThreatSentinel = new ThreatSentinelService();
