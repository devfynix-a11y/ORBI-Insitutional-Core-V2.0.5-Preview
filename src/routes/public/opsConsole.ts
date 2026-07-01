import type { Express, Request, Response } from 'express';
import { OpsActionService } from '../../../backend/ops/OpsActionService.js';
import { OpsConsoleService } from '../../../backend/ops/OpsConsoleService.js';

const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>ORBI Operations Console</title>
  <style>
    :root {
      color-scheme: light;
      --ink: #15201c;
      --muted: #65736e;
      --line: #dfe7e2;
      --panel: rgba(255, 255, 255, 0.88);
      --accent: #0f6b4d;
      --danger: #a33131;
      --warn: #9a6a10;
      --bg: #edf5ef;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: Georgia, "Times New Roman", serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(36, 107, 78, 0.22), transparent 34rem),
        linear-gradient(135deg, #f8fbf4 0%, var(--bg) 42%, #e3efe7 100%);
      min-height: 100vh;
    }
    main { width: min(1240px, calc(100% - 32px)); margin: 0 auto; padding: 42px 0; }
    header { display: flex; justify-content: space-between; gap: 24px; align-items: flex-end; margin-bottom: 28px; }
    h1 { margin: 0; font-size: clamp(2rem, 5vw, 4.6rem); line-height: 0.95; letter-spacing: -0.06em; }
    h2 { margin: 0 0 10px; font-size: 1.35rem; }
    p { color: var(--muted); line-height: 1.55; }
    button {
      border: 0; border-radius: 999px; background: var(--accent); color: white;
      padding: 11px 16px; font-weight: 700; cursor: pointer;
      box-shadow: 0 12px 24px rgba(15, 107, 77, 0.16); margin: 4px 4px 0 0;
    }
    button.secondary { background: #31423b; }
    button.warn { background: var(--warn); }
    button.danger { background: var(--danger); }
    input, select, textarea {
      width: 100%; border: 1px solid var(--line); border-radius: 16px; padding: 11px 12px;
      background: rgba(255, 255, 255, 0.86); color: var(--ink); margin: 5px 0 11px;
    }
    textarea { min-height: 78px; resize: vertical; }
    label { display: block; color: var(--muted); font-size: 0.82rem; font-weight: 700; }
    .grid { display: grid; grid-template-columns: repeat(12, 1fr); gap: 16px; }
    .card {
      grid-column: span 4;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 20px;
      box-shadow: 0 18px 50px rgba(37, 55, 47, 0.08);
      backdrop-filter: blur(14px);
    }
    .wide { grid-column: span 8; }
    .half { grid-column: span 6; }
    .full { grid-column: 1 / -1; }
    .label { color: var(--muted); font-size: 0.78rem; letter-spacing: 0.12em; text-transform: uppercase; }
    .value { font-size: 1.7rem; margin-top: 8px; font-weight: 700; overflow-wrap: anywhere; }
    .pill { display: inline-flex; padding: 7px 10px; border-radius: 999px; background: #e4f1ea; color: var(--accent); font-weight: 700; margin: 4px 4px 0 0; }
    .bad { background: #f8e3e3; color: var(--danger); }
    .status { background: #eaf0ed; color: #31423b; }
    pre {
      white-space: pre-wrap; overflow-wrap: anywhere; background: #14221d; color: #eafff6;
      padding: 16px; border-radius: 18px; font-size: 0.9rem;
    }
    table { width: 100%; border-collapse: collapse; font-size: 0.92rem; }
    td, th { padding: 10px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }
    @media (max-width: 860px) { header { display: block; } .card, .wide, .half { grid-column: 1 / -1; } }
  </style>
</head>
<body>
  <main>
    <header>
      <div>
        <div class="label">Private Infrastructure</div>
        <h1>ORBI Operations Console</h1>
        <p>Deployment, backup, restore-drill, and VM-agent approvals. Keep this behind Cloudflare Access or VPN.</p>
      </div>
      <button id="refresh">Refresh Secure State</button>
    </header>
    <section class="grid" id="root">
      <article class="card full"><p>Loading secure operations console...</p></article>
    </section>
  </main>
  <script>
    let monitorKey = sessionStorage.getItem('orbi_monitor_key') || '';
    let operatorId = sessionStorage.getItem('orbi_operator_id') || '';
    const root = document.getElementById('root');
    const asJson = (value) => JSON.stringify(value, null, 2);
    const esc = (value) => String(value == null ? '' : value).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
    const pill = (label, ok) => '<span class="pill ' + (ok ? '' : 'bad') + '">' + esc(label) + ': ' + (ok ? 'OK' : 'CHECK') + '</span>';
    function renderUnlock(message = '') {
      root.innerHTML = [
        '<article class="card wide">',
        '<div class="label">Secure Access</div>',
        '<h2>Unlock Operations Console</h2>',
        '<p>Enter the monitor key and your operator ID. Values stay in this browser session and are never displayed back.</p>',
        message ? '<pre>' + esc(message) + '</pre>' : '',
        '<label>Monitor key</label><input id="monitorKeyInput" type="password" autocomplete="off" placeholder="Paste monitor key" />',
        '<label>Operator ID</label><input id="operatorIdInput" autocomplete="username" placeholder="admin-name or operator id" value="' + esc(operatorId) + '" />',
        '<button id="unlockOps">Unlock Console</button>',
        '</article>',
        '<article class="card"><div class="label">Protection</div><div class="value">2 approvals</div><p>Deploy, backup, and restore-drill requests stay behind audited approval flow.</p></article>',
        '<article class="card"><div class="label">VM Agent</div><div class="value">Controlled</div><p>The UI queues approved actions only. It does not expose arbitrary shell.</p></article>',
      ].join('');
      document.getElementById('unlockOps')?.addEventListener('click', async () => {
        monitorKey = document.getElementById('monitorKeyInput')?.value || '';
        operatorId = document.getElementById('operatorIdInput')?.value || '';
        if (!monitorKey || !operatorId) {
          renderUnlock('Monitor key and operator ID are required.');
          return;
        }
        sessionStorage.setItem('orbi_monitor_key', monitorKey);
        sessionStorage.setItem('orbi_operator_id', operatorId);
        await refresh();
      });
    }
    function ensureIdentity() {
      monitorKey = monitorKey || sessionStorage.getItem('orbi_monitor_key') || '';
      operatorId = operatorId || sessionStorage.getItem('orbi_operator_id') || '';
      return Boolean(monitorKey && operatorId);
    }
    async function requestJson(path, options = {}) {
      if (!ensureIdentity()) throw new Error('IDENTITY_REQUIRED');
      const response = await fetch(path, {
        ...options,
        headers: {
          'content-type': 'application/json',
          'x-orbi-monitor-key': monitorKey,
          'x-orbi-operator-id': operatorId,
          ...(options.headers || {}),
        },
      });
      const json = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error((json && json.error) || path + ' -> ' + response.status);
      return json;
    }
    async function getJson(path) {
      return requestJson(path);
    }
    async function postJson(path, body) {
      return requestJson(path, { method: 'POST', body: JSON.stringify(body || {}) });
    }
    async function refresh() {
      if (!ensureIdentity()) {
        renderUnlock();
        return;
      }
      root.innerHTML = '<article class="card full"><p>Loading operations state...</p></article>';
      try {
        const [overview, deploy, backup, restore, actions] = await Promise.all([
          getJson('/api/admin/ops/overview'),
          getJson('/api/admin/ops/deployment-plan'),
          getJson('/api/admin/ops/backup-plan'),
          getJson('/api/admin/ops/restore-drill-plan'),
          getJson('/api/admin/ops/actions'),
        ]);
        const data = overview.data;
        const artifacts = data.backups.artifacts || [];
        root.innerHTML = [
          '<article class="card"><div class="label">Platform</div><div class="value">' + esc(data.health.status) + '</div><p>' + esc(data.deployment.releaseId) + '</p></article>',
          '<article class="card"><div class="label">Agent Gate</div><div class="value">' + (data.actions.vmAgentExecutionEnabled ? 'Enabled' : 'Locked') + '</div><p>' + esc(data.actions.reason) + '</p></article>',
          '<article class="card"><div class="label">Backup Artifacts</div><div class="value">' + artifacts.length + '</div><p>' + esc(data.backups.directory) + '</p></article>',
          '<article class="card wide"><div class="label">Safety Switches</div><p>' +
            pill('Gateway jobs', data.safety.gatewayBackgroundJobsEnabled) +
            pill('Internal jobs', !data.safety.internalBackgroundJobsEnabled) +
            pill('Sandbox routes', !data.safety.sandboxRoutesEnabled) +
            pill('Webhook signatures', data.safety.requireWebhookSignatures) +
          '</p></article>',
          '<article class="card"><div class="label">Secrets Present</div><p>' +
            Object.entries(data.secrets).map(([k, v]) => pill(k, v)).join('') +
          '</p></article>',
          renderRequestForms(artifacts),
          '<article class="card full"><div class="label">Action Requests</div>' + renderActions(actions.data || []) + '</article>',
          '<article class="card full"><div class="label">Latest Backups</div>' + renderBackupTable(artifacts) + '</article>',
          '<article class="card full"><div class="label">Deployment Plan</div><pre>' + esc(asJson(deploy.data)) + '</pre></article>',
          '<article class="card full"><div class="label">Backup Plan</div><pre>' + esc(asJson(backup.data)) + '</pre></article>',
          '<article class="card full"><div class="label">Restore Drill Plan</div><pre>' + esc(asJson(restore.data)) + '</pre></article>',
        ].join('');
        wireForms();
      } catch (error) {
        const message = String(error.message || error);
        if (message.includes('monitor credentials') || message.includes('IDENTITY_REQUIRED')) {
          sessionStorage.removeItem('orbi_monitor_key');
          monitorKey = '';
          renderUnlock(message);
          return;
        }
        root.innerHTML = '<article class="card full"><div class="label">Console Error</div><pre>' + esc(message) + '</pre></article>';
      }
    }
    function renderRequestForms(artifacts) {
      const backupOptions = artifacts.filter((item) => item.name.endsWith('.dump.enc')).map((item) => '<option value="' + esc(item.name) + '">' + esc(item.name) + '</option>').join('');
      return [
        '<article class="card half"><h2>One-Click Requests</h2><p>Each request needs two distinct approvers before the VM agent can queue it.</p>',
        '<label>Audit reason</label><textarea id="requestReason" placeholder="Why this action is needed"></textarea>',
        '<button id="backupNow">Request Backup</button></article>',
        '<article class="card half"><h2>Deploy Approved Commit</h2><label>Git ref or commit SHA</label><input id="releaseRef" placeholder="main or commit SHA" />',
        '<button id="deployRef">Request Deploy</button></article>',
        '<article class="card full"><h2>Restore Drill</h2><p>This is only allowed for staging/isolated drill targets, not production.</p>',
        '<label>Encrypted backup artifact</label><select id="backupArtifact">' + (backupOptions || '<option value="">No encrypted backups found</option>') + '</select>',
        '<label>Target</label><select id="restoreTarget"><option value="staging">staging</option><option value="isolated">isolated</option><option value="drill">drill</option></select>',
        '<label>Typed confirmation</label><input id="restoreConfirm" placeholder="RESTORE DRILL" />',
        '<button class="warn" id="restoreDrill">Request Restore Drill</button></article>',
      ].join('');
    }
    function renderActions(actions) {
      if (!actions.length) return '<p>No action requests yet.</p>';
      return '<table><thead><tr><th>Action</th><th>Status</th><th>Requester</th><th>Approvals</th><th>Controls</th></tr></thead><tbody>' +
        actions.map((item) => '<tr><td><strong>' + esc(item.actionType) + '</strong><br><span class="label">' + esc(item.id) + '</span><pre>' + esc(asJson(item.metadata)) + '</pre></td><td><span class="pill status">' + esc(item.status) + '</span></td><td>' + esc(item.requestedBy) + '<br>' + esc(item.requestedReason) + '</td><td>' + item.approvals.length + ' / ' + item.requiredApprovals + '</td><td>' + actionButtons(item) + '</td></tr>').join('') +
        '</tbody></table>';
    }
    function actionButtons(item) {
      const approve = '<button data-action="approve" data-id="' + esc(item.id) + '">Approve</button>';
      const cancel = '<button class="danger" data-action="cancel" data-id="' + esc(item.id) + '">Cancel</button>';
      const execute = '<button class="secondary" data-action="execute" data-id="' + esc(item.id) + '">Queue Agent</button>';
      if (item.status === 'READY') return approve + execute + cancel;
      if (item.status === 'PENDING_APPROVAL') return approve + cancel;
      return '<span class="label">No controls</span>';
    }
    function renderBackupTable(artifacts) {
      if (!artifacts.length) return '<p>No readable backup artifacts yet.</p>';
      return '<table><thead><tr><th>Name</th><th>Kind</th><th>Size</th><th>Modified</th></tr></thead><tbody>' +
        artifacts.map((item) => '<tr><td>' + esc(item.name) + '</td><td>' + esc(item.kind) + '</td><td>' + item.sizeBytes + '</td><td>' + esc(item.modifiedAt) + '</td></tr>').join('') +
        '</tbody></table>';
    }
    function wireForms() {
      const requestReason = () => document.getElementById('requestReason')?.value || '';
      document.getElementById('backupNow')?.addEventListener('click', async () => {
        await postJson('/api/admin/ops/actions', { actionType: 'RUN_MANUAL_BACKUP', reason: requestReason(), metadata: {} });
        await refresh();
      });
      document.getElementById('deployRef')?.addEventListener('click', async () => {
        await postJson('/api/admin/ops/actions', { actionType: 'DEPLOY_APPROVED_COMMIT', reason: requestReason(), metadata: { releaseRef: document.getElementById('releaseRef').value } });
        await refresh();
      });
      document.getElementById('restoreDrill')?.addEventListener('click', async () => {
        await postJson('/api/admin/ops/actions', {
          actionType: 'RESTORE_BACKUP_DRILL',
          reason: requestReason(),
          targetEnvironment: document.getElementById('restoreTarget').value,
          confirmText: document.getElementById('restoreConfirm').value,
          metadata: { backupArtifact: document.getElementById('backupArtifact').value },
        });
        await refresh();
      });
      document.querySelectorAll('button[data-action]').forEach((button) => {
        button.addEventListener('click', async () => {
          const id = button.getAttribute('data-id');
          const action = button.getAttribute('data-action');
          const reason = prompt('Audit reason') || '';
          await postJson('/api/admin/ops/actions/' + id + '/' + action, { reason });
          await refresh();
        });
      });
    }
    document.getElementById('refresh').addEventListener('click', refresh);
    refresh();
  </script>
</body>
</html>`;

const jsonOk = (res: Response, data: unknown) => res.json({ success: true, data });

const operatorIdFrom = (req: Request) => String(req.header('x-orbi-operator-id') || '').trim();

const statusForError = (message: string) => {
  if (message.includes('NOT_FOUND')) return 404;
  if (message.includes('DISABLED')) return 409;
  if (message.includes('NOT_READY') || message.includes('REQUIRED') || message.includes('CANNOT') || message.includes('UNSUPPORTED')) return 400;
  if (message.includes('ALREADY') || message.includes('APPROVABLE') || message.includes('CANCELLABLE')) return 409;
  return 500;
};

const handleOpsError = (res: Response, error: unknown) => {
  const message = error instanceof Error ? error.message : 'OPS_REQUEST_FAILED';
  return res.status(statusForError(message)).json({ success: false, error: message });
};

export const registerOpsConsoleRoutes = (app: Express, authenticateMonitorApiKey: any) => {
  app.get(['/ops', '/ops/'], (_req: Request, res: Response) => {
    res.setHeader(
      'Content-Security-Policy',
      "default-src 'self';base-uri 'self';font-src 'self' https: data:;form-action 'self';frame-ancestors 'self';img-src 'self' data:;object-src 'none';script-src 'self' 'unsafe-inline';script-src-attr 'none';style-src 'self' https: 'unsafe-inline';upgrade-insecure-requests",
    );
    res.type('html').send(html);
  });

  app.get('/api/admin/ops/overview', authenticateMonitorApiKey, async (_req, res) => {
    try {
      return jsonOk(res, await OpsConsoleService.overview());
    } catch (error) {
      return handleOpsError(res, error);
    }
  });

  app.get('/api/admin/ops/deployment-plan', authenticateMonitorApiKey, (_req, res) => {
    return jsonOk(res, OpsConsoleService.deploymentPlan());
  });

  app.get('/api/admin/ops/backup-plan', authenticateMonitorApiKey, (_req, res) => {
    return jsonOk(res, OpsConsoleService.backupPlan());
  });

  app.get('/api/admin/ops/restore-drill-plan', authenticateMonitorApiKey, (_req, res) => {
    return jsonOk(res, OpsConsoleService.restoreDrillPlan());
  });

  app.get('/api/admin/ops/actions', authenticateMonitorApiKey, async (req, res) => {
    try {
      const limit = Number(req.query.limit || 50);
      return jsonOk(res, await OpsActionService.list(limit));
    } catch (error) {
      return handleOpsError(res, error);
    }
  });

  app.post('/api/admin/ops/actions', authenticateMonitorApiKey, async (req, res) => {
    try {
      return jsonOk(res, await OpsActionService.request({
        actionType: req.body?.actionType,
        requestedBy: operatorIdFrom(req),
        reason: req.body?.reason,
        targetEnvironment: req.body?.targetEnvironment,
        metadata: req.body?.metadata,
        confirmText: req.body?.confirmText,
      }));
    } catch (error) {
      return handleOpsError(res, error);
    }
  });

  app.post('/api/admin/ops/actions/:id/approve', authenticateMonitorApiKey, async (req, res) => {
    try {
      return jsonOk(res, await OpsActionService.approve(req.params.id, {
        operatorId: operatorIdFrom(req),
        reason: req.body?.reason,
      }));
    } catch (error) {
      return handleOpsError(res, error);
    }
  });

  app.post('/api/admin/ops/actions/:id/cancel', authenticateMonitorApiKey, async (req, res) => {
    try {
      return jsonOk(res, await OpsActionService.cancel(req.params.id, {
        operatorId: operatorIdFrom(req),
        reason: req.body?.reason,
      }));
    } catch (error) {
      return handleOpsError(res, error);
    }
  });

  app.post('/api/admin/ops/actions/:id/execute', authenticateMonitorApiKey, async (req, res) => {
    try {
      return jsonOk(res, await OpsActionService.execute(req.params.id, {
        operatorId: operatorIdFrom(req),
        reason: req.body?.reason,
      }));
    } catch (error) {
      return handleOpsError(res, error);
    }
  });
};
