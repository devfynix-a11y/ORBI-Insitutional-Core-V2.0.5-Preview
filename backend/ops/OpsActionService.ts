import { randomUUID } from 'node:crypto';
import { getOrbiDatabase } from '../../services/orbiDatabase.js';

export const OPS_ACTION_TYPES = [
  'DEPLOY_APPROVED_COMMIT',
  'RUN_MANUAL_BACKUP',
  'RESTORE_BACKUP_DRILL',
] as const;

export type OpsActionType = typeof OPS_ACTION_TYPES[number];

export type OpsActionStatus =
  | 'PENDING_APPROVAL'
  | 'READY'
  | 'QUEUED_FOR_AGENT'
  | 'COMPLETED'
  | 'FAILED'
  | 'CANCELLED';

export type OpsActionApproval = {
  operatorId: string;
  reason: string;
  approvedAt: string;
};

export type OpsActionRecord = {
  id: string;
  actionType: OpsActionType;
  status: OpsActionStatus;
  requestedBy: string;
  requestedReason: string;
  targetEnvironment: string;
  commandPlan: Record<string, unknown>;
  metadata: Record<string, unknown>;
  approvals: OpsActionApproval[];
  requiredApprovals: number;
  executedBy: string | null;
  executionResult: Record<string, unknown> | null;
  createdAt: string;
  updatedAt: string;
  approvedAt: string | null;
  executedAt: string | null;
  cancelledAt: string | null;
};

export type OpsActionRequestInput = {
  actionType: string;
  requestedBy: string;
  reason: string;
  targetEnvironment?: string;
  metadata?: Record<string, unknown>;
  confirmText?: string;
};

export type OpsActionApprovalInput = {
  operatorId: string;
  reason: string;
};

const MIN_REASON_LENGTH = 8;

const DEFAULT_REQUIRED_APPROVALS = 2;

const actionSet = new Set<string>(OPS_ACTION_TYPES);

const boolValue = (value: unknown) => String(value || '').trim().toLowerCase() === 'true';

const requiredApprovals = () => Math.max(
  DEFAULT_REQUIRED_APPROVALS,
  Number(process.env.ORBI_OPS_REQUIRED_APPROVALS || DEFAULT_REQUIRED_APPROVALS),
);

const safeText = (value: unknown) => String(value || '').trim();

export const normalizeOperatorId = (value: unknown): string => safeText(value).toLowerCase();

export const approvalCount = (approvals: OpsActionApproval[]): number => (
  new Set(approvals.map((approval) => normalizeOperatorId(approval.operatorId))).size
);

export const addApproval = (
  approvals: OpsActionApproval[],
  approval: OpsActionApproval,
): OpsActionApproval[] => {
  const normalized = normalizeOperatorId(approval.operatorId);
  if (!normalized) throw new Error('OPERATOR_ID_REQUIRED');
  if (approvals.some((item) => normalizeOperatorId(item.operatorId) === normalized)) {
    throw new Error('OPERATOR_ALREADY_APPROVED');
  }
  return [...approvals, { ...approval, operatorId: normalized }];
};

