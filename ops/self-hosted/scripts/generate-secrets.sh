#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo so protected secret files can be created." >&2
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
template="${root}/ops/self-hosted/.env.production.example"
target="${root}/ops/self-hosted/.env.production"
monitor_file="/srv/orbi/secrets/orbi_monitor_api_key.txt"

if [[ -e "${target}" ]]; then
  echo "${target} already exists; refusing to overwrite it." >&2
  exit 1
fi

cp "${template}" "${target}"
chown orbi:orbi "${target}"
chmod 0640 "${target}"

random_hex() {
  openssl rand -hex "$1"
}

set_value() {
  local key="$1"
  local value="$2"
  sed -i "s|^${key}=.*$|${key}=${value}|" "${target}"
}

postgres_password="$(random_hex 32)"
valkey_password="$(random_hex 32)"
storage_password="$(random_hex 32)"
monitor_key="$(random_hex 32)"

set_value JWT_SECRET "$(random_hex 64)"
set_value SESSION_SECRET "$(random_hex 64)"
set_value KMS_MASTER_KEY "$(random_hex 64)"
set_value KMS_SALT "$(random_hex 32)"
set_value WORKER_SECRET "$(random_hex 32)"
set_value WORKER_SIGNING_SECRET "$(random_hex 64)"
set_value ORBI_MONITOR_API_KEY "${monitor_key}"
set_value ORBI_BOOTSTRAP_ADMIN_SECRET "$(random_hex 32)"
set_value ORBI_INTERNAL_MTLS_PROXY_SHARED_SECRET "$(random_hex 64)"
set_value ORBI_KEYCLOAK_ADMIN_PASSWORD "$(random_hex 32)"
set_value ORBI_POSTGRES_PASSWORD "${postgres_password}"
set_value DATABASE_URL "postgresql://orbi:${postgres_password}@postgres:5432/orbi"
set_value ORBI_VALKEY_PASSWORD "${valkey_password}"
set_value VALKEY_URL "redis://:${valkey_password}@valkey:6379/0"
set_value ORBI_STORAGE_ROOT_PASSWORD "${storage_password}"
set_value CLOUDFLARE_R2_IMAGE_BUCKET "orbishop-storage"
set_value ORBI_IMAGE_PUBLIC_BASE_URL "https://media-stock.orbifinancial.com"
set_value ORBI_BACKUP_ENCRYPTION_KEY "$(random_hex 64)"
set_value ORBI_BACKUP_R2_BUCKET "orbishop-storage"
set_value ORBI_BACKUP_R2_PREFIX "database-backups"
set_value ORBI_GRAFANA_ADMIN_PASSWORD "$(random_hex 24)"
set_value ORBI_RELEASE_ID "$(date -u +%Y%m%d%H%M%S)"

install -d -o root -g orbi -m 0750 /srv/orbi/secrets
printf '%s' "${monitor_key}" > "${monitor_file}"
chown root:orbi "${monitor_file}"
chmod 0640 "${monitor_file}"

echo "Generated ${target} and ${monitor_file}."
echo "Fill external credentials, allowed origins, Android hash, and TLS paths before deployment."
