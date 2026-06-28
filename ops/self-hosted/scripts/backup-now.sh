#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
compose="${root}/ops/self-hosted/docker-compose.prod.yml"
env_file="${ORBI_CORE_ENV_FILE:-${root}/ops/self-hosted/.env.production}"

export ORBI_CORE_ENV_FILE="${env_file}"
output_dir="/srv/orbi/backups/database"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
plain="${output_dir}/orbi-manual-${timestamp}.dump.partial"
output="${output_dir}/orbi-manual-${timestamp}.dump.enc"
manifest="${output_dir}/orbi-manual-${timestamp}.manifest"

set -a
source "${env_file}"
set +a

if [[ -z "${ORBI_BACKUP_ENCRYPTION_KEY:-}" ]]; then
  echo "ORBI_BACKUP_ENCRYPTION_KEY is required." >&2
  exit 1
fi
command -v openssl >/dev/null 2>&1 || {
  echo "openssl is required to encrypt backups." >&2
  exit 1
}

mkdir -p "${output_dir}"
umask 077
docker compose --env-file "${env_file}" -f "${compose}" exec -T postgres \
  pg_dump --username "${ORBI_POSTGRES_USER:-orbi}" \
  --dbname "${ORBI_POSTGRES_DB:-orbi}" \
  --format=custom --no-owner --no-privileges > "${plain}"

openssl enc -aes-256-cbc -salt -pbkdf2 -iter 200000 \
  -in "${plain}" \
  -out "${output}" \
  -pass env:ORBI_BACKUP_ENCRYPTION_KEY
rm -f "${plain}"
sha256sum "${output}" > "${output}.sha256"
{
  echo "created_at=${timestamp}"
  echo "database=${ORBI_POSTGRES_DB:-orbi}"
  echo "format=pg_dump_custom_openssl_aes_256_cbc_pbkdf2"
  echo "artifact=$(basename "${output}")"
  sha256sum "${output}"
} > "${manifest}"
chmod 0640 "${output}" "${output}.sha256" "${manifest}"
echo "Backup created: ${output}"
