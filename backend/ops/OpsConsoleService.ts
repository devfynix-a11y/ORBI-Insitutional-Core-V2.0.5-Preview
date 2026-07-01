import fs from 'node:fs/promises';
import path from 'node:path';
import { operationalHealthService } from '../infrastructure/OperationalHealthService.js';

type BackupArtifact = {
  name: string;
  sizeBytes: number;
  modifiedAt: string;
  kind: 'encrypted_dump' | 'checksum' | 'manifest' | 'other';
};

const boolValue = (value: unknown) => String(value || '').trim().toLowerCase() === 'true';

const configured = (value: unknown) => String(value || '').trim().length > 0;

const redactState = (value: unknown) => configured(value);

const backupKind = (name: string): BackupArtifact['kind'] => {
  if (name.endsWith('.dump.enc')) return 'encrypted_dump';
  if (name.endsWith('.sha256')) return 'checksum';
  if (name.endsWith('.manifest')) return 'manifest';
  return 'other';
};

const backupDir = () => String(process.env.ORBI_BACKUP_LOCAL_DIR || '/srv/orbi/backups/database').trim();

export class OpsConsoleService {
  static async overview() {
    const [health, backups] = await Promise.all([
      operationalHealthService.captureSnapshot().catch((error: any) => ({
        status: 'CRITICAL',
        error: error?.message || 'OPERATIONAL_HEALTH_UNAVAILABLE',
      })),
      this.listLocalBackups().catch((error: any) => ({
        available: false,
        directory: backupDir(),
        error: error?.message || 'BACKUP_DIRECTORY_UNAVAILABLE',
        artifacts: [],
      })),
    ]);

    return {
      generatedAt: new Date().toISOString(),
      deployment: {
        releaseId: process.env.ORBI_RELEASE_ID || 'local',
        nodeEnv: process.env.NODE_ENV || 'development',
        coreBaseUrl: process.env.ORBI_PRIMARY_CORE_BASE_URL || process.env.BACKEND_URL || null,
        keycloakIssuer: process.env.ORBI_KEYCLOAK_ISSUER || null,
        dataProvider: process.env.ORBI_DATA_PROVIDER || 'supabase',
        authProvider: process.env.ORBI_AUTH_PROVIDER || 'supabase',
        localDataProductionReady: boolValue(process.env.ORBI_LOCAL_DATA_PRODUCTION_READY),
      },
      safety: {
        gatewayBackgroundJobsEnabled: boolValue(process.env.ORBI_ENABLE_GATEWAY_BACKGROUND_JOBS),
        internalBackgroundJobsEnabled: boolValue(process.env.ORBI_ENABLE_INTERNAL_BACKGROUND_JOBS),
        sandboxRoutesEnabled: boolValue(process.env.ORBI_ENABLE_SANDBOX_ROUTES),
        messagingTestRoutesEnabled: boolValue(process.env.ORBI_ENABLE_MESSAGING_TEST_ROUTES),
        requireWebhookSignatures: process.env.ORBI_REQUIRE_WEBHOOK_SIGNATURES !== 'false',
        apiGatewayFailClosed: process.env.ORBI_API_GATEWAY_FAIL_CLOSED !== 'false',
      },
      secrets: {
        postgres: redactState(process.env.ORBI_POSTGRES_PASSWORD),
        valkey: redactState(process.env.ORBI_VALKEY_PASSWORD),
        keycloakAdmin: redactState(process.env.ORBI_KEYCLOAK_ADMIN_PASSWORD),
        backupEncryption: redactState(process.env.ORBI_BACKUP_ENCRYPTION_KEY),
        cloudflareR2: redactState(process.env.CLOUDFLARE_ACCOUNT_ID)
          && redactState(process.env.CLOUDFLARE_ACCESS_KEY_ID)
          && redactState(process.env.CLOUDFLARE_SECRET_ACCESS_KEY),
        firebase: redactState(process.env.FIREBASE_SERVICE_ACCOUNT_JSON_BASE64),
        talkGateway: redactState(process.env.ORBI_TALK_GATEWAY_API_KEY),
        payGateway: redactState(process.env.ORBI_PAY_GATEWAY_OPERATOR_DISCOVERY_API_KEY),
      },
      backups,
      health,
      actions: {
        vmAgentExecutionEnabled: boolValue(process.env.ORBI_OPS_AGENT_EXECUTION_ENABLED),
        requiredApprovals: Math.max(2, Number(process.env.ORBI_OPS_REQUIRED_APPROVALS || 2)),
        destructiveActionsEnabled: boolValue(process.env.ORBI_OPS_DESTRUCTIVE_ACTIONS_ENABLED),
        reason: boolValue(process.env.ORBI_OPS_AGENT_EXECUTION_ENABLED)
          ? 'Approved actions can be queued for the VM agent after two distinct operators approve them.'
          : 'Action requests and approvals are enabled, but VM agent execution is fail-closed until ORBI_OPS_AGENT_EXECUTION_ENABLED=true.',
      },
    };
  }

