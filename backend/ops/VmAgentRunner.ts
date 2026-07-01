import { spawn } from 'node:child_process';
import { basename, resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import dotenv from 'dotenv';
import { closeOrbiDatabase, getOrbiDatabase } from '../../services/orbiDatabase.js';

dotenv.config();
if (process.env.ORBI_CORE_ENV_FILE) {
  dotenv.config({ path: process.env.ORBI_CORE_ENV_FILE, override: false });
}
if (process.env.ORBI_OPS_AGENT_DATABASE_URL) {
  process.env.DATABASE_URL = process.env.ORBI_OPS_AGENT_DATABASE_URL;
}

const AGENT_ID = String(process.env.ORBI_OPS_AGENT_ID || 'orbi-vm-agent').trim();
const ROOT_DIR = resolve(String(process.env.ORBI_OPS_AGENT_ROOT || process.cwd()));
const ENV_FILE = String(process.env.ORBI_CORE_ENV_FILE || resolve(ROOT_DIR, 'ops/self-hosted/.env.production'));
const POLL_MS = Math.max(5000, Number(process.env.ORBI_OPS_AGENT_POLL_MS || 15000));
const COMMAND_TIMEOUT_MS = Math.max(60000, Number(process.env.ORBI_OPS_AGENT_COMMAND_TIMEOUT_MS || 20 * 60 * 1000));
const OUTPUT_LIMIT = Math.max(4000, Number(process.env.ORBI_OPS_AGENT_OUTPUT_LIMIT || 24000));
const RUN_ONCE = String(process.env.ORBI_OPS_AGENT_RUN_ONCE || '').toLowerCase() === 'true';

type ActionRow = {
  id: string;
  action_type: 'DEPLOY_APPROVED_COMMIT' | 'RUN_MANUAL_BACKUP' | 'RESTORE_BACKUP_DRILL';
  target_environment: string;
  metadata: Record<string, unknown> | string | null;
};

type CommandResult = {
  command: string;
  exitCode: number | null;
  durationMs: number;
  outputTail: string;
};

const now = () => new Date().toISOString();

const envForCommand = () => ({
  ...process.env,
  ORBI_CORE_ENV_FILE: ENV_FILE,
});

const parseJson = <T>(value: unknown, fallback: T): T => {
  if (value && typeof value === 'object') return value as T;
  if (typeof value !== 'string') return fallback;
  try {
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
};

const appendTail = (current: string, next: string) => {
  const combined = current + next;
  return combined.length > OUTPUT_LIMIT ? combined.slice(combined.length - OUTPUT_LIMIT) : combined;
};

const validateReleaseRef = (value: unknown): string => {
  const releaseRef = String(value || '').trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9._/-]{0,119}$/.test(releaseRef)) {
    throw new Error('INVALID_RELEASE_REF');
  }
  if (releaseRef.includes('..') || releaseRef.includes('//') || releaseRef.endsWith('/')) {
    throw new Error('UNSAFE_RELEASE_REF');
  }
  return releaseRef;
};

const validateBackupArtifact = (value: unknown): string => {
  const artifact = basename(String(value || '').trim());
  if (!/^[A-Za-z0-9._-]+\.dump\.enc$/.test(artifact)) {
    throw new Error('INVALID_BACKUP_ARTIFACT');
  }
  return artifact;
};

const runCommand = async (command: string, args: string[], timeoutMs = COMMAND_TIMEOUT_MS): Promise<CommandResult> => {
  const startedAt = Date.now();
  let outputTail = '';

  return await new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(command, args, {
      cwd: ROOT_DIR,
      env: envForCommand(),
      shell: false,
      windowsHide: true,
    });
    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      setTimeout(() => child.kill('SIGKILL'), 5000).unref();
    }, timeoutMs);

    child.stdout.on('data', (chunk) => {
      outputTail = appendTail(outputTail, chunk.toString());
    });
    child.stderr.on('data', (chunk) => {
      outputTail = appendTail(outputTail, chunk.toString());
    });
    child.on('error', (error) => {
      clearTimeout(timer);
      rejectPromise(error);
    });
    child.on('close', (exitCode) => {
      clearTimeout(timer);
      const result = {
        command: [command, ...args].join(' '),
        exitCode,
        durationMs: Date.now() - startedAt,
        outputTail,
      };
      if (exitCode === 0) {
        resolvePromise(result);
      } else {
        const error = new Error(`COMMAND_FAILED:${result.command}`);
        Object.assign(error, { commandResult: result });
        rejectPromise(error);
      }
    });
  });
};

const runBashScript = (scriptPath: string, args: string[] = []) => (
  runCommand('bash', [scriptPath, ...args])
);

const markFailed = async (id: string, error: unknown, results: CommandResult[]) => {
  const commandResult = typeof error === 'object' && error ? (error as any).commandResult : null;
  await getOrbiDatabase().query(
    `UPDATE public.ops_action_requests
     SET status = 'FAILED',
         execution_result = $2::jsonb,
         updated_at = NOW()
     WHERE id = $1`,
    [
      id,
      JSON.stringify({
        agentId: AGENT_ID,
        failedAt: now(),
        error: error instanceof Error ? error.message : String(error),
        results: commandResult ? [...results, commandResult] : results,
      }),
    ],
  );
};

