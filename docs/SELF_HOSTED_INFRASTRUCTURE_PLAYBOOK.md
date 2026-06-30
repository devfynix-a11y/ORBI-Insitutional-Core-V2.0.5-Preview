# ORBI Self-Hosted Infrastructure Playbook

This playbook provisions ORBI Core on an organization-managed Linux VM with a
static public IP. It removes dependence on paid application hosts without
prematurely removing Supabase. Supabase Auth, Postgres, Storage, and RPC access
remain active until their private replacements pass migration, reconciliation,
restore, and rollback testing.

## 1. Target architecture

Public:

- `api.orbifinancial.com` points to the VM static IP.
- `pay.orbifinancial.com` points to the same VM or Cloudflare Tunnel and routes
  only to ORBI Pay Gateway.
- `ops.orbifinancial.com` points to the same VM but is protected by
  Cloudflare Access, VPN, or a fixed administration allowlist.
- TCP 443 terminates TLS at Nginx.
- TCP 80 is used only for redirect and certificate renewal.

Private:

- ORBI Core listens on `127.0.0.1:3000`.
- ORBI Pay Gateway listens on `127.0.0.1:3100` and is also reachable inside
  Docker as `http://pay-gateway:3100`.
- ORBI Ops Console is served by Core at `/ops` only through the private
  `ops.orbifinancial.com` hostname.
- Valkey listens on the private container network only.
- S3-compatible object storage remains on the private container network.
- SSH is reachable only through a VPN or fixed administration allowlist.
- PostgreSQL and backup storage must not be exposed to the public internet.

The development container modules are maintained under:

```txt
ops/self-hosted/Auth_Security
ops/self-hosted/Storage
ops/self-hosted/Pay_Gateway
```

See `ops/self-hosted/README.md` for combined and component-specific commands.
See `docs/UBUNTU_SERVER_LAUNCH_RUNBOOK.md` for the exact first-machine
installation and deployment sequence.
See `docs/KEYCLOAK_AUTHENTICATION_PLAYBOOK.md` for identity, JWT, session, and
mobile PKCE migration.

Temporary external compatibility:

- Keycloak replaces Supabase Auth and is persisted in a separate PostgreSQL
  database on the private network.
- Supabase financial-data compatibility remains connected through
  `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_ANON_KEY` until
  financial repositories complete their local PostgreSQL migration.
- Firebase remains enabled for mobile push notifications.
- Payment and messaging gateways remain separate services with signed,
  authenticated callbacks.
- ORBI Shop calls `https://pay.orbifinancial.com/v1/paysafe/*` with its
  private `ORBI_SHOP_PAY_API_KEY`; Pay Gateway signs service-payment requests
  into Core. Do not expose the service key to browser, mobile, logs, or Git.

Cloudflare Tunnel public hostnames for the local VM:

- `api.orbifinancial.com` -> `http://orbi-core:3000` or `http://core:3000`
  depending on the active compose project aliases.
- `pay.orbifinancial.com` -> `http://pay-gateway:3100`.
- `auth.orbifinancial.com` -> `http://keycloak:8080`.
- `ops.orbifinancial.com` -> `http://orbi-core:3000` or `http://core:3000`
  and protect it with Cloudflare Access/VPN.

Pay Gateway readiness can show provider adapters as `DOWN` until real bank or
mobile-money token references are configured. That is expected while PaySafe
service intake and signed Core callbacks are being tested.

Private operations console:

- URL: `https://ops.orbifinancial.com/ops`
- JSON API: `/api/admin/ops/*`
- Auth: Cloudflare Access/VPN at the edge plus `ORBI_MONITOR_API_KEY` for JSON
  endpoints. Every action request must also include `x-orbi-operator-id`.
- Mode: monitoring, action request, approval, and VM-agent queue. Execution is
  fail-closed unless `ORBI_OPS_AGENT_EXECUTION_ENABLED=true`.
- Purpose: view deployment state, safety switches, secret presence, backup
  artifacts, approved deployment commands, backup procedure, restore-drill
  procedure, and audited one-click deploy/backup/restore-drill requests.
- Two-person control: deploy, backup, and restore-drill action requests require
  at least `ORBI_OPS_REQUIRED_APPROVALS=2` distinct operators. The requester
  cannot approve their own action.
- Restore control: console restore is limited to staging, isolated, or drill
  targets. Production restore is an incident runbook action, not a dashboard
  button.

## 2. Minimum VM baseline

Recommended starting point:

