import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  addApproval,
  approvalCount,
  validateActionRequestInput,
} from '../backend/ops/OpsActionService.js';
import { OpsConsoleService } from '../backend/ops/OpsConsoleService.js';

test('ops console exposes read-only deployment and recovery plans', () => {
  const deployment = OpsConsoleService.deploymentPlan();
  const backup = OpsConsoleService.backupPlan();
  const restore = OpsConsoleService.restoreDrillPlan();

  assert.ok(deployment.commands.some((command) => command.includes('validate-deployment.sh')));
  assert.ok(backup.commands.some((command) => command.includes('backup-now.sh')));
  assert.equal(restore.isolatedHostRequired, true);
  assert.match(restore.warning, /Never restore directly over production/);
});

test('ops action requests require audited safe inputs', () => {
  const deploy = validateActionRequestInput({
    actionType: 'DEPLOY_APPROVED_COMMIT',
    requestedBy: 'Release.Manager',
    reason: 'approved release window',
    metadata: { releaseRef: 'main' },
  });

  assert.equal(deploy.requestedBy, 'release.manager');
  assert.equal(deploy.commandPlan.actionType, 'DEPLOY_APPROVED_COMMIT');

  assert.throws(() => validateActionRequestInput({
    actionType: 'RESTORE_BACKUP_DRILL',
    requestedBy: 'ops-a',
    reason: 'restore test',
    targetEnvironment: 'production',
    confirmText: 'RESTORE DRILL',
    metadata: { backupArtifact: 'orbi.dump.enc' },
  }), /RESTORE_DRILL_CANNOT_TARGET_PRODUCTION/);

  assert.throws(() => validateActionRequestInput({
    actionType: 'RESTORE_BACKUP_DRILL',
    requestedBy: 'ops-a',
    reason: 'restore test',
    targetEnvironment: 'isolated',
    confirmText: 'RESTORE',
    metadata: { backupArtifact: 'orbi.dump.enc' },
  }), /RESTORE_DRILL_CONFIRMATION_REQUIRED/);
});

test('ops approvals require two distinct operators', () => {
  const first = addApproval([], {
    operatorId: 'Ops-A',
    reason: 'reviewed release evidence',
    approvedAt: new Date().toISOString(),
  });
  const second = addApproval(first, {
    operatorId: 'Ops-B',
    reason: 'reviewed restore evidence',
    approvedAt: new Date().toISOString(),
  });

  assert.equal(approvalCount(first), 1);
  assert.equal(approvalCount(second), 2);
  assert.throws(() => addApproval(first, {
    operatorId: 'ops-a',
    reason: 'duplicate approval',
    approvedAt: new Date().toISOString(),
  }), /OPERATOR_ALREADY_APPROVED/);
});
