
import { CONFIG } from '../../services/config.js';

export type BreakerState = 'CLOSED' | 'OPEN' | 'HALF_OPEN' | 'HEALING';

interface ServiceCircuit {
    id: string;
    state: BreakerState;
    failures: number;
    lastFailureTime: number;
    activeEndpoint: string;
    recoveryAttempts: number;
}

class ResilienceEngineService {
    private circuits: Map<string, ServiceCircuit> = new Map();
    private healingPool: Set<string> = new Set();
    // FIX: Changed type to any to avoid NodeJS namespace issues in client-side environment
    private healTimer: any | null = null;

    constructor() {
        this.startHealCycle();
    }

    private startHealCycle() {
        if (this.healTimer) clearInterval(this.healTimer);
        this.healTimer = setInterval(() => this.runGlobalHealCycle(), CONFIG.RESILIENCE.HEAL_INTERVAL);
    }

    public async execute<T>(serviceId: string, action: (url: string) => Promise<T>, timeoutMs: number = 5000): Promise<T> {
        const circuit = this.getCircuit(serviceId);

        if (circuit.state === 'OPEN') {
            const now = Date.now();
            if (now - circuit.lastFailureTime > CONFIG.RESILIENCE.BREAKER_COOLDOWN) {
                console.info(`[SovereignBreaker] ${serviceId} entering HALF_OPEN probe.`);
                circuit.state = 'HALF_OPEN';
            } else {
                throw new Error(`CIRCUIT_OPEN: Relay node ${serviceId} is currently offline.`);
            }
        }

        try {
            // Wrap action in a timeout promise to prevent hanging connections
            const timeoutPromise = new Promise<never>((_, reject) => 
                setTimeout(() => reject(new Error('TIMEOUT')), timeoutMs)
            );
            
            const result = await Promise.race([
                action(circuit.activeEndpoint),
                timeoutPromise
            ]);
            
            this.onSuccess(serviceId);
            return result;
        } catch (error: any) {
            return this.onFailure(serviceId, action, error);
        }
    }

    private getCircuit(id: string): ServiceCircuit {
        if (!this.circuits.has(id)) {
            this.circuits.set(id, {
                id,
                state: 'CLOSED',
                failures: 0,
                lastFailureTime: 0,
                activeEndpoint: CONFIG.BACKEND_URL,
                recoveryAttempts: 0
            });
        }
        return this.circuits.get(id)!;
    }

    private onSuccess(id: string) {
        const circuit = this.circuits.get(id);
        if (circuit) {
            if (circuit.state !== 'CLOSED') {
                console.info(`[SovereignBreaker] Node ${id} restored.`);
            }
            circuit.state = 'CLOSED';
            circuit.failures = 0;
            circuit.recoveryAttempts = 0;
            this.healingPool.delete(id);
        }
    }

    private async onFailure<T>(id: string, action: (url: string) => Promise<T>, error: any): Promise<T> {
        const circuit = this.getCircuit(id);
        if (!circuit) throw error;

        circuit.failures++;
        circuit.lastFailureTime = Date.now();

        if (circuit.failures >= CONFIG.RESILIENCE.BREAKER_THRESHOLD) {
            circuit.state = 'OPEN';
            console.error(`[SovereignBreaker] CRITICAL: Breaker TRIPPED for ${id}. Relay link severed.`);
            this.healingPool.add(id);
        }

        throw error;
    }

    private async runGlobalHealCycle() {
        if (this.healingPool.size === 0) return;
        for (const id of this.healingPool) {
            try {
                const response = await fetch(`${CONFIG.BACKEND_URL}/health`);
                if (response.ok) this.onSuccess(id);
            } catch (e) { }
        }
    }

    public getCircuitStates() {
        return Array.from(this.circuits.values()).map(c => ({
            id: c.id,
            state: c.state,
            failures: c.failures,
            provisioned: CONFIG.PROVISIONING.IS_HYDRATED
        }));
    }
}

export const ResilienceEngine = new ResilienceEngineService();