export const buildOpsCommandPlan = (
  actionType: OpsActionType,
  metadata: Record<string, unknown> = {},
) => {
  const envFile = process.env.ORBI_CORE_ENV_FILE || '/etc/orbi/core.env';
  if (actionType === 'DEPLOY_APPROVED_COMMIT') {
    const releaseRef = safeText(metadata.releaseRef);
    return {
      mode: 'vm-agent',
      actionType,
      releaseRef,
      commands: [
        `export ORBI_CORE_ENV_FILE=${envFile}`,
        'bash ops/self-hosted/scripts/validate-deployment.sh',
        releaseRef ? `git fetch --all --prune && git checkout ${releaseRef}` : 'git fetch --all --prune',
        'bash ops/self-hosted/scripts/deploy.sh',
        'curl --fail https://api.orbifinancial.com/ready',
      ],
      notes: [
        'The VM agent must resolve the release ref safely; shell interpolation is not allowed in the agent implementation.',
        'Deploy runs only after two distinct approvals.',
      ],
    };
  }

  if (actionType === 'RUN_MANUAL_BACKUP') {
    return {
      mode: 'vm-agent',
      actionType,
      commands: [
        `export ORBI_CORE_ENV_FILE=${envFile}`,
        'bash ops/self-hosted/scripts/backup-now.sh',
        'docker compose --env-file /etc/orbi/core.env -f ops/self-hosted/docker-compose.prod.yml logs --tail=100 database-backup backup-r2-replicator',
      ],
      notes: ['Manual backup produces encrypted live-disk artifacts and R2 mirror evidence.'],
    };
  }

  const backupArtifact = safeText(metadata.backupArtifact);
  return {
    mode: 'vm-agent',
    actionType,
    backupArtifact,
    commands: [
      `export ORBI_CORE_ENV_FILE=${envFile}`,
      'export ORBI_CONFIRM_RESTORE=YES',
      `bash ops/self-hosted/scripts/restore-database.sh /srv/orbi/backups/database/${backupArtifact || '<backup>.dump.enc'}`,
      'npm run test:db:financial',
      'npm run test:db:financial:write',
      'npm test',
    ],
    notes: [
      'Restore drills must target isolated/staging infrastructure, never production.',
      'Production restore requires a separate incident runbook and cannot be triggered from this console.',
    ],
  };
};

export const validateActionRequestInput = (input: OpsActionRequestInput) => {
  const actionType = safeText(input.actionType) as OpsActionType;
  const requestedBy = normalizeOperatorId(input.requestedBy);
  const reason = safeText(input.reason);
  const targetEnvironment = safeText(input.targetEnvironment || 'staging').toLowerCase();
  const metadata = input.metadata && typeof input.metadata === 'object' ? input.metadata : {};

  if (!actionSet.has(actionType)) throw new Error('UNSUPPORTED_OPS_ACTION');
  if (!requestedBy) throw new Error('REQUESTED_BY_REQUIRED');
  if (reason.length < MIN_REASON_LENGTH) throw new Error('AUDIT_REASON_REQUIRED');

  if (actionType === 'DEPLOY_APPROVED_COMMIT' && !safeText(metadata.releaseRef)) {
    throw new Error('RELEASE_REF_REQUIRED');
  }

  if (actionType === 'RESTORE_BACKUP_DRILL') {
    if (!['staging', 'isolated', 'drill'].includes(targetEnvironment)) {
      throw new Error('RESTORE_DRILL_CANNOT_TARGET_PRODUCTION');
    }
    if (!safeText(metadata.backupArtifact).endsWith('.dump.enc')) {
      throw new Error('ENCRYPTED_BACKUP_ARTIFACT_REQUIRED');
    }
    if (safeText(input.confirmText) !== 'RESTORE DRILL') {
      throw new Error('RESTORE_DRILL_CONFIRMATION_REQUIRED');
    }
  }

  return {
    actionType,
    requestedBy,
    reason,
    targetEnvironment,
    metadata,
    commandPlan: buildOpsCommandPlan(actionType, metadata),
  };
};

