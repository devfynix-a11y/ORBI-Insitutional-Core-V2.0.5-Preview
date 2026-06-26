import { Cluster, Redis } from 'ioredis';
import fs from 'fs';

/**
 * ORBI VALKEY CLIENT FACTORY
 * -------------------------------------------
 * Uses the Redis wire protocol through ioredis for Valkey compatibility.
 * Legacy REDIS_* variables remain temporary aliases during migration.
 */

export type RedisTier = 'session' | 'fraud' | 'monitor';

class RedisClusterFactory {
    private static instances: Map<RedisTier, Cluster | Redis> = new Map();

    private static buildTlsOptions() {
        const tlsEnabled = process.env.VALKEY_TLS_ENABLED || process.env.REDIS_TLS_ENABLED;
        if (tlsEnabled !== 'true') return undefined;

        const allowInsecureTls =
            (process.env.VALKEY_ALLOW_INSECURE_TLS || process.env.REDIS_ALLOW_INSECURE_TLS) === 'true';
        const caPath = process.env.VALKEY_CA_CERT_PATH || process.env.REDIS_CA_CERT_PATH;
        const tlsOptions: any = {
            rejectUnauthorized: !allowInsecureTls,
        };

        if (caPath && fs.existsSync(caPath)) {
            tlsOptions.ca = fs.readFileSync(caPath);
            tlsOptions.minVersion = 'TLSv1.3' as const;
        }

        if (allowInsecureTls) {
            console.warn('[ValkeyFactory] Insecure TLS is enabled. This is forbidden in production.');
        }

        return tlsOptions;
    }

    public static isAvailable(): boolean {
        return !!(
            process.env.VALKEY_CLUSTER_NODES ||
            process.env.VALKEY_URL ||
            process.env.VALKEY_HOST ||
            process.env.REDIS_CLUSTER_NODES ||
            process.env.REDIS_URL ||
            process.env.REDIS_HOST
        );
    }

    public static getClient(tier: RedisTier): Cluster | Redis | null {
        if (this.instances.has(tier)) {
            return this.instances.get(tier)!;
        }

        const standaloneUrl = process.env.VALKEY_URL || process.env.REDIS_URL;

        // 1. Standalone Valkey mode.
        if (standaloneUrl) {
            console.info(`[ValkeyFactory] Initializing standalone link for ${tier}...`);
            try {
                const client = new Redis(standaloneUrl, {
                    maxRetriesPerRequest: null,
                    enableReadyCheck: false,
                    tls: this.buildTlsOptions(),
                });

                client.on('error', (err) => {
                    // Suppress connection errors to prevent log flooding
                    console.warn(`[Valkey:${tier}] Connection instability: ${err.message}`);
                });

                this.instances.set(tier, client);
                return client;
            } catch (e: any) {
                console.error(`[ValkeyFactory] Standalone initialization failed: ${e.message}`);
            }
        }

        // 2. Cluster Mode
        const nodesStr = process.env.VALKEY_CLUSTER_NODES || process.env.REDIS_CLUSTER_NODES;
        if (nodesStr) {
            const nodes = nodesStr.split(',').map(n => {
                const [host, port] = n.split(':');
                return { host, port: parseInt(port || '6379') };
            });

            const username =
                process.env[`VALKEY_USER_${tier.toUpperCase()}`] ||
                process.env[`REDIS_USER_${tier.toUpperCase()}`];
            const password =
                process.env[`VALKEY_PASS_${tier.toUpperCase()}`] ||
                process.env[`REDIS_PASS_${tier.toUpperCase()}`];
            const tlsOptions = this.buildTlsOptions();

            const cluster = new Cluster(nodes, {
                dnsLookup: (address: string, callback: (err: Error | null, address: string, family?: number) => void) => callback(null, address),
                enableReadyCheck: false,
                redisOptions: {
                    tls: tlsOptions,
                    username,
                    password,
                    connectTimeout: 20000,
                    maxRetriesPerRequest: 5,
                    keepAlive: 30000,
                    showFriendlyErrorStack: process.env.NODE_ENV !== 'production',
                },
                clusterRetryStrategy: (times: number) => {
                    return Math.min(times * 200, 5000);
                },
                slotsRefreshTimeout: 45000, // Increased timeout for slots refresh
                retryDelayOnFailover: 100, // Retry delay on failover
            });

            cluster.on('error', (err: Error) => {
                // Suppress "Failed to refresh slots cache" if it's transient
                if (err.message.includes('Failed to refresh slots cache')) {
                    // console.warn(`[RedisCluster:${tier}] Slots refresh warning (transient): ${err.message}`);
                } else {
                    console.error(`[ValkeyCluster:${tier}] Functional fault detected:`, err.message);
                }
            });

            this.instances.set(tier, cluster);
            return cluster;
        }

        // 3. Standalone Host Fallback
        const standaloneHost = process.env.VALKEY_HOST || process.env.REDIS_HOST;
        if (standaloneHost) {
             const client = new Redis({
                 host: standaloneHost,
                 port: parseInt(process.env.VALKEY_PORT || process.env.REDIS_PORT || '6379'),
                 username: process.env.VALKEY_USERNAME,
                 password: process.env.VALKEY_PASSWORD || process.env.REDIS_PASSWORD,
                 tls: this.buildTlsOptions(),
             });
             
             client.on('error', (err) => {
                 console.warn(`[Valkey:${tier}] Connection instability: ${err.message}`);
             });

             this.instances.set(tier, client);
             return client;
        }

        return null;
    }

    public static async shutdownAll() {
        for (const [tier, client] of this.instances.entries()) {
            console.info(`[ValkeyFactory] Closing ${tier} connection...`);
            await client.quit();
        }
        this.instances.clear();
    }
}

export { RedisClusterFactory };
