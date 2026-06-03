# ORBI Backup Restore Drill Procedure

## Purpose

This procedure defines how to run and document a backup restore drill for ORBI Institutional Core.

This procedure is the canonical restore-drill document for both first-time drills and recurring drills.

Use this procedure in:

- staging with production-like data
- isolated recovery environments
- controlled disaster recovery rehearsals

Do not run this directly against live production traffic.

## Preconditions

- a recent backup snapshot is available
- WAL or equivalent point-in-time recovery data is available if applicable
- KMS master-secret custody has been confirmed
- `kms_keys` backup availability is confirmed
- a recovery environment is provisioned
- a drill owner and reviewer are assigned

## Required Inputs

- environment under test
- backup identifier or timestamp
- restore start target time
- recovery target timestamp if PITR is being tested
- application build or commit SHA expected after restore
- operator name
- reviewer name

## High-Level Flow

1. prepare the recovery environment
2. restore the database backup
3. verify encrypted-data dependencies
4. verify critical RPCs and health endpoints
5. validate ledger and settlement read paths
6. capture evidence and lessons learned

## Step 1: Prepare Recovery Environment

- isolate the environment from production traffic
- load required secrets without reusing production write endpoints
- confirm the target ORBI app version or commit SHA
- ensure Redis configuration is either available or explicitly documented as absent for the drill

## Step 2: Restore Database

- restore the selected backup into the recovery environment
- apply WAL or point-in-time replay if the drill includes PITR
- record:
  - backup identifier
  - backup timestamp
  - restore start timestamp
  - restore completion timestamp

## Step 3: Validate KMS And Encrypted Data Dependencies

- confirm `KMS_MASTER_KEY` source and custody
- verify `kms_keys` records are present
- confirm the active key can unwrap sample encrypted values
- confirm provider secret access still works in a read-safe manner

If this step fails, stop and record the drill as unsuccessful. Database recovery without key recovery is not a valid restore result.

## Step 4: Validate Application Startup

Run and record the results of:

- `GET /health`
- `GET /ready`
- `GET /health/deep`
- `GET /api/admin/monitor/operational-health`
- `GET /api/admin/monitor/operational-metrics/prometheus`

If using the smoke script:

```bash
ORBI_BASE_URL=https://recovery-host \
ORBI_MONITOR_API_KEY=replace_me \
node scripts/release-smoke.mjs
```

## Step 5: Validate Financial Read Paths

Confirm the following against recovered data:

- sample transaction history reads succeed
- sample wallet or vault reads succeed
- settlement backlog visibility works
- reconciliation report reads succeed
- provider webhook event history reads succeed

## Step 6: Validate Financial Integrity Controls

- confirm critical RPCs exist:
  - `post_transaction_v2`
  - `append_ledger_entries_v1`
  - `claim_internal_transfer_settlement`
  - `complete_internal_transfer_settlement`
  - `repair_wallet_balance_emergency`
- confirm no unexpected critical reconciliation mismatch increase
- confirm wallet drift count is zero or understood

## Step 7: Capture Evidence

Use the drill evidence generator:

```bash
node scripts/drill-report.mjs --help
```

Example:

```bash
ORBI_DRILL_TYPE=backup_restore \
ORBI_DRILL_ENV=staging-recovery \
ORBI_DRILL_OWNER="Platform Lead" \
ORBI_DRILL_REVIEWER="Security Lead" \
ORBI_DRILL_BACKUP_ID="backup-2026-05-01-0200" \
ORBI_DRILL_BACKUP_TIMESTAMP="2026-05-01T02:00:00Z" \
ORBI_DRILL_RESTORE_STARTED_AT="2026-05-06T08:00:00Z" \
ORBI_DRILL_RESTORE_COMPLETED_AT="2026-05-06T08:47:00Z" \
ORBI_DRILL_STATUS=passed \
ORBI_DRILL_SUMMARY="Backup restore validation passed with healthy readiness and valid KMS recovery." \
node scripts/drill-report.mjs
```

## Pass Criteria

- restore completed successfully
- encrypted data remained accessible through valid key custody
- health and readiness checks passed
- operational monitor endpoints passed
- critical RPCs are present
- financial read paths are usable
- drill evidence report is captured

## Fail Criteria

- backup cannot be restored
- `kms_keys` or master-secret custody is missing or invalid
- health or readiness remains degraded without explained exception
- critical RPCs are missing
- reconciliation signals show unexplained critical drift
- no evidence report is captured

## Required Outputs

- restore drill report
- timeline of restore events
- validation results
- issues found
- follow-up actions with owners
