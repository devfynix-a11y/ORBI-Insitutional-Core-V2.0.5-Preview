# ORBI Production Deployment Guide

## Required Services
- Primary database: Supabase Postgres (service role access required for server-side operations)
- Auth: Supabase Auth (server-side admin access)
- Cache/queues: Redis (cluster or single-node)
- Object storage: Supabase Storage or equivalent S3-compatible backend (for receipts, artifacts)
- Background jobs: Node worker runtime (same build as API)
- Observability: centralized log ingestion (JSON structured logs)

## Secrets
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY`
- `JWT_SECRET`
- `KMS_MASTER_KEY`
- `WORKER_SECRET`
- `WORKER_SIGNING_SECRET`
- Provider secrets (stored in `financial_partners.provider_metadata.secrets` or encrypted vault fields)

## Environment Variables
### Required (Production)
- `NODE_ENV=production`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY`
- `JWT_SECRET`
- `KMS_MASTER_KEY`
- `WORKER_SECRET`
- `WORKER_SIGNING_SECRET`
- `ORBI_INTERNAL_MTLS_MODE=required`
- `ORBI_INTERNAL_MTLS_SOURCE`
- `ORBI_ENFORCE_HTTPS=true`
- `RP_ID`
- `ORBI_WEB_ORIGIN`
- `ORBI_MOBILE_ORIGIN`
- `ORBI_CORE_PORTAL_APP_ORIGIN`
- `ORBI_ANDROID_APP_HASH`

### Strongly Recommended
- `ORBI_MONITOR_API_KEY`
- `REDIS_URL` or `REDIS_CLUSTER_NODES`
- `REDIS_TLS_ENABLED=true`
- `REDIS_ALLOW_INSECURE_TLS=false`
- `ORBI_TLS_ENABLED=true` with valid `ORBI_TLS_CERT_PATH` and `ORBI_TLS_KEY_PATH` when terminating TLS directly on the Node server
- `ORBI_TALK_GATEWAY_API_KEY` and `ORBI_TALK_GATEWAY_URL` for SMS/email/push/template delivery
- `ORBI_GATEWAY_BASE_URL` only for the payment gateway/payment bridge, if enabled
- `ORBI_WEBHOOK_MAX_AGE_SECONDS`
- `ORBI_WEBHOOK_REPLAY_WINDOW_SECONDS`
- `ORBI_PROVIDER_TIMEOUT_MS`
- `ORBI_PROVIDER_MAX_ATTEMPTS`
- `ORBI_PROVIDER_RETRY_DELAY_MS`
- `ORBI_API_GATEWAY_ENABLED=true`
- `ORBI_API_GATEWAY_FAIL_CLOSED=true`
- `ORBI_API_GATEWAY_REDIS_REQUIRED=true`
- `ORBI_API_GATEWAY_AI_MODE=adapter`

### Optional / Feature Flags
- `ORBI_ENABLE_GATEWAY_BACKGROUND_JOBS`
- `ORBI_ENABLE_INTERNAL_BACKGROUND_JOBS`
- `ORBI_ENABLE_LEGACY_API_GATEWAY`
- `ORBI_ENABLE_SANDBOX_ROUTES`
- `ORBI_ENABLE_MESSAGING_TEST_ROUTES`
- `ORBI_AI_SECURITY_SCORER_URL` for the future Python/FastAPI security scorer
- `ORBI_AI_SECURITY_SCORER_TIMEOUT_MS=750`

## Pre-Flight Checklist
1. Confirm required production env vars are present (see above).
2. Confirm `ORBI_INTERNAL_MTLS_MODE=required` and worker signing secrets are set.
3. Confirm internal mTLS source is explicitly configured:
   - proxy mode: `ORBI_INTERNAL_MTLS_SOURCE=proxy` and `ORBI_INTERNAL_MTLS_PROXY_SHARED_SECRET`
   - direct mode: `ORBI_INTERNAL_MTLS_SOURCE=direct` and `ORBI_INTERNAL_MTLS_CA_PATH`
4. Confirm desktop portal identity is configured if desktop clients are enabled:
   - `ORBI_CORE_PORTAL_APP_ID`
   - `ORBI_CORE_PORTAL_APP_ORIGIN`
