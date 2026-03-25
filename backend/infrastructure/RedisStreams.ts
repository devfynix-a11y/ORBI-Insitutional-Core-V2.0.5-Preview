import os from 'os';
import { RedisClusterFactory } from './RedisClusterFactory.js';

type RedisFieldMap = Record<string, string>;

interface StreamEntry {
    id: string;
    fields: RedisFieldMap;
}

type RedisClientLike = {
    call(command: string, ...args: string[]): Promise<unknown>;
};

export class RedisStreams {
    private static readonly backgroundStream = process.env.ORBI_REDIS_STREAM_BACKGROUND_JOBS || 'orbi:stream:background_jobs';
    private static readonly outboxStream = process.env.ORBI_REDIS_STREAM_OUTBOX_EVENTS || 'orbi:stream:outbox_events';
    private static readonly backgroundRetrySet = process.env.ORBI_REDIS_RETRY_BACKGROUND_JOBS || 'orbi:retry:background_jobs';
    private static readonly outboxRetrySet = process.env.ORBI_REDIS_RETRY_OUTBOX_EVENTS || 'orbi:retry:outbox_events';
    private static readonly backgroundDeadLetterStream = process.env.ORBI_REDIS_DLQ_BACKGROUND_JOBS || 'orbi:dlq:background_jobs';
    private static readonly outboxDeadLetterStream = process.env.ORBI_REDIS_DLQ_OUTBOX_EVENTS || 'orbi:dlq:outbox_events';
    private static readonly backgroundGroup = process.env.ORBI_REDIS_GROUP_BACKGROUND_JOBS || 'orbi:bg-workers';
    private static readonly outboxGroup = process.env.ORBI_REDIS_GROUP_OUTBOX_EVENTS || 'orbi:event-workers';
    private static readonly consumerName =
        process.env.ORBI_REDIS_CONSUMER_NAME || `${os.hostname()}:${process.pid}`;
    private static readonly defaultBlockMs = Number(process.env.ORBI_REDIS_STREAM_BLOCK_MS || 5000);
    private static readonly defaultClaimIdleMs = Number(process.env.ORBI_REDIS_STREAM_CLAIM_IDLE_MS || 60000);

    public static isAvailable(): boolean {
        return !!RedisClusterFactory.getClient('monitor');
    }

    public static getBackgroundConfig() {
        return {
            stream: this.backgroundStream,
            retrySet: this.backgroundRetrySet,
            deadLetterStream: this.backgroundDeadLetterStream,
            group: this.backgroundGroup,
            consumer: this.consumerName,
            blockMs: this.defaultBlockMs,
            claimIdleMs: this.defaultClaimIdleMs,
        };
    }

    public static getOutboxConfig() {
        return {
            stream: this.outboxStream,
            retrySet: this.outboxRetrySet,
            deadLetterStream: this.outboxDeadLetterStream,
            group: this.outboxGroup,
            consumer: this.consumerName,
            blockMs: this.defaultBlockMs,
            claimIdleMs: this.defaultClaimIdleMs,
        };
    }

    public static async publish(stream: string, fields: RedisFieldMap): Promise<string | null> {
        const client = this.getClient();
        if (!client) return null;

        const flattenedFields = Object.entries(fields).flatMap(([key, value]) => [key, value]);
        const result = await client.call('XADD', stream, '*', ...flattenedFields);
        return typeof result === 'string' ? result : String(result);
    }

    public static async ensureGroup(stream: string, group: string): Promise<void> {
        const client = this.getClient();
        if (!client) return;

        try {
            await client.call('XGROUP', 'CREATE', stream, group, '$', 'MKSTREAM');
        } catch (error: any) {
            const message = String(error?.message || error || '');
            if (!message.includes('BUSYGROUP')) {
                throw error;
            }
        }
    }

