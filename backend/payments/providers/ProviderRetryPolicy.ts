import { FinancialPartner } from '../../../types.js';
import { normalizeProviderError, toProviderDomainError } from './ProviderErrorNormalizer.js';
import { RetryHooks, RetryOperation } from './types.js';
import { logger } from '../../infrastructure/logger.js';

type RetryOptions = {
    maxAttempts?: number;
    baseDelayMs?: number;
    hooks?: RetryHooks;
};

type CircuitState = {
    state: 'CLOSED' | 'OPEN' | 'HALF_OPEN';
    failures: number;
    openedAt?: number;
};

const sleep = async (ms: number): Promise<void> => {
    await new Promise((resolve) => setTimeout(resolve, ms));
};

const retryLogger = logger.child({ component: 'provider_retry_policy' });

export class ProviderRetryPolicy {
    private readonly defaultMaxAttempts = Number(process.env.ORBI_PROVIDER_MAX_ATTEMPTS || 3);
    private readonly defaultBaseDelayMs = Number(process.env.ORBI_PROVIDER_RETRY_DELAY_MS || 250);
    private readonly circuitFailureThreshold = Math.max(1, Number(process.env.ORBI_PROVIDER_CIRCUIT_FAILURE_THRESHOLD || 5));
    private readonly circuitCooldownMs = Math.max(1000, Number(process.env.ORBI_PROVIDER_CIRCUIT_COOLDOWN_MS || 60000));
    private readonly maxConcurrentPerProvider = Math.max(1, Number(process.env.ORBI_PROVIDER_MAX_CONCURRENT_PER_PROVIDER || 10));
    private readonly circuits = new Map<string, CircuitState>();
    private readonly activeByProvider = new Map<string, number>();

    private getProviderKey(partner: FinancialPartner): string {
        return String(partner.id || partner.name || 'unknown_provider');
    }

    private getCircuitKey(partner: FinancialPartner, operation: RetryOperation): string {
        return `${this.getProviderKey(partner)}:${operation}`;
    }

    private assertCircuitAllows(circuitKey: string, partner: FinancialPartner, operation: RetryOperation): void {
        const circuit = this.circuits.get(circuitKey);
        if (!circuit || circuit.state === 'CLOSED') return;

        const elapsedMs = Date.now() - Number(circuit.openedAt || 0);
        if (elapsedMs >= this.circuitCooldownMs) {
            this.circuits.set(circuitKey, { ...circuit, state: 'HALF_OPEN' });
            retryLogger.warn('provider.circuit_half_open', {
                operation,
                partner_id: partner.id,
                partner_name: partner.name,
                failures: circuit.failures,
            });
            return;
        }

        const error = new Error(`PROVIDER_CIRCUIT_OPEN: ${partner.name || partner.id} ${operation}`);
        (error as any).code = 'PROVIDER_CIRCUIT_OPEN';
        (error as any).retryable = false;
        throw error;
    }

    private recordSuccess(circuitKey: string, partner: FinancialPartner, operation: RetryOperation): void {
        const previous = this.circuits.get(circuitKey);
        if (previous && previous.state !== 'CLOSED') {
            retryLogger.info('provider.circuit_closed', {
                operation,
                partner_id: partner.id,
                partner_name: partner.name,
            });
        }
        this.circuits.set(circuitKey, { state: 'CLOSED', failures: 0 });
    }

    private recordFailure(circuitKey: string, partner: FinancialPartner, operation: RetryOperation): void {
        const previous = this.circuits.get(circuitKey) || { state: 'CLOSED' as const, failures: 0 };
        const failures = previous.failures + 1;
        if (failures >= this.circuitFailureThreshold || previous.state === 'HALF_OPEN') {
            this.circuits.set(circuitKey, { state: 'OPEN', failures, openedAt: Date.now() });
            retryLogger.warn('provider.circuit_open', {
                operation,
                partner_id: partner.id,
                partner_name: partner.name,
                failures,
                threshold: this.circuitFailureThreshold,
                cooldown_ms: this.circuitCooldownMs,
            });
            return;
        }

        this.circuits.set(circuitKey, { state: previous.state, failures, openedAt: previous.openedAt });
    }

    private async runWithBulkhead<T>(partner: FinancialPartner, operation: RetryOperation, work: () => Promise<T>): Promise<T> {
        const providerKey = this.getProviderKey(partner);
        const active = this.activeByProvider.get(providerKey) || 0;
        if (active >= this.maxConcurrentPerProvider) {
            retryLogger.warn('provider.bulkhead_rejected', {
                operation,
                partner_id: partner.id,
                partner_name: partner.name,
                active,
                limit: this.maxConcurrentPerProvider,
            });
            const error = new Error(`PROVIDER_BULKHEAD_FULL: ${partner.name || partner.id}`);
            (error as any).code = 'PROVIDER_BULKHEAD_FULL';
            (error as any).retryable = true;
            throw error;
        }

        this.activeByProvider.set(providerKey, active + 1);
        try {
            return await work();
        } finally {
            const nextActive = Math.max(0, (this.activeByProvider.get(providerKey) || 1) - 1);
            if (nextActive === 0) this.activeByProvider.delete(providerKey);
            else this.activeByProvider.set(providerKey, nextActive);
        }
    }

    async execute<T>(
        partner: FinancialPartner,
        operation: RetryOperation,
        work: () => Promise<T>,
        options: RetryOptions = {},
    ): Promise<T> {
        const maxAttempts = Math.max(1, Number(options.maxAttempts || this.defaultMaxAttempts));
        const baseDelayMs = Math.max(0, Number(options.baseDelayMs || this.defaultBaseDelayMs));
        const hooks = options.hooks;
        const circuitKey = this.getCircuitKey(partner, operation);

        let lastError: unknown;
        for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
            try {
                this.assertCircuitAllows(circuitKey, partner, operation);
                const result = await this.runWithBulkhead(partner, operation, work);
                this.recordSuccess(circuitKey, partner, operation);
                return result;
            } catch (error: any) {
                const normalized = normalizeProviderError(error, partner);
                lastError = toProviderDomainError(error, partner);
                this.recordFailure(circuitKey, partner, operation);
                const shouldRetry = normalized.retryable && attempt < maxAttempts;
                const hookContext = {
                    partner,
                    operation,
                    attempt,
                    maxAttempts,
                    error: normalized,
                };

                if (!shouldRetry) {
                    await hooks?.onExhausted?.(hookContext);
                    throw lastError;
                }

                await hooks?.onRetry?.(hookContext);
                await hooks?.onFailoverCandidate?.(hookContext);
                const delayMs = Math.round(baseDelayMs * (2 ** (attempt - 1)));
                retryLogger.warn('provider.retry_scheduled', { operation, partner_id: partner.id, partner_name: partner.name, category: normalized.category, attempt, max_attempts: maxAttempts });
                if (delayMs > 0) {
                    await sleep(delayMs);
                }
            }
        }

        throw toProviderDomainError(lastError, partner);
    }
}

export const providerRetryPolicy = new ProviderRetryPolicy();
