#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
compose="${root}/ops/self-hosted/docker-compose.prod.yml"
env_file="${ORBI_CORE_ENV_FILE:-${root}/ops/self-hosted/.env.production}"

export ORBI_CORE_ENV_FILE="${env_file}"
output_dir="/srv/orbi/backups/database"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output="${output_dir}/orbi-manual-${timestamp}.dump"

set -a
source "${env_file}"
set +a

mkdir -p "${output_dir}"
docker compose --env-file "${env_file}" -f "${compose}" exec -T postgres \
  pg_dump --username "${ORBI_POSTGRES_USER:-orbi}" \
  --dbname "${ORBI_POSTGRES_DB:-orbi}" \
  --format=custom --no-owner --no-privileges > "${output}"

sha256sum "${output}" > "${output}.sha256"
chmod 0640 "${output}" "${output}.sha256"
echo "Backup created: ${output}"
