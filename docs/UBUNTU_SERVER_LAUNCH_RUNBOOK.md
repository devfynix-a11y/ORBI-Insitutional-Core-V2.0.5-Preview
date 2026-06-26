# ORBI Ubuntu Server Launch Runbook

This runbook prepares a dedicated Ubuntu machine for ORBI development,
staging, and later production deployment. The first installation must be
treated as staging until database migration, financial reconciliation,
backup restore, and rollback tests pass.

## 1. Recommended machine

- Ubuntu Server 24.04 LTS
- 8 dedicated CPU cores or better
- 32 GB RAM
- 500 GB or larger encrypted NVMe SSD
- Second encrypted disk or independent backup destination
- Wired network connection, static LAN address, and UPS protection
- Static public IP, business router port forwarding, or a secure tunnel

Do not expose PostgreSQL, Valkey, MinIO, Grafana, Prometheus, Docker, SSH, or
Coolify directly to the public internet. Only the HTTPS API edge should be
public.

## 2. Install and secure Ubuntu

During Ubuntu installation:

1. Enable full-disk encryption where unattended restart requirements allow it.
2. Install OpenSSH Server.
3. Create a non-root administrator account.
4. Apply all firmware and operating-system updates.
5. Reserve a static LAN address in the router.

Clone the approved Core repository, then run:

```bash
cd /path/to/orbi-core
sudo ADMIN_VPN_CIDR="<trusted-cidr>" \
  bash ops/self-hosted/scripts/provision-ubuntu.sh
```

Log out and back in after provisioning so the `orbi` account receives Docker
group membership. Confirm Docker before proceeding:

```bash
sudo -iu orbi
docker version
docker compose version
```

Do not enable UFW until a trusted SSH rule is present and a second terminal can
successfully connect.

## 3. Install the repository

Use a read-only deploy key and an approved branch or commit:

```bash
sudo -iu orbi
git clone <CORE_REPOSITORY_SSH_URL> /srv/orbi/app
cd /srv/orbi/app
git fetch --prune origin
git checkout <APPROVED_COMMIT_OR_RELEASE_BRANCH>
```

Production must not deploy an uncommitted working tree.

## 4. Generate deployment secrets

```bash
cd /srv/orbi/app
sudo bash ops/self-hosted/scripts/generate-secrets.sh
sudoedit ops/self-hosted/.env.production
```

Complete every external integration value, including Firebase, payment
providers, SMTP, Cloudflare R2, and any temporary Supabase compatibility
credentials. Keep the R2 public prefix set to:

```env
CLOUDFLARE_PUBLIC_URL_PREFIX=https://media-stock.orbifinancial.com
```

Never commit `.env.production`, private keys, certificates, database dumps, or
provider credentials.

## 5. Choose one edge deployment

### Direct Docker edge

Use this when ORBI manages Nginx and TLS directly:

```bash
sudo install -m 0640 fullchain.pem /srv/orbi/secrets/tls/fullchain.pem
sudo install -m 0640 privkey.pem /srv/orbi/secrets/tls/privkey.pem
sudo chown root:orbi /srv/orbi/secrets/tls/*.pem

cd /srv/orbi/app
bash ops/self-hosted/scripts/validate-deployment.sh
bash ops/self-hosted/scripts/deploy.sh
```

The `direct-edge` profile publishes only ports 80 and 443.

### Coolify edge

Use Coolify only after the direct Compose stack is validated. Follow
`ops/self-hosted/COOLIFY_DEPLOYMENT.md`; do not enable the `direct-edge`
profile because Coolify owns HTTPS routing. Assign the public API domain only
to the Core service on port 3000.

## 6. Validate the platform

Check service state and the public edge:

```bash
cd /srv/orbi/app
docker compose --env-file ops/self-hosted/.env.production \
  -f ops/self-hosted/docker-compose.prod.yml ps

curl --fail https://api.orbifinancial.com/health
curl --fail https://api.orbifinancial.com/ready
```

Confirm that external scans cannot reach ports `3000`, `5432`, `6379`, `9000`,
`9001`, `9090`, or `3001`.

Valkey must remain private, password protected, persistent, and configured with
`noeviction`. Restart it once during staging and verify sessions,
idempotency records, and queues recover correctly.

## 7. Enable automatic restart

For the direct Docker edge:

```bash
cd /srv/orbi/app
sudo bash ops/self-hosted/scripts/install-systemd.sh
sudo systemctl enable --now orbi-stack
sudo systemctl status orbi-stack
```

Coolify-managed deployments should use Coolify lifecycle management instead of
the ORBI systemd unit.

## 8. Backup and restore drill

Create and verify a manual logical backup:

```bash
cd /srv/orbi/app
sudo bash ops/self-hosted/scripts/backup-now.sh
sudo ls -lh /srv/orbi/backups/database
```

Copy encrypted backups to a different physical machine or ORBI-controlled
object-storage destination. A backup on the same laptop is not disaster
recovery.

Restore only on an isolated staging environment:

```bash
sudo ORBI_CONFIRM_RESTORE=YES \
  bash ops/self-hosted/scripts/restore-database.sh \
  /srv/orbi/backups/database/<backup-file>.dump
```

After restore, reconcile user counts, wallet balances, ledger totals,
transactions, audit chains, PaySafe records, shared pots, and shared budgets.

## 9. Production gate

The infrastructure can be deployed before the complete Supabase replacement,
but ORBI financial production must remain blocked until:

- all required financial repositories and RPC behavior use local PostgreSQL;
- duplicate and concurrent money operations are idempotent;
- PaySafe, transfers, pots, budgets, reversals, and disputes pass integration
  tests;
- local authentication, JWT rotation, sessions, OTP, PIN, and trusted devices
  pass security tests;
- backup restore and point-in-time recovery are demonstrated;
- ledger and wallet reconciliation reports show no unexplained drift;
- rollback is rehearsed with the previous application image.

The deployment validator intentionally rejects local financial production mode
unless `ORBI_LOCAL_DATA_PRODUCTION_READY=true` is set after these gates pass.

## 10. Scale after stability

One laptop is one failure domain. After staging is reliable:

1. Move PostgreSQL to a dedicated host with WAL archiving and a replica.
2. Run Valkey primary, replica, and Sentinel voters on independent hosts.
3. Separate API and background workers.
4. Add an independent backup destination and restore-test host.
5. Add redundant power, networking, monitoring, and operator access.

High scale begins with tested recovery and financial correctness, not simply
with more containers.
