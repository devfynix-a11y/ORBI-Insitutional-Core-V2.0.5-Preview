# ORBI Disaster Recovery Runbook

## Purpose

This runbook defines the first-response and recovery path for the ORBI Institutional Core platform during severe operational incidents.

Use this runbook for:

- database outage
- Redis outage
- KMS or master-key recovery events
- settlement stalls
- webhook processing failures
- ledger drift investigation

## Recovery Objectives

Target objectives should be finalized with operations leadership, but the working defaults are:

- RTO target: 4 hours
- RPO target: 15 minutes

These are planning targets until validated by restore drills.

## Incident Severity

- `SEV1`
  - active customer impact on money movement
  - settlement flow halted
  - inability to validate ledger integrity
  - loss of production database connectivity
- `SEV2`
  - degraded provider routing
  - growing backlog with partial service continuity
  - Redis degradation with safe fallback still active
- `SEV3`
  - observability impairment
  - non-critical tooling or reporting degradation

## Core Principles

1. Preserve financial correctness before restoring throughput.
2. Do not run emergency repair commands without audit capture.
3. API and worker rollback must be treated as one coordinated decision.
4. KMS custody assumptions must be checked before any restore involving encrypted data.

## Minimum Incident Checklist

- declare severity and incident owner
- freeze non-essential deployments
- capture current timestamps and impacted services
- preserve logs, traces, and audit evidence
- verify whether the ledger path is still trustworthy
- communicate customer impact and containment status

## Scenario: Production Database Failure

### Detection

- `/ready` returns `NOT_READY`
- `/health/deep` reports database connectivity failure
- operational alerts report database unavailable

### Immediate Actions

1. pause new deployments
2. confirm provider callbacks are either queued or safely rejected
3. verify whether worker processes are still attempting writes
4. place platform into controlled degraded mode if needed

### Recovery Steps

1. verify the primary database outage scope
2. confirm latest backup and WAL availability
3. restore into validated recovery environment first when time permits
4. verify critical RPCs:
   - `post_transaction_v2`
   - `append_ledger_entries_v1`
   - `claim_internal_transfer_settlement`
   - `complete_internal_transfer_settlement`
   - `repair_wallet_balance_emergency`
5. run `/health`, `/ready`, and `/health/deep`
6. validate sample ledger and settlement reads
7. reopen traffic in stages

### Evidence To Capture

- outage start and end time
- backup timestamp used
- restore completion timestamp
- validation results

## Scenario: Redis Failure

### Detection

- operational health shows Redis unavailable
- throttling or replay protection alerts fire
- queue backlog begins growing

### Immediate Actions

1. determine whether the platform is configured for safe degraded mode
2. confirm idempotency and replay protections are not silently falling back in unsafe ways
3. reduce non-critical traffic if webhook or provider replay risk rises

### Recovery Steps

1. restore Redis service connectivity
2. verify `PING` success and TLS configuration
3. inspect queue depth and stuck jobs
4. inspect webhook replay window behavior
5. confirm readiness recovers

## Scenario: KMS Or Master-Key Recovery Event

### Detection

- decrypt failures increase
- key unwrap failures in logs
- audit or provider secret operations fail unexpectedly

### Immediate Actions

1. halt manual secret rotation activity
2. confirm current master-secret custody
3. prevent destructive key changes until custody is verified

### Recovery Steps

1. verify `KMS_MASTER_KEY` provenance
2. verify `kms_keys` table availability and integrity
3. confirm the active key can unwrap sample encrypted records
4. use re-wrap procedures only through controlled change management
5. validate audit signing, auth token signing, and provider secret access boundaries after recovery

## Scenario: Settlement Stall

### Detection

- settlement backlog alert fires
- scheduler reports running but backlog keeps growing
- provider callbacks arrive but movements are not progressing

### Immediate Actions

1. identify whether the block is provider-side, worker-side, DB-side, or queue-side
2. stop any duplicate manual replay attempts until idempotency state is understood
3. preserve affected transaction IDs and settlement lifecycle records

### Recovery Steps

1. inspect settlement scheduler health
2. inspect queue status
3. inspect `settlement_lifecycle`
4. inspect related `provider_webhook_events`
5. re-queue only through approved worker paths
6. verify backlog trend returns downward before closing incident

## Scenario: Ledger Drift

### Detection

- reconciliation mismatch alerts fire
- wallet drift count increases
- system reconciliation reports imbalance

### Immediate Actions

1. freeze any non-essential balance repair activity
2. collect affected wallet IDs and transaction IDs
3. run read-only reconciliation first

### Recovery Steps

1. confirm whether drift is isolated or systemic
2. compare transactions to ledger legs
3. verify append-marker and settlement states
4. use emergency repair only with explicit incident approval and audit evidence
5. rerun reconciliation after repair

## Restore Validation Checklist

- `/health` returns online
- `/ready` returns ready
- `/health/deep` shows non-critical platform state
- broker heartbeat recovers
- operational metrics endpoint responds
- sample authenticated request succeeds
- sample settlement read succeeds
- reconciliation checks show no unreviewed critical mismatch increase

## Required Evidence After Every Drill Or Real Incident

- incident summary
- root cause
- systems impacted
- customer impact
- timeline
- commands and recovery actions used
- validation results
- follow-up actions

## Drill Cadence

- backup restore drill: quarterly
- KMS recovery validation: quarterly
- settlement stall tabletop: monthly
- ledger drift tabletop: monthly

## Drill Execution References

- backup restore drill procedure: `docs/BACKUP_RESTORE_DRILL_PROCEDURE.md`
- restore drill procedure: `docs/BACKUP_RESTORE_DRILL_PROCEDURE.md`
- drill evidence generator: `node scripts/drill-report.mjs`

## Ownership

- incident commander: platform lead
- ledger authority reviewer: financial core lead
- secret custody reviewer: security lead
- release freeze approver: engineering lead
