#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
env_file="${ORBI_CORE_ENV_FILE:-${root}/ops/self-hosted/.env.production}"
backup="${1:-}"
container="${ORBI_RESTORE_DRILL_CONTAINER:-orbi-restore-drill-postgres}"
volume="${ORBI_RESTORE_DRILL_VOLUME:-orbi-restore-drill-data}"
database="${ORBI_RESTORE_DRILL_DATABASE:-orbi}"
user="${ORBI_RESTORE_DRILL_USER:-orbi}"
password="${ORBI_RESTORE_DRILL_PASSWORD:-orbi_restore_drill_only}"

if [[ -z "${backup}" ]]; then
  echo "Usage: $0 /backups/<backup>.dump.enc" >&2
  exit 1
fi

set -a
source "${env_file}"
set +a

[[ -n "${ORBI_BACKUP_ENCRYPTION_KEY:-}" ]] || {
  echo "ORBI_BACKUP_ENCRYPTION_KEY is required." >&2
  exit 1
}

backup_name="$(basename "${backup}")"

docker rm -f "${container}" >/dev/null 2>&1 || true
docker volume rm "${volume}" >/dev/null 2>&1 || true
docker volume create "${volume}" >/dev/null

docker run -d \
  --name "${container}" \
  --network orbi-private \
  -e POSTGRES_DB="${database}" \
  -e POSTGRES_USER="${user}" \
  -e POSTGRES_PASSWORD="${password}" \
  -v "${volume}:/var/lib/postgresql/data" \
  "${ORBI_POSTGRES_IMAGE:-postgres:16-bookworm}" >/dev/null

for _ in $(seq 1 40); do
  if docker exec "${container}" pg_isready -U "${user}" -d "${database}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
docker exec "${container}" pg_isready -U "${user}" -d "${database}" >/dev/null

docker exec "${container}" psql -U "${user}" -d "${database}" -v ON_ERROR_STOP=1 -c "
DO \$\$ BEGIN CREATE ROLE service_role NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
DO \$\$ BEGIN CREATE ROLE authenticated NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
DO \$\$ BEGIN CREATE ROLE anon NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
" >/dev/null

docker run --rm \
  --env-file "${env_file}" \
  --network orbi-private \
  -v orbi-database-backups:/backups:ro \
  "${ORBI_POSTGRES_IMAGE:-postgres:16-bookworm}" \
  sh -ec "cd /backups && sha256sum --check '${backup_name}.sha256' && openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 200000 -in '/backups/${backup_name}' -pass env:ORBI_BACKUP_ENCRYPTION_KEY | PGPASSWORD='${password}' pg_restore --host '${container}' --port 5432 --username '${user}' --dbname '${database}' --no-owner --no-privileges --exit-on-error"

docker exec "${container}" psql -U "${user}" -d "${database}" -v ON_ERROR_STOP=1 -c "SELECT COUNT(*) AS public_table_count FROM information_schema.tables WHERE table_schema='public';"
docker exec "${container}" psql -U "${user}" -d "${database}" -v ON_ERROR_STOP=1 -c "SELECT to_regclass('public.wallets') AS wallets_table, to_regclass('public.financial_ledger') AS ledger_table, to_regclass('public.ops_action_requests') AS ops_actions_table;"
docker exec "${container}" psql -U "${user}" -d "${database}" -v ON_ERROR_STOP=1 -c "SELECT COUNT(*) AS rls_policy_count FROM pg_policies WHERE schemaname='public';"

echo "Restore drill completed in ${container} from ${backup_name}."