- Ubuntu Server 24.04 LTS
- 4 dedicated CPU cores
- 16 GB RAM
- 200 GB encrypted SSD
- Separate encrypted backup disk or organization-controlled backup target
- Static public IP and private administration network
- UPS-backed host and tested power/network recovery

Increase capacity based on measured API latency, worker queues, Valkey memory,
database growth, and backup duration. Do not place the only database copy on
the same physical disk as the API.

## 3. Base operating-system setup

Run as an authorized administrator:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y ca-certificates curl git nginx ufw fail2ban unattended-upgrades
sudo adduser --disabled-password --gecos "" orbi
sudo usermod -aG sudo orbi
```

Install Docker Engine and the Compose plugin from Docker's official Ubuntu
repository. Pin a supported major version and record it in the operations log.

Create the application directories:

```bash
sudo install -d -o orbi -g orbi -m 0750 /srv/orbi/core
sudo install -d -o root -g orbi -m 0750 /etc/orbi
sudo install -d -o root -g root -m 0700 /var/backups/orbi
```

## 4. Firewall and network boundary

Default-deny incoming traffic:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow from <ADMIN_VPN_CIDR> to any port 22 proto tcp
sudo ufw enable
```

Do not open ports `3000`, `5432`, or `6379` publicly. Confirm from a separate
internet connection that only approved ports respond.

## 5. Repository access

Use a read-only deploy key dedicated to this VM. Do not use a developer's
personal GitHub credentials.

```bash
sudo -u orbi git clone <CORE_REPOSITORY_SSH_URL> /srv/orbi/core/repository
cd /srv/orbi/core/repository
git remote -v
```

Deploy only an approved branch or immutable commit SHA. A production deployment
must never run directly from an unreviewed working tree.

## 6. Secrets and environment

Create `/etc/orbi/core.env` with mode `0640`, owner `root`, and group `orbi`.
Start from `.env.example`, then provide production values.

Required self-hosting identity:

```env
NODE_ENV=production
PORT=3000
ORBI_ENFORCE_HTTPS=true
ORBI_TLS_ENABLED=false
RP_ID=api.orbifinancial.com
ORBI_WEB_ORIGIN=https://api.orbifinancial.com
ORBI_PRIMARY_CORE_BASE_URL=https://api.orbifinancial.com
ORBI_PRIMARY_CORE_REGION=private-datacenter
ORBI_PRIMARY_CORE_JURISDICTION=TZ
```

Keep Supabase variables populated only while the compatibility provider is
still required. Store Firebase, JWT, KMS, worker, gateway, SMTP, and provider
secrets in the same protected secret source, never in Git or a Docker image.

Production secret inventory:

- Core signing and encryption: `JWT_SECRET`, `SESSION_SECRET`,
  `KMS_MASTER_KEY`, `KMS_SALT`.
- Internal service trust: `WORKER_SECRET`, `WORKER_SIGNING_SECRET`,
  `ORBI_INTERNAL_MTLS_PROXY_SHARED_SECRET`, `ORBI_MONITOR_API_KEY`,
  `ORBI_BOOTSTRAP_ADMIN_SECRET`.
- Identity: `ORBI_KEYCLOAK_ADMIN_PASSWORD` and the public Keycloak issuer
  values.
- Data plane: `ORBI_POSTGRES_PASSWORD`, `DATABASE_URL`,
  `ORBI_VALKEY_PASSWORD`, `VALKEY_URL`, storage root credentials, and backup
  retention settings.
- Ops control plane: `ORBI_OPS_REQUIRED_APPROVALS=2` and
  `ORBI_OPS_AGENT_EXECUTION_ENABLED=false` until the VM agent has been tested
  with non-production drills.
- Cloudflare R2 images: `CLOUDFLARE_ACCOUNT_ID`,
  `CLOUDFLARE_ACCESS_KEY_ID`, `CLOUDFLARE_SECRET_ACCESS_KEY`,
  `CLOUDFLARE_BUCKET_NAME`, and `CLOUDFLARE_PUBLIC_URL_PREFIX`.
- Mobile trust: `ORBI_ANDROID_APP_HASH`, `ORBI_ANDROID_SMS_HASH`, iOS bundle
  IDs, app IDs, and allowed origins.
- Messaging and payments: Firebase service account, ORBI Talk Gateway API
  key/user metadata, ORBI Pay Gateway operator key, webhook signing secrets,
  and provider credentials.
