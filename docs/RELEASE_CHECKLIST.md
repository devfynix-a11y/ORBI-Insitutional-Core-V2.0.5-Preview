# ORBI Release Checklist

## Purpose

Use this checklist before every staging or production release of ORBI Institutional Core.

## Pre-Deploy

- [ ] `npm ci`
- [ ] `npm run lint`
- [ ] `npm test`
- [ ] `npm run build`
- [ ] review schema changes in `database/`
- [ ] confirm API and worker release compatibility
- [ ] confirm required environment variables exist in the target environment
- [ ] confirm provider registry changes are reviewed
- [ ] confirm rollback target is known

## Pre-Traffic Validation

- [ ] `GET /health` returns `ONLINE`
- [ ] `GET /ready` returns `READY`
- [ ] `GET /health/deep` is not `CRITICAL`
- [ ] `GET /api/admin/monitor/operational-health` returns non-critical status
- [ ] Prometheus scrape endpoint returns `orbi_operational_status`
- [ ] if workers are required, `GET /api/broker/health` is healthy

## Automated Smoke Test

Run:

```bash
ORBI_BASE_URL=https://your-target-host \
ORBI_MONITOR_API_KEY=replace_me \
node scripts/release-smoke.mjs
```

If broker heartbeat is required:

```bash
ORBI_BASE_URL=https://your-target-host \
ORBI_MONITOR_API_KEY=replace_me \
ORBI_EXPECT_BROKER_HEALTH=true \
node scripts/release-smoke.mjs
```

The same smoke test can be executed from GitHub Actions using the `Release Smoke` workflow.

`ORBI_MONITOR_API_KEY` should be a dedicated internal monitor token, not a tenant or frontend `x-api-key`.

## Post-Deploy Validation

- [ ] smoke test passed
- [ ] settlement backlog is within normal range
- [ ] failed webhook count is not rising unexpectedly
- [ ] reconciliation mismatch count remains zero
- [ ] wallet drift count remains zero
- [ ] logs show normal startup and no fatal dependency warnings

## Rollback Trigger Conditions

Rollback immediately if any of the following are true:

- [ ] `/ready` remains non-ready after recovery window
- [ ] operational health is `CRITICAL`
- [ ] DB or Redis connectivity is unavailable
- [ ] reconciliation mismatch count is non-zero after deploy
- [ ] wallet drift appears unexpectedly
- [ ] settlement backlog grows abnormally due to the release

## Evidence To Record

- [ ] release version or commit SHA
- [ ] deploy start and completion time
- [ ] smoke test result
- [ ] operator name
- [ ] rollback decision if applicable
