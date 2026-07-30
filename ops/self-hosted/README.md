# Self-Hosted Container Layout

The stack is split by responsibility:

```txt
ops/self-hosted/
  Auth_Security/     PostgreSQL and Valkey
  Storage/           S3-compatible object storage and bucket initialization
  Gateway/           Public TLS reverse proxy
  Observability/     Private Prometheus and Grafana control plane
  Backup_Recovery/   Backup foundation and recovery guidance
  docker-compose.dev.yml   ORBI Core API
  docker-compose.prod.yml  Hardened Ubuntu deployment topology
```

For a dedicated Ubuntu server, start with
`docs/UBUNTU_SERVER_LAUNCH_RUNBOOK.md`. The production stack uses named Docker
volumes for service data and stores logical database backups under
`/srv/orbi/backups/database`.

Production commands:

```bash
sudo bash ops/self-hosted/scripts/provision-ubuntu.sh
sudo bash ops/self-hosted/scripts/generate-secrets.sh
bash ops/self-hosted/scripts/validate-deployment.sh
bash ops/self-hosted/scripts/deploy.sh
```

Use `ops/self-hosted/COOLIFY_DEPLOYMENT.md` when Coolify owns the HTTPS edge.
Do not run the `direct-edge` profile at the same time as Coolify.

On Windows with Docker Desktop:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/start-windows.ps1
```

This starts Core, PostgreSQL, Keycloak, Valkey, and storage using the same
container modules that move to Ubuntu later.

Start the complete development stack from the repository root:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  up --build -d
```

Start only Auth and Security dependencies:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  up -d postgres valkey
```

Start only Storage:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  up -d storage storage-init
```

The root compose file is intentionally listed first so all relative paths use
`ops/self-hosted` as the Compose project directory.

Start the complete platform:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  -f ops/self-hosted/Gateway/docker-compose.yml \
  -f ops/self-hosted/Observability/docker-compose.yml \
  -f ops/self-hosted/Backup_Recovery/docker-compose.yml \
  up --build -d
```

Before using the complete command, install TLS files, create the Prometheus
monitor-key secret, set strong service passwords, and confirm that ports 80 and
443 are intended to be public.

## Internal mTLS Certificates

Direct Core-to-Gateway mTLS uses a private ORBI internal CA, a Core server
certificate, and a Pay Gateway client certificate. Generate a sandbox bundle
first:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/generate-mtls-certificates.ps1 -Environment sandbox
```

Generate a live bundle only when ready to deploy both Core and Gateway together:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/generate-mtls-certificates.ps1 -Environment live
```

Live dry-run readiness:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/test-live-mtls-readiness.ps1
```

Default Windows output paths:

```text
D:\FYNIX\ORBI\SECREATES\ORBI_CORE_TLS
D:\FYNIX\ORBI\SECREATES\ORBI_MTLS
D:\FYNIX\ORBI\SECREATES\ORBI_CORE_TLS_SANDBOX
D:\FYNIX\ORBI\SECREATES\ORBI_MTLS_SANDBOX
```

The Core production compose mounts `ORBI_CORE_TLS_CERT_DIRECTORY` into
`/etc/orbi/tls`. The Pay Gateway compose mounts
`ORBI_PAY_GATEWAY_MTLS_CERT_DIRECTORY` into `/opt/orbi/mtls`.

Do not enable direct mTLS until Gateway readiness passes:

```bash
npm run mtls:readiness -- /path/to/pay-gateway.env
```

Live cutover order:

```text
1. Generate or rotate live cert bundle.
2. Apply Core mTLS env patch and ensure Core TLS volume is mounted.
3. Restart Core only.
4. Verify https://core:3000/health from inside the Docker private network.
5. Apply Pay Gateway mTLS env patch.
6. Restart Pay Gateway.
7. Run live runtime smoke and inspect request audit logs.
```

Dry-run the env change first:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/set-live-mtls-mode.ps1 -Mode enable
```

Apply the env patches only inside an approved maintenance window:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/set-live-mtls-mode.ps1 -Mode enable -Apply
```

Rollback env values if Core HTTPS or Gateway smoke fails:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/set-live-mtls-mode.ps1 -Mode rollback -Apply
```

The script backs up both env files before writing. It intentionally does not
restart Core or Gateway automatically; restart must use the approved deployment
command for the host after each verification step.

Sandbox direct mTLS trial:

```powershell
$env:Path = "C:\Program Files\Git\usr\bin;$env:Path"
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/generate-mtls-certificates.ps1 -Environment sandbox
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/start-core-sandbox.ps1 -EnableDirectMtls
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/start-pay-gateway-sandbox.ps1 -GatewayImage orbi-pay-gateway:local -EnableDirectMtls
```

If direct mTLS is enabled, sandbox Gateway talks to Core through:

```text
https://core-sandbox:3000
```

and uses `/opt/orbi/mtls/pay-gateway-client.crt`,
`/opt/orbi/mtls/pay-gateway-client.key`, and
`/opt/orbi/mtls/orbi-internal-ca.crt`.

Stop the full stack without deleting data:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  down
```

Do not use `down --volumes` outside a disposable development environment.