- Optional intelligence and alerts: `GEMINI_API_KEY`, `ADMIN_ALERT_EMAIL`,
  and `ADMIN_ALERT_PHONE`.

For repository-based deployments, generate the private file from
`ops/self-hosted/.env.production.example` into
`ops/self-hosted/.env.production`. For a hardened VM, copy the reviewed values
into `/etc/orbi/core.env` with owner `root`, group `orbi`, and mode `0640`.
The production Compose stack reads `ORBI_CORE_ENV_FILE`; the provided systemd
unit sets it to `/etc/orbi/core.env`, while local repository deployments default
to `ops/self-hosted/.env.production`.
Cloudflare R2 is used only for public or sanitized images; never store raw KYC
documents there unless a separate private bucket, access policy, and retention
process are approved.

## 7. Build and release procedure

Every release follows this order:

```bash
cd /srv/orbi/core/repository
git fetch --prune origin
git checkout <APPROVED_COMMIT_SHA>
npm ci
npm run lint
npm test
docker build --pull --tag orbi-core:<RELEASE_ID> .
```

Start the candidate container on loopback with the protected environment file:

```bash
docker run -d \
  --name orbi-core-candidate \
  --restart unless-stopped \
  --env-file /etc/orbi/core.env \
  --publish 127.0.0.1:3001:3000 \
  orbi-core:<RELEASE_ID>
```

Validate before switching traffic:

```bash
curl --fail http://127.0.0.1:3001/health
curl --fail http://127.0.0.1:3001/ready
ORBI_BASE_URL=http://127.0.0.1:3001 \
  ORBI_MONITOR_API_KEY=<MONITOR_KEY> \
  node scripts/release-smoke.mjs
```

Do not run financial write smoke tests against production customer wallets.
Use isolated operational test identities and reconcile every test transaction.

## 8. Nginx and TLS

Nginx should proxy only to the active loopback port:

