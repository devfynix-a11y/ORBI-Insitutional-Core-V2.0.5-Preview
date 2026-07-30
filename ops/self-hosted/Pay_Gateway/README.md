# ORBI Pay Gateway Self-Hosted Runtime

This compose module runs the live and sandbox ORBI Pay Gateway containers.

## Services

```text
pay-gateway         -> https://pay.orbifinancial.com       -> container port 3100
pay-gateway-sandbox -> https://sandbox-pay.orbifinancial.com -> container port 3101
```

Live and sandbox must use separate env files, separate database URLs, separate
worker signing secrets, separate developer API keys, and separate webhook
secrets.

## mTLS Certificate Mounts

The compose file mounts read-only certificate directories into:

```text
/opt/orbi/mtls
```

Host defaults:

```text
D:/FYNIX/ORBI/SECREATES/ORBI_MTLS
D:/FYNIX/ORBI/SECREATES/ORBI_MTLS_SANDBOX
```

Override them with:

```env
ORBI_PAY_GATEWAY_MTLS_CERT_DIRECTORY=/srv/orbi/secrets/mtls/pay-gateway
ORBI_PAY_GATEWAY_SANDBOX_MTLS_CERT_DIRECTORY=/srv/orbi/secrets/mtls/pay-gateway-sandbox
```

Do not commit certificates or private keys. Keep private keys root-owned or
server-admin-owned and mount the directory read-only.

## Portable Gateway Paths

The compose file uses relative defaults so the whole `Orbi Infrastructures`
folder can move together without editing the compose file.

```env
ORBI_PAY_GATEWAY_BACKEND_ROOT=../../../../../../ORBI GATEWAY/Pay Gateway Backend
ORBI_PAY_GATEWAY_RECONCILIATION_REPORTS_ROOT=../../../../../../ORBI GATEWAY/Reconciliation Reports/live
ORBI_PAY_GATEWAY_RECONCILIATION_SANDBOX_REPORTS_ROOT=../../../../../../ORBI GATEWAY/Reconciliation Reports/sandbox
```

Override these only when the Pay Gateway backend or report directories live
outside the infrastructure folder.

## Reconciliation Evidence

Both live and sandbox containers write signed reconciliation evidence reports to:

```text
/app/reconciliation
```

This is mounted to host report folders:

```text
ORBI GATEWAY/Reconciliation Reports/live
ORBI GATEWAY/Reconciliation Reports/sandbox
```

The internal export endpoint is:

```text
GET/POST /v1/internal/reconciliation/evidence/export
```

It produces report hashes, signatures, payment/webhook summaries, and exception
queues for operator review.

The self-hosted runtime enables scheduled reconciliation every 24 hours:

```env
PAYMENT_GATEWAY_RECONCILIATION_SCHEDULE_ENABLED=true
PAYMENT_GATEWAY_RECONCILIATION_SCHEDULE_INTERVAL_MINUTES=1440
PAYMENT_GATEWAY_RECONCILIATION_SCHEDULE_WINDOW_HOURS=24
PAYMENT_GATEWAY_RECONCILIATION_SCHEDULE_RUN_ON_START=false
```

Keep `RUN_ON_START=false` in production unless you intentionally want a report
created after every container restart.

Before enabling `PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED=true`, run the gateway
readiness check from the Pay Gateway Backend repository:

```bash
npm run mtls:readiness -- /path/to/pay-gateway.env
```

## Direct mTLS Operating Modes

### Sandbox

Sandbox may be run with direct mTLS while live remains on the current production
transport. This is the preferred test path before live cutover.

```powershell
powershell -ExecutionPolicy Bypass -File ..\scripts\start-core-sandbox.ps1 -EnableDirectMtls
powershell -ExecutionPolicy Bypass -File ..\scripts\start-pay-gateway-sandbox.ps1 -GatewayImage orbi-pay-gateway:local -EnableDirectMtls
```

Expected sandbox gateway log:

```json
{"coreTarget":"https://core-sandbox:3000","mtlsEnabled":true}
```

Run sandbox smoke after startup:

```powershell
$env:PAYMENT_GATEWAY_SMOKE_BASE_URL='https://sandbox-pay.orbifinancial.com'
$env:PAYMENT_GATEWAY_SMOKE_ALLOWED_ORIGIN='https://shop.orbifinancial.com'
npm run smoke:runtime-controls
```

### Live

Live mTLS must be enabled only during an approved maintenance window.

1. Generate or rotate live certificates outside Git.
2. Run `test-live-mtls-readiness.ps1`.
3. Dry-run `set-live-mtls-mode.ps1 -Mode enable`.
4. Apply the env patch with `-Apply`.
5. Restart Core first and verify Core HTTPS health inside the Docker network.
6. Restart Pay Gateway and run live smoke.

```powershell
powershell -ExecutionPolicy Bypass -File ..\scripts\test-live-mtls-readiness.ps1
powershell -ExecutionPolicy Bypass -File ..\scripts\set-live-mtls-mode.ps1 -Mode enable
powershell -ExecutionPolicy Bypass -File ..\scripts\set-live-mtls-mode.ps1 -Mode enable -Apply
```

Rollback:

```powershell
powershell -ExecutionPolicy Bypass -File ..\scripts\set-live-mtls-mode.ps1 -Mode rollback -Apply
```

The live cutover script writes timestamped env backups and never restarts
containers automatically. Restart must be handled by the approved deployment
command so Core and Gateway can be verified one step at a time.