    public static async readGroup(
        stream: string,
        group: string,
        consumer: string,
        count: number,
        blockMs: number,
    ): Promise<StreamEntry[]> {
        const client = this.getClient();
        if (!client) return [];

        const raw = await client.call(
            'XREADGROUP',
            'GROUP',
            group,
            consumer,
            'COUNT',
            String(count),
            'BLOCK',
            String(blockMs),
            'STREAMS',
            stream,
            '>',
        );

        return this.parseEntries(raw);
    }

    public static async autoClaim(
        stream: string,
        group: string,
        consumer: string,
        minIdleMs: number,
        count: number,
        startId = '0-0',
    ): Promise<StreamEntry[]> {
        const client = this.getClient();
        if (!client) return [];

        const raw = await client.call(
            'XAUTOCLAIM',
            stream,
            group,
            consumer,
            String(minIdleMs),
            startId,
            'COUNT',
            String(count),
        );

        if (!Array.isArray(raw) || raw.length < 2) {
            return [];
        }

        return this.parseMessagesArray(raw[1]);
    }

    public static async ack(stream: string, group: string, id: string): Promise<void> {
        const client = this.getClient();
        if (!client) return;
        await client.call('XACK', stream, group, id);
    }

    public static async del(stream: string, id: string): Promise<void> {
        const client = this.getClient();
        if (!client) return;
        await client.call('XDEL', stream, id);
    }

    public static async scheduleRetry(
        retrySet: string,
        availableAtMs: number,
        fields: RedisFieldMap,
    ): Promise<void> {
        const client = this.getClient();
        if (!client) return;

        await client.call('ZADD', retrySet, String(availableAtMs), JSON.stringify(fields));
    }

    public static async drainDueRetries(retrySet: string, limit: number): Promise<RedisFieldMap[]> {
        const client = this.getClient();
        if (!client) return [];

        const raw = await client.call(
            'ZRANGEBYSCORE',
            retrySet,
            '-inf',
            String(Date.now()),
            'LIMIT',
            '0',
            String(limit),
        );

        if (!Array.isArray(raw) || raw.length === 0) {
            return [];
        }

        const payloads: RedisFieldMap[] = [];
        for (const member of raw) {
            try {
                payloads.push(JSON.parse(String(member)) as RedisFieldMap);
            } catch {
                continue;
            }
        }

        if (payloads.length > 0) {
            await client.call('ZREM', retrySet, ...raw.map((member) => String(member)));
        }

        return payloads;
    }

    public static async incrementCounter(key: string, ttlSeconds: number): Promise<number> {
        const client = this.getClient();
        if (!client) return 0;

        const raw = await client.call('INCR', key);
        await client.call('EXPIRE', key, String(ttlSeconds));
        return Number(raw || 0);
    }

    public static async deleteKey(key: string): Promise<void> {
        const client = this.getClient();
        if (!client) return;
        await client.call('DEL', key);
    }

    private static getClient(): RedisClientLike | null {
        return RedisClusterFactory.getClient('monitor') as RedisClientLike | null;
    }

    private static parseEntries(raw: unknown): StreamEntry[] {
        if (!Array.isArray(raw) || raw.length === 0) {
            return [];
        }

        const entries: StreamEntry[] = [];
        for (const streamChunk of raw) {
            if (!Array.isArray(streamChunk) || streamChunk.length < 2) {
                continue;
            }

            const messages = streamChunk[1];
            entries.push(...this.parseMessagesArray(messages));
        }

        return entries;
    }

    private static parseMessagesArray(messages: unknown): StreamEntry[] {
        if (!Array.isArray(messages)) {
            return [];
        }

        const entries: StreamEntry[] = [];
        for (const message of messages) {
            if (!Array.isArray(message) || message.length < 2) {
                continue;
            }

            const id = String(message[0]);
            const fieldsArray = message[1];
            const fields: RedisFieldMap = {};

            if (Array.isArray(fieldsArray)) {
                for (let i = 0; i < fieldsArray.length; i += 2) {
                    const key = fieldsArray[i];
                    const value = fieldsArray[i + 1];
                    if (key !== undefined && value !== undefined) {
                        fields[String(key)] = String(value);
                    }
                }
            }

            entries.push({ id, fields });
        }

        return entries;
    }
}
