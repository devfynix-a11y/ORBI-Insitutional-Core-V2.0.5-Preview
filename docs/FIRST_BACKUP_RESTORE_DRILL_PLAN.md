# ORBI First Backup Restore Drill Plan

## Objective

Execute the first formal ORBI backup restore drill in a staging or isolated recovery environment and produce auditable evidence that:

- the database can be restored
- KMS-dependent encrypted data remains usable
- health and operational monitoring recover correctly
- core financial read paths remain intact after restore

## Scope

In scope:

- database restore
- KMS dependency validation
- health and readiness verification
- operational metrics verification
- financial read-path verification
- evidence report generation

Out of scope for the first drill:

- production traffic cutover
- live write validation against restored financial data
- rollback of a real production incident

## Target Environment

Recommended target:

- `staging-recovery`

Requirements:

- isolated from production traffic
- access to a recent production-like backup
- access to required KMS and configuration material
- monitor API key available for smoke validation

## Required Inputs

Before the drill begins, fill in the following:

- target environment name
- backup identifier
- backup timestamp
- restore target timestamp if PITR is included
- app commit SHA or release version
- drill owner
- drill reviewer
- start time
- expected finish time

## Roles

- Drill owner:
  - coordinates the drill
  - records start and finish times
  - ensures evidence is captured
- Platform operator:
  - performs restore actions
  - validates runtime and dependencies
- Security reviewer:
  - confirms KMS custody and encrypted-data assumptions
- Financial core reviewer:
  - confirms reconciliation and financial read-path checks

## Planned Timeline

### 1. Preparation

Duration:

- 15 to 30 minutes

Checklist:

- verify backup availability
- verify recovery environment is isolated
- verify `KMS_MASTER_KEY` custody path
- verify `kms_keys` availability
- verify monitor API key for smoke validation

### 2. Restore Execution

Duration:

- 30 to 60 minutes

Checklist:

- start restore
- record restore start time
- restore backup
- apply WAL or PITR if included
- record restore completion time

### 3. Runtime Validation

Duration:

- 15 to 30 minutes

Run:

```bash
ORBI_BASE_URL=https://recovery-host \
ORBI_MONITOR_API_KEY=replace_me \
node scripts/release-smoke.mjs
```

Confirm:

- `/health` is online
- `/ready` is ready
- `/health/deep` is not critical
- operational monitor endpoint is healthy
- Prometheus endpoint exposes `orbi_operational_status`

### 4. Financial Validation

Duration:

- 15 to 30 minutes

Checklist:

- validate sample wallet or vault reads
- validate sample transaction history reads
- validate settlement backlog visibility
- validate reconciliation report reads
- validate provider webhook event history reads
- confirm critical RPCs are present
- confirm no unexplained reconciliation mismatch increase

### 5. Evidence Capture

Duration:

- 10 to 15 minutes

Generate the report:

```bash
ORBI_DRILL_TYPE=backup_restore \
ORBI_DRILL_ENV=staging-recovery \
ORBI_DRILL_OWNER="Platform Lead" \
ORBI_DRILL_REVIEWER="Security Lead" \
ORBI_DRILL_BACKUP_ID="fill-me" \
ORBI_DRILL_BACKUP_TIMESTAMP="fill-me" \
ORBI_DRILL_RESTORE_STARTED_AT="fill-me" \
ORBI_DRILL_RESTORE_COMPLETED_AT="fill-me" \
ORBI_DRILL_STATUS=passed \
ORBI_DRILL_SUMMARY="fill-me" \
ORBI_DRILL_NOTES="fill-me||fill-me" \
ORBI_DRILL_ACTION_ITEMS="fill-me||fill-me" \
node scripts/drill-report.mjs
```

## Exit Criteria

The first drill is successful only if all of the following are true:

- restore completed successfully
- encrypted data remained accessible
- health and readiness passed
- operational metrics endpoint passed
- critical RPC presence was verified
- financial read paths were validated
- drill report was generated and saved

## Common Failure Reasons To Watch

- backup available but key custody missing
- restored database present but RPC compatibility broken
- health endpoint passes while readiness remains degraded
- operational metrics unavailable because monitor auth or routing is incomplete
- recovered data accessible but reconciliation signals show drift

## Follow-Up Deliverables After The First Drill

- attach the generated drill report to the weekly production-readiness review
- record actual restore duration against RTO target
- record backup age against RPO target
- create tickets for every action item found during the drill
- decide whether the next drill should include PITR or broker-heartbeat validation