const markCompleted = async (id: string, results: CommandResult[]) => {
  await getOrbiDatabase().query(
    `UPDATE public.ops_action_requests
     SET status = 'COMPLETED',
         execution_result = $2::jsonb,
         updated_at = NOW()
     WHERE id = $1`,
    [
      id,
      JSON.stringify({
        agentId: AGENT_ID,
        completedAt: now(),
        results,
      }),
    ],
  );
};

const claimNextAction = async (): Promise<ActionRow | null> => {
  const result = await getOrbiDatabase().query(
    `WITH next_action AS (
       SELECT id
       FROM public.ops_action_requests
       WHERE status = 'QUEUED_FOR_AGENT'
       ORDER BY executed_at ASC NULLS LAST, updated_at ASC
       LIMIT 1
       FOR UPDATE SKIP LOCKED
     )
     UPDATE public.ops_action_requests actions
     SET execution_result = jsonb_build_object(
           'agentId', $1::text,
           'claimedAt', NOW(),
           'state', 'RUNNING'
         ),
         updated_at = NOW()
     FROM next_action
     WHERE actions.id = next_action.id
     RETURNING actions.id, actions.action_type, actions.target_environment, actions.metadata`,
    [AGENT_ID],
  );
  return result.rows[0] || null;
};

const executeDeploy = async (metadata: Record<string, unknown>): Promise<CommandResult[]> => {
  const releaseRef = validateReleaseRef(metadata.releaseRef);
  const results: CommandResult[] = [];
  results.push(await runCommand('git', ['diff', '--quiet']));
  results.push(await runCommand('git', ['diff', '--cached', '--quiet']));
  results.push(await runCommand('git', ['fetch', '--all', '--prune']));
  const resolved = await runCommand('git', ['rev-parse', '--verify', `${releaseRef}^{commit}`]);
  const commitSha = resolved.outputTail.trim().split(/\s+/).pop() || releaseRef;
  results.push(resolved);
  results.push(await runCommand('git', ['checkout', '--detach', commitSha]));
  results.push(await runBashScript('ops/self-hosted/scripts/validate-deployment.sh'));
  results.push(await runBashScript('ops/self-hosted/scripts/deploy.sh'));
  results.push(await runCommand('curl', ['--fail', 'https://api.orbifinancial.com/ready'], 90000));
  return results;
};

const executeBackup = async (): Promise<CommandResult[]> => [
  await runBashScript('ops/self-hosted/scripts/backup-now.sh'),
];

const executeRestoreDrill = async (
  targetEnvironment: string,
  metadata: Record<string, unknown>,
): Promise<CommandResult[]> => {
  if (String(process.env.ORBI_OPS_DESTRUCTIVE_ACTIONS_ENABLED || '').toLowerCase() !== 'true') {
    throw new Error('DESTRUCTIVE_ACTIONS_DISABLED');
  }
  if (!['staging', 'isolated', 'drill'].includes(targetEnvironment)) {
    throw new Error('RESTORE_DRILL_TARGET_BLOCKED');
  }
  const artifact = validateBackupArtifact(metadata.backupArtifact);
  return [
    await runBashScript('ops/self-hosted/scripts/restore-drill.sh', [`/backups/${artifact}`]),
  ];
};

const executeAction = async (action: ActionRow) => {
  const metadata = parseJson<Record<string, unknown>>(action.metadata, {});
  const results: CommandResult[] = [];
  try {
    let actionResults: CommandResult[];
    if (action.action_type === 'DEPLOY_APPROVED_COMMIT') {
      actionResults = await executeDeploy(metadata);
    } else if (action.action_type === 'RUN_MANUAL_BACKUP') {
      actionResults = await executeBackup();
    } else if (action.action_type === 'RESTORE_BACKUP_DRILL') {
      actionResults = await executeRestoreDrill(action.target_environment, metadata);
    } else {
      throw new Error('UNSUPPORTED_AGENT_ACTION');
    }
    results.push(...actionResults);
    await markCompleted(action.id, results);
    console.log(`[OpsVmAgent] Completed ${action.action_type} ${action.id}`);
  } catch (error) {
    await markFailed(action.id, error, results);
    console.error(`[OpsVmAgent] Failed ${action.action_type} ${action.id}:`, error);
  }
};

const tick = async () => {
  const action = await claimNextAction();
  if (!action) return false;
  console.log(`[OpsVmAgent] Claimed ${action.action_type} ${action.id}`);
  await executeAction(action);
  return true;
};

const main = async () => {
  console.log(`[OpsVmAgent] Started ${AGENT_ID} in ${ROOT_DIR}`);
  while (true) {
    try {
      const worked = await tick();
      if (RUN_ONCE) break;
      if (!worked) await delay(POLL_MS);
    } catch (error) {
      console.error('[OpsVmAgent] Poll failed:', error);
      if (RUN_ONCE) throw error;
      await delay(POLL_MS);
    }
  }
};

process.on('SIGINT', async () => {
  await closeOrbiDatabase();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await closeOrbiDatabase();
  process.exit(0);
});

await main();
await closeOrbiDatabase();