5. Ensure Supabase connectivity using service-role credentials.
6. Verify critical RPCs exist:
   - `post_transaction_v2`
   - `append_ledger_entries_v1`
   - `claim_internal_transfer_settlement`
   - `complete_internal_transfer_settlement`
   - `repair_wallet_balance_emergency`
7. Validate Redis connectivity (or accept degraded mode if intentionally disabled).
8. Verify provider registry readiness for active partners (mapping config, webhook callback config).
9. Confirm the ORBI API Gateway security layer is enabled and Redis-backed in production.
10. Run `/health` and `/api/admin/monitor/operational-health` before opening traffic.
11. Run the automated smoke test:
   - `ORBI_BASE_URL=https://target-host ORBI_MONITOR_API_KEY=... node scripts/release-smoke.mjs`

## ORBI API Gateway Security Layer
- The in-process API Gateway runs before business routes and centralizes route policy, velocity limits, progressive attempt-locking, quarantine, audit events, and operator alerts.
- Production should keep `ORBI_API_GATEWAY_REDIS_REQUIRED=true`; process-local fallback is only appropriate for local development.
- Current AI mode should remain `ORBI_API_GATEWAY_AI_MODE=adapter`. When the Python Sentinel model is deployed, set `ORBI_API_GATEWAY_AI_MODE=python` and `ORBI_AI_SECURITY_SCORER_URL=https://...`.
- Gateway scoring must only receive redacted request features. Never forward passwords, OTPs, tokens, card PAN/CVV, KYC files, or provider secrets to an AI service.
- Gateway blocks are visible through `audit_trail`, `operator_alerts`, `api_gateway_security_events`, and `api_gateway_quarantines`.

## TLS / SSL
- If you are behind a managed edge such as Nginx, Apache, or OCI Load Balancer, keep:
  - `ORBI_ENFORCE_HTTPS=true`
  - `ORBI_TLS_ENABLED=false`
  This relies on the platform TLS terminator plus strict HTTPS enforcement and HSTS inside the app.
- If you terminate TLS directly in Node, set:
  - `ORBI_TLS_ENABLED=true`
  - `ORBI_TLS_CERT_PATH=/path/to/fullchain.pem`
  - `ORBI_TLS_KEY_PATH=/path/to/privkey.pem`
  - optional `ORBI_TLS_CA_PATH=/path/to/ca.pem`
- In production, startup now fails if HTTPS enforcement is disabled or TLS file paths are missing while `ORBI_TLS_ENABLED=true`.
- Database/API transport is also locked down:
  - `SUPABASE_URL` must use `https://` in production
  - Redis should use your provider's TLS-compatible connection settings with `REDIS_TLS_ENABLED=true`
  - direct insecure database transport is not allowed by startup validation

## Internal mTLS
- Preferred behind a managed reverse proxy:
  - `ORBI_INTERNAL_MTLS_SOURCE=proxy`
  - trusted proxy/service mesh verifies client certs
  - proxy injects `ORBI_INTERNAL_MTLS_PROXY_HEADER` with secret `ORBI_INTERNAL_MTLS_PROXY_SHARED_SECRET`
  - backend rejects spoofed mTLS headers without that attestation
- Direct end-to-end Node termination:
  - `ORBI_INTERNAL_MTLS_SOURCE=direct`
  - `ORBI_TLS_ENABLED=true`
  - `ORBI_INTERNAL_MTLS_CA_PATH=/path/to/internal-ca.pem`
  - workers must connect directly to Node and present valid client certs
  - use this only where infrastructure allows direct TLS connectivity to the service
- Next payment gateway hardening milestone:
  - start with signed HMAC callbacks while `ORBI_INTERNAL_MTLS_MODE=optional`
  - deploy internal CA and gateway/Core service certificates outside Git
  - verify gateway callbacks with both mTLS evidence and HMAC signatures in staging
  - switch production to `ORBI_INTERNAL_MTLS_MODE=required` only after callback smoke tests pass
  - keep HMAC signatures enabled permanently because mTLS proves service identity while HMAC proves request integrity

