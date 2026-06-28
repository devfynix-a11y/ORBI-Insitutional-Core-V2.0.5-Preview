#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
compose="${root}/ops/self-hosted/docker-compose.prod.yml"
env_file="${ORBI_CORE_ENV_FILE:-${root}/ops/self-hosted/.env.production}"

export ORBI_CORE_ENV_FILE="${env_file}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || fail "Docker is not installed."
docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is unavailable."
[[ -f "${env_file}" ]] || fail "Missing ${env_file}. Run generate-secrets.sh."

set -a
source "${env_file}"
set +a

required=(
  JWT_SECRET KMS_MASTER_KEY WORKER_SECRET WORKER_SIGNING_SECRET
  ORBI_MONITOR_API_KEY ORBI_POSTGRES_PASSWORD ORBI_VALKEY_PASSWORD
  ORBI_STORAGE_ROOT_PASSWORD ORBI_GRAFANA_ADMIN_PASSWORD
  ORBI_TLS_CERT_DIRECTORY ORBI_MONITOR_KEY_FILE
  ORBI_BACKUP_ENCRYPTION_KEY
  ORBI_KEYCLOAK_PUBLIC_URL ORBI_KEYCLOAK_ADMIN_USERNAME
  ORBI_KEYCLOAK_ADMIN_PASSWORD
)
for key in "${required[@]}"; do
  [[ -n "${!key:-}" ]] || fail "Required value ${key} is empty."
done

[[ -f "${ORBI_TLS_CERT_DIRECTORY}/fullchain.pem" ]] || fail "TLS fullchain.pem is missing."
[[ -f "${ORBI_TLS_CERT_DIRECTORY}/privkey.pem" ]] || fail "TLS privkey.pem is missing."
[[ -f "${ORBI_MONITOR_KEY_FILE}" ]] || fail "Prometheus monitor-key file is missing."

for dir in /srv/orbi/backups/database /srv/orbi/secrets; do
  [[ -d "${dir}" ]] || fail "Required host directory ${dir} is missing."
done

docker compose --env-file "${env_file}" -f "${compose}" config --quiet

published="$(
  docker compose --env-file "${env_file}" -f "${compose}" config \
    | awk '/published:/{print $2}'
)"
for port in ${published}; do
  case "${port}" in
    80|443|9090|3001) ;;
    *) fail "Unexpected published port: ${port}" ;;
  esac
done

if grep -Eq '^(SUPABASE_URL|SUPABASE_SERVICE_ROLE_KEY|SUPABASE_ANON_KEY)=$' "${env_file}" \
  && grep -q '^ORBI_DATA_PROVIDER=supabase$' "${env_file}"; then
  fail "ORBI_DATA_PROVIDER=supabase but Supabase compatibility credentials are empty."
fi

if grep -q '^ORBI_DATA_PROVIDER=local$' "${env_file}" \
  && ! grep -q '^ORBI_LOCAL_DATA_PRODUCTION_READY=true$' "${env_file}"; then
  fail "Local financial-data mode is blocked until ORBI_LOCAL_DATA_PRODUCTION_READY=true."
fi

if grep -q '^ORBI_AUTH_PROVIDER=keycloak$' "${env_file}"; then
  grep -q '^ORBI_KEYCLOAK_PUBLIC_URL=https://' "${env_file}" \
    || fail "Production Keycloak must use an HTTPS public URL."
fi

echo "Deployment configuration is structurally valid."