  static deploymentPlan() {
    const envFile = process.env.ORBI_CORE_ENV_FILE || '/etc/orbi/core.env';
    return {
      title: 'Approved production deployment flow',
      envFile,
      commands: [
        `export ORBI_CORE_ENV_FILE=${envFile}`,
        'bash ops/self-hosted/scripts/validate-deployment.sh',
        'bash ops/self-hosted/scripts/deploy.sh',
        'curl --fail https://api.orbifinancial.com/ready',
        'curl --fail https://auth.orbifinancial.com/realms/orbi/.well-known/openid-configuration',
      ],
      gates: [
        'Deploy only reviewed commits.',
        'Keep background settlement jobs disabled until restore and reconciliation are signed off.',
        'Run smoke checks before switching traffic.',
        'Rollback API and workers together.',
      ],
    };
  }

  static backupPlan() {
    return {
      localDirectory: backupDir(),
      r2Bucket: process.env.ORBI_BACKUP_R2_BUCKET || process.env.CLOUDFLARE_BUCKET_NAME || null,
      r2Prefix: process.env.ORBI_BACKUP_R2_PREFIX || 'database-backups',
      intervalSeconds: Number(process.env.ORBI_BACKUP_INTERVAL_SECONDS || 86400),
      retentionDays: Number(process.env.ORBI_BACKUP_RETENTION_DAYS || 14),
      commands: [
        'bash ops/self-hosted/scripts/backup-now.sh',
        'docker compose --env-file /etc/orbi/core.env -f ops/self-hosted/docker-compose.prod.yml logs --tail=100 database-backup backup-r2-replicator',
      ],
      evidence: [
        'Encrypted .dump.enc artifact exists on live disk.',
        'SHA-256 checksum exists beside the artifact.',
        'Manifest records created_at, database, format, and checksum.',
        'R2 object exists under the configured backup prefix.',
      ],
    };
  }

  static restoreDrillPlan() {
    return {
      warning: 'Never restore directly over production without an incident commander, typed confirmation, and current backup evidence.',
      isolatedHostRequired: true,
      commands: [
        'export ORBI_CORE_ENV_FILE=/etc/orbi/core.env',
        'export ORBI_CONFIRM_RESTORE=YES',
        'bash ops/self-hosted/scripts/restore-database.sh /srv/orbi/backups/database/<backup>.dump.enc',
        'npm run test:db:financial',
        'npm run test:db:financial:write',
        'npm test',
      ],
      reconciliationEvidence: [
        'wallet balances equal ledger-derived balances',
        'transaction counts match expected snapshot',
        'settlement backlog reviewed',
        'audit chain and critical RPCs verified',
      ],
    };
  }

  private static async listLocalBackups() {
    const directory = backupDir();
    const entries = await fs.readdir(directory, { withFileTypes: true });
    const artifacts: BackupArtifact[] = [];
    for (const entry of entries) {
      if (!entry.isFile()) continue;
      const fullPath = path.join(directory, entry.name);
      const stat = await fs.stat(fullPath);
      artifacts.push({
        name: entry.name,
        sizeBytes: stat.size,
        modifiedAt: stat.mtime.toISOString(),
        kind: backupKind(entry.name),
      });
    }
    artifacts.sort((a, b) => b.modifiedAt.localeCompare(a.modifiedAt));
    return {
      available: true,
      directory,
      artifacts: artifacts.slice(0, 50),
    };
  }
}