## Payment Gateway Production Safety Rule
When the standalone ORBI Payment Gateway is used for external provider collections, payouts, refunds, and webhooks, Core must not run legacy provider-gateway execution routes.

Gateway source and deployment docs live outside this Core repository:

```txt
D:\FYNIX\ORBI\ORBI CORE\ORBI PAY GATEWAY
```

Keep these unset or explicitly false in production:

```env
ORBI_ENABLE_CORE_PROVIDER_GATEWAY_ROUTES=false
ORBI_ALLOW_STUB_PROVIDER_RECONCILIATION=false
```

- `ORBI_ENABLE_CORE_PROVIDER_GATEWAY_ROUTES` is only a temporary migration switch for old Core `/v1/gateway/*` provider-execution routes.
- `ORBI_ALLOW_STUB_PROVIDER_RECONCILIATION` is only for non-production settlement lab tests.
- Live settlement must require trusted provider proof from ORBI Payment Gateway, a verified provider webhook, provider API reconciliation, or admin dual-control evidence before Core posts ledger entries.

## Database Migration Order
1. Apply core schema: `database/reset_schema.sql`
2. Apply main schema updates: `database/main.sql`
3. Validate critical RPCs exist:
   - `post_transaction_v2`
   - `append_ledger_entries_v1`
   - `claim_internal_transfer_settlement`
   - `complete_internal_transfer_settlement`
   - `repair_wallet_balance_emergency`
4. Run post-migration health checks (see below).

## Background Worker Requirements
- At least one worker process for internal settlement flows and ledger reapers.
- Worker must present:
  - `x-worker-id`
  - signed request headers
  - mTLS client cert (production)
- Worker auth is required; legacy worker auth is blocked in prod.

## Webhook Endpoints
- Provider callbacks route through:
  - `POST /api/v1/webhooks/:providerId`
- Required provider callback configuration in `financial_partners.mapping_config.callback`:
  - `reference_field`
  - `status_field`
  - `event_id_field`
  - `timestamp_header` (if freshness validation enforced)

## Rollback Guidance
- Always rollback API and worker together (they share schema assumptions).
- If rolling back schema:
  - Restore prior `main.sql` and `reset_schema.sql` snapshot
  - Verify RPC compatibility before re-enabling traffic
- For emergency rollback of a release:
  1. Disable traffic to new pods
  2. Roll back deployment image
  3. Run `/health` and `/api/admin/monitor/operational-health`
  4. Resume traffic only after DB/RPC checks pass

## Release Automation

- CI validation is defined in `.github/workflows/backend-ci.yml`
- manual release smoke validation is defined in `.github/workflows/release-smoke.yml`
- operator checklist is defined in `docs/RELEASE_CHECKLIST.md`
- protected monitor endpoints now use a dedicated internal monitor token, separate from tenant `x-api-key` flows

## Incident Recovery Basics
- Use `audit_trail` and `provider_webhook_events` for forensic reconstruction.
- For ledger drift:
  - Run reconciliation read-only checks
  - Use `repair_wallet_balance_emergency` only with incident approval
- For settlement stalls:
  - Inspect `settlement_lifecycle` stage/status
  - Re-queue via worker with proper claim and idempotency keys
- For provider webhook failures:
  - Check `provider_webhook_events` for `failed` status
  - Use replay and re-claim only via controlled worker paths
- For backup restore drills and evidence capture:
  - follow `docs/BACKUP_RESTORE_DRILL_PROCEDURE.md`
  - generate drill evidence with `node scripts/drill-report.mjs`

## Reconciliation Operations
- Read-only checks:
  - `reconciliation_reports` for `WALLET_DRIFT` and other mismatches
- Automated reconciliation:
  - `TransactionService.verifyWalletBalance(walletId)` for drift detection
- Privileged repair:
  - `repair_wallet_balance_emergency` only during incident windows
  - Ensure audit entry exists for every repair

## Production Readiness Checks
On startup, the app now validates:
- Required env vars for production
- Provider secret dependency consistency
- Supabase connectivity
- Critical RPC availability

If any check fails, startup exits with a fatal log.