const parseJson = <T>(value: unknown, fallback: T): T => {
  if (Array.isArray(value) || (value && typeof value === 'object')) return value as T;
  if (typeof value !== 'string') return fallback;
  try {
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
};

const mapRow = (row: any): OpsActionRecord => ({
  id: row.id,
  actionType: row.action_type,
  status: row.status,
  requestedBy: row.requested_by,
  requestedReason: row.requested_reason,
  targetEnvironment: row.target_environment,
  commandPlan: parseJson(row.command_plan, {}),
  metadata: parseJson(row.metadata, {}),
  approvals: parseJson(row.approvals, []),
  requiredApprovals: Number(row.required_approvals || DEFAULT_REQUIRED_APPROVALS),
  executedBy: row.executed_by,
  executionResult: parseJson(row.execution_result, null),
  createdAt: new Date(row.created_at).toISOString(),
  updatedAt: new Date(row.updated_at).toISOString(),
  approvedAt: row.approved_at ? new Date(row.approved_at).toISOString() : null,
  executedAt: row.executed_at ? new Date(row.executed_at).toISOString() : null,
  cancelledAt: row.cancelled_at ? new Date(row.cancelled_at).toISOString() : null,
});

export class OpsActionService {
  private static schemaReady = false;

  static async ensureSchema() {
    if (this.schemaReady) return;
    await getOrbiDatabase().query(`
      CREATE TABLE IF NOT EXISTS public.ops_action_requests (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        action_type TEXT NOT NULL CHECK (action_type IN ('DEPLOY_APPROVED_COMMIT', 'RUN_MANUAL_BACKUP', 'RESTORE_BACKUP_DRILL')),
        status TEXT NOT NULL DEFAULT 'PENDING_APPROVAL' CHECK (status IN ('PENDING_APPROVAL', 'READY', 'QUEUED_FOR_AGENT', 'COMPLETED', 'FAILED', 'CANCELLED')),
        requested_by TEXT NOT NULL,
        requested_reason TEXT NOT NULL,
        target_environment TEXT NOT NULL DEFAULT 'staging',
        command_plan JSONB NOT NULL DEFAULT '{}'::jsonb,
        metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
        approvals JSONB NOT NULL DEFAULT '[]'::jsonb,
        required_approvals INTEGER NOT NULL DEFAULT 2 CHECK (required_approvals >= 2),
        executed_by TEXT,
        execution_result JSONB,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        approved_at TIMESTAMPTZ,
        executed_at TIMESTAMPTZ,
        cancelled_at TIMESTAMPTZ
      );
      CREATE INDEX IF NOT EXISTS idx_ops_action_requests_status_created ON public.ops_action_requests(status, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_ops_action_requests_type_created ON public.ops_action_requests(action_type, created_at DESC);
    `);
    this.schemaReady = true;
  }

  static async list(limit = 50): Promise<OpsActionRecord[]> {
    await this.ensureSchema();
    const result = await getOrbiDatabase().query(
      'SELECT * FROM public.ops_action_requests ORDER BY created_at DESC LIMIT $1',
      [Math.min(Math.max(limit, 1), 100)],
    );
    return result.rows.map(mapRow);
  }

  static async request(input: OpsActionRequestInput): Promise<OpsActionRecord> {
    await this.ensureSchema();
    const normalized = validateActionRequestInput(input);
    const id = randomUUID();
    const result = await getOrbiDatabase().query(
      `INSERT INTO public.ops_action_requests (
        id, action_type, requested_by, requested_reason, target_environment, command_plan, metadata, required_approvals
      )
      VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8)
      RETURNING *`,
      [
        id,
        normalized.actionType,
        normalized.requestedBy,
        normalized.reason,
        normalized.targetEnvironment,
        JSON.stringify(normalized.commandPlan),
        JSON.stringify(normalized.metadata),
        requiredApprovals(),
      ],
    );
    return mapRow(result.rows[0]);
  }

  static async approve(id: string, input: OpsActionApprovalInput): Promise<OpsActionRecord> {
    await this.ensureSchema();
    const operatorId = normalizeOperatorId(input.operatorId);
    const reason = safeText(input.reason);
    if (!operatorId) throw new Error('OPERATOR_ID_REQUIRED');
    if (reason.length < MIN_REASON_LENGTH) throw new Error('AUDIT_REASON_REQUIRED');

    const client = await getOrbiDatabase().connect();
    try {
      await client.query('BEGIN');
      const current = await client.query(
        'SELECT * FROM public.ops_action_requests WHERE id = $1 FOR UPDATE',
        [id],
      );
      if (!current.rowCount) throw new Error('OPS_ACTION_NOT_FOUND');
      const record = mapRow(current.rows[0]);
      if (!['PENDING_APPROVAL', 'READY'].includes(record.status)) {
        throw new Error('OPS_ACTION_NOT_APPROVABLE');
      }
      if (normalizeOperatorId(record.requestedBy) === operatorId) {
        throw new Error('REQUESTER_CANNOT_APPROVE_OWN_ACTION');
      }
      const approvals = addApproval(record.approvals, {
        operatorId,
        reason,
        approvedAt: new Date().toISOString(),
      });
      const ready = approvalCount(approvals) >= record.requiredApprovals;
      const updated = await client.query(
        `UPDATE public.ops_action_requests
         SET approvals = $2::jsonb,
             status = $3,
             approved_at = CASE WHEN $3 = 'READY' THEN COALESCE(approved_at, NOW()) ELSE approved_at END,
             updated_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [id, JSON.stringify(approvals), ready ? 'READY' : 'PENDING_APPROVAL'],
      );
      await client.query('COMMIT');
      return mapRow(updated.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  static async cancel(id: string, input: OpsActionApprovalInput): Promise<OpsActionRecord> {
    await this.ensureSchema();
    const operatorId = normalizeOperatorId(input.operatorId);
    const reason = safeText(input.reason);
    if (!operatorId) throw new Error('OPERATOR_ID_REQUIRED');
    if (reason.length < MIN_REASON_LENGTH) throw new Error('AUDIT_REASON_REQUIRED');
    const result = await getOrbiDatabase().query(
      `UPDATE public.ops_action_requests
       SET status = 'CANCELLED',
           executed_by = $2,
           execution_result = $3::jsonb,
           cancelled_at = NOW(),
           updated_at = NOW()
       WHERE id = $1 AND status IN ('PENDING_APPROVAL', 'READY', 'FAILED')
       RETURNING *`,
      [id, operatorId, JSON.stringify({ cancelledBy: operatorId, reason })],
    );
    if (!result.rowCount) throw new Error('OPS_ACTION_NOT_CANCELLABLE');
    return mapRow(result.rows[0]);
  }

  static async execute(id: string, input: OpsActionApprovalInput): Promise<OpsActionRecord> {
    await this.ensureSchema();
    const operatorId = normalizeOperatorId(input.operatorId);
    const reason = safeText(input.reason);
    if (!operatorId) throw new Error('OPERATOR_ID_REQUIRED');
    if (reason.length < MIN_REASON_LENGTH) throw new Error('AUDIT_REASON_REQUIRED');

    const current = await getOrbiDatabase().query(
      'SELECT * FROM public.ops_action_requests WHERE id = $1',
      [id],
    );
    if (!current.rowCount) throw new Error('OPS_ACTION_NOT_FOUND');
    const record = mapRow(current.rows[0]);
    if (record.status !== 'READY') throw new Error('OPS_ACTION_NOT_READY');
    if (approvalCount(record.approvals) < record.requiredApprovals) {
      throw new Error('TWO_PERSON_APPROVAL_REQUIRED');
    }
    if (!boolValue(process.env.ORBI_OPS_AGENT_EXECUTION_ENABLED)) {
      throw new Error('OPS_AGENT_EXECUTION_DISABLED');
    }

    const result = await getOrbiDatabase().query(
      `UPDATE public.ops_action_requests
       SET status = 'QUEUED_FOR_AGENT',
           executed_by = $2,
           execution_result = $3::jsonb,
           executed_at = NOW(),
           updated_at = NOW()
       WHERE id = $1 AND status = 'READY'
       RETURNING *`,
      [
        id,
        operatorId,
        JSON.stringify({
          queuedBy: operatorId,
          reason,
          queuedAt: new Date().toISOString(),
          agentMode: 'whitelisted-command-plan',
          commandPlan: record.commandPlan,
        }),
      ],
    );
    if (!result.rowCount) throw new Error('OPS_ACTION_QUEUE_FAILED');
    return mapRow(result.rows[0]);
  }
}