```nginx
server {
    listen 443 ssl http2;
    server_name api.orbifinancial.com;

    ssl_certificate /etc/letsencrypt/live/api.orbifinancial.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.orbifinancial.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Obtain a certificate with Certbot or an approved internal certificate process.
Test renewal and reload Nginx only after `nginx -t` succeeds.

## 9. Safe traffic switch and rollback

Use blue/green loopback ports, for example active `3000` and candidate `3001`.
After candidate validation:

1. Update the Nginx upstream to the candidate port.
2. Run `sudo nginx -t`.
3. Reload Nginx.
4. Re-run public health and release smoke checks.
5. Keep the previous container stopped but available during the rollback
   window.

If health, reconciliation, authentication, or settlement checks fail, restore
the previous Nginx upstream and reload immediately. Roll back API and workers
together because they share schema and settlement assumptions.

## 10. Repository-triggered deployment

Begin with manual, commit-pinned releases. After the VM process is stable,
automation may invoke the same release script using a dedicated self-hosted
runner or signed webhook.

Automation requirements:

- deployment is allowed only from a protected release branch;
- the triggering commit must pass Core CI;
- the VM checks out the exact approved SHA;
- concurrent deployments are locked;
- secrets are read from `/etc/orbi`, not workflow input;
- health and smoke checks must pass before traffic switches;
- failed checks automatically restore the previous upstream;
- every deployment records actor, SHA, release ID, start time, and result.

A self-hosted runner must use a dedicated unprivileged account and must not run
untrusted pull-request code. Prefer a narrow deploy service over granting the
runner unrestricted root or Docker access.

## 11. Monitoring and incident controls

Monitor at minimum:

- `/health`, `/ready`, and `/health/deep`
- API latency and HTTP error rate
- authentication failures and quarantine events
- Valkey connectivity, memory pressure, persistence health, and queue lag
- settlement lifecycle stalls
- ledger reconciliation drift
- disk, memory, CPU, temperature, and certificate expiry
- Supabase connectivity while the compatibility layer remains active

Send alerts to an independently reachable channel. Keep logs structured,
access-controlled, time-synchronized, and retained according to financial and
privacy requirements.

## 12. Backup and restore

During the compatibility phase, retain Supabase backups and export evidence
before every schema migration. When private PostgreSQL is introduced:

- enable encrypted full backups and then add continuous WAL archiving;
- keep encrypted copies on the live host disk and outside the primary VM under
  ORBI-controlled keys;
- run scheduled restore drills on an isolated host;
- reconcile wallet balances, ledger totals, transaction counts, audit chains,
  and critical RPC behavior after every test restore;
- record recovery point and recovery time results.

Never expose PostgreSQL or raw backup files through a public endpoint. Remote
operations should use authenticated administration job triggers and return only
status and audit evidence.

The production stack creates encrypted PostgreSQL dump artifacts under
`/srv/orbi/backups/database` and mirrors those encrypted artifacts to Cloudflare
R2 using `backup-r2-replicator`. Do not copy raw PostgreSQL volume files while
PostgreSQL is running; use logical dumps for baseline recovery, then add WAL
archive and point-in-time recovery once the restore drill is proven.

## 13. Native PostgreSQL migration status

The local development stack now boots the complete master schema against
PostgreSQL 16 and records `20260622_native_postgres_runtime`. The bootstrap is
idempotent and has been validated twice against an empty disposable database.

Implemented:

- native PostgreSQL pooling and transaction boundaries;
- Keycloak-compatible `auth.uid()`, `auth.role()`, and `auth.jwt()` claims;
- explicit `anon`, `authenticated`, and `service_role` database roles;
- native table operations and named PostgreSQL RPC execution;
- explicit PostgreSQL-safe enrichment for shared pot, shared budget, and
  treasury approval reads that previously depended on nested PostgREST
  relationship projection syntax;
- Valkey Pub/Sub replacement for Supabase Realtime socket broadcasts;
- wallet, ledger, internal settlement, PaySafe, shared-pot, budget, webhook,
  reversal, review-hold, and repair integration coverage;
- deterministic sandbox financial fixtures;
- Windows backup, schema-apply, test, and restore commands.

Verified locally:

- 135 public tables;
- 101 RLS policies;
- 3/3 native PostgreSQL read integration tests;
- 21/21 native PostgreSQL financial mutation tests;
- 32/32 financial authority, PaySafe, shared-pot, and ledger invariant tests.
- 133/133 currently runnable test cases passing, with 24 database/provider
  tests intentionally skipped unless explicitly enabled.

Remaining production gates:

- keep the local adapter fail-closed for any newly introduced nested
  PostgREST relationship projection and migrate future occurrences to explicit
  joins/enrichment before release;
- complete Keycloak-native administration for every legacy Supabase Auth call;
- complete protected KYC/document storage migration;
- run a restore drill on an isolated machine and reconcile all balances;
- configure Talk Gateway and external payment-provider credentials;
- run concurrency/load tests and a full mobile end-to-end acceptance cycle.

Do not enable real-money traffic or background settlement jobs until these
remaining gates pass and reconciliation evidence is signed off.

## 14. Go-live checklist

- DNS resolves to the static VM IP.
- Only ports 80 and 443 are public; SSH is restricted.
- TLS, HSTS, WebSocket upgrade, and certificate renewal work.
- Core binds only to loopback behind Nginx.
- Production secrets are protected and absent from Git and images.
- Keycloak, PostgreSQL, Valkey, storage, and Firebase push pass health checks.
- Valkey is private, persistent, and configured with `noeviction`.
- Core CI, unit tests, release smoke, and reconciliation pass.
- Backup restore evidence is current.
- Rollback to the previous image has been rehearsed.
- Mobile and admin clients use only `https://api.orbifinancial.com`.

## 15. Recommended implementation roadmap

Do not wait for the remote VM before continuing engineering. Build and validate
the same container architecture locally first, then deploy it to a remote
staging VM, and only promote it after recovery and financial-integrity testing.

### Phase 1: Local engineering environment

- Install WSL2 with Ubuntu 24.04 and Docker Engine or Docker Desktop.
- Do not introduce Coolify during the first local validation cycle.
- Start PostgreSQL, Valkey, MinIO, and Core using the Compose modules under
  `ops/self-hosted`.
- Use disposable development identities and financial data only.
- Test signup, login, token refresh, logout, image uploads, wallets, internal
  transfers, PaySafe, shared pots, and shared budgets.
- Test container restarts and verify that PostgreSQL, Valkey, and MinIO volumes
  persist correctly.

### Phase 2: Complete the local Supabase replacement

Migrate runtime dependencies one subsystem at a time:

1. User and staff profile repositories.
2. Wallet and vault reads.
3. Ledger RPC execution and transaction posting.
4. Internal transfers and settlement workers.
5. PaySafe lifecycle.
6. Shared pots, shared budgets, and bill reserves.
7. OTP, password reset, passkeys, PINs, and trusted-device state.
8. Realtime event delivery.
9. Private document and KYC storage.

