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

Stop the full stack without deleting data:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  down
```

Do not use `down --volumes` outside a disposable development environment.