Every subsystem requires PostgreSQL read/write integration tests, idempotency
tests, repeated-request tests, rollback behavior, and financial reconciliation.
Remove Supabase only after runtime references reach zero.

### Local PostgreSQL operator commands

Run these from the repository root on Windows:

```powershell
# Back up the current database and create a SHA-256 checksum.
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/backup-windows.ps1

# Back up, apply the complete idempotent schema, and verify roles/policies.
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/apply-database-schema-windows.ps1

# Run native PostgreSQL read integration tests.
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/test-local-financial-db-windows.ps1

# Apply sandbox fixtures and run all native PostgreSQL mutation tests.
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/test-local-financial-db-windows.ps1 -AllowWrites

# Destructive restore. Core is stopped during restore.
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/restore-database-windows.ps1 `
  -BackupPath "D:\path\to\orbi-backup.dump" `
  -ConfirmRestore
```

Backups under `backups/local` are excluded from Git. Copy encrypted backups to
an approved off-machine location. A successful dump is not sufficient evidence:
restore it, run both database suites, and reconcile ledger totals before use.

### Phase 3: Acquire a remote staging VM

Recommended starting capacity:

- 8 dedicated vCPU
- 32 GB RAM
- 500 GB encrypted NVMe storage
- Ubuntu Server 24.04 LTS or Debian 12
- static public IP
- deployment inside the required data-residency jurisdiction

Treat this machine as staging first. Do not place real customer funds or
production identities on the first deployment.

### Phase 4: Install Coolify on staging

Use Coolify for:

- Git-based deployments;
- environment and secret management;
- container health checks;
- TLS certificate automation;
- deployment history and rollback;
- controlled application lifecycle.

Deploy the reviewed Docker Compose configuration from the repository. Keep
PostgreSQL, Valkey, MinIO, monitoring internals, and backup services private
without published host ports. Expose only the Core API through Coolify's proxy.
Restrict Coolify administration through VPN access or a strict IP allowlist.

Coolify's Compose deployment treats the Compose file as the source of truth.
Persistent volumes, required environment variables, service health checks, and
private networking must therefore remain explicitly defined in the repository.

### Phase 5: Deploy and validate staging

Deploy:

- `Auth_Security`: PostgreSQL and Valkey;
- `Storage`: private MinIO;
- ORBI Core API;
- `Observability`: Prometheus and Grafana;
- `Backup_Recovery`;
- Cloudflare R2 integration for public or sanitized images only.

Then:

- initialize the database from scratch;
- create isolated test identities and wallets;
- run the complete automated test suite and database integration suite;
- test duplicate requests and concurrent settlements;
- restart every container individually;
- simulate Valkey unavailability and database reconnects;
- verify fail-closed behavior for security and idempotency controls;
- perform an API rollback;
- complete a backup restore and ledger reconciliation drill.

### Phase 6: Production hardening

- Separate Coolify/application hosting from the primary database host where
  possible.
- Add PostgreSQL WAL archiving, point-in-time recovery, and a streaming replica
  on an independent failure domain.
- Progress Valkey from one persistent node to a primary, replica, and at least
  three Sentinel voters on independent failure domains.
- Use Valkey Cluster only when measured throughput or memory requirements need
  sharding.
- Add encrypted off-machine backups, host-level monitoring, UPS protection,
  redundant networking, certificate-expiry alerts, and tested incident access.
- Replace symmetric JWT signing with asymmetric keys and rehearsed JWKS
  rotation.
- Separate background workers from API containers.

### Phase 7: Production launch

- Freeze schema changes during the launch window.
- Verify current backup and restore evidence.
- Run authentication, settlement, PaySafe, wallet, and reconciliation smoke
  checks.
- Confirm no unexplained ledger drift.
- Point `api.orbifinancial.com` to the production edge.
- Release mobile and admin clients only after the public API smoke tests pass.
- Keep the previous application image and rollback path available during the
  defined observation window.

## 16. Coolify and high availability

Coolify simplifies deployment management, but it does not create high
availability by itself. A single Coolify-managed VM is still one failure
domain.

Real high availability requires:

- multiple physical or virtual hosts;
- PostgreSQL replication and point-in-time recovery;
- Valkey replication with Sentinel or a correctly designed Valkey Cluster;
- off-host encrypted backups;
- independent monitoring and alert delivery;
- tested DNS, proxy, service, database, and storage failover;
- documented operators and recovery procedures.

Start with one well-tested staging host. Add complexity only after the local and
single-host architecture is stable, observable, recoverable, and financially
reconciled.
