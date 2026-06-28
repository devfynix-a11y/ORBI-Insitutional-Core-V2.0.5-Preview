#!/usr/bin/env bash
set -euo pipefail

if [[ "${ORBI_CONFIRM_RESTORE:-}" != "YES" ]]; then
  echo "Set ORBI_CONFIRM_RESTORE=YES to acknowledge destructive database restore." >&2
  exit 1
fi

backup="${1:-}"
[[ -f "${backup}" ]] || {
  echo "Usage: ORBI_CONFIRM_RESTORE=YES $0 /absolute/path/to/backup.dump" >&2
  exit 1
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
compose="${root}/ops/self-hosted/docker-compose.prod.yml"
env_file="${ORBI_CORE_ENV_FILE:-${root}/ops/self-hosted/.env.production}"

export ORBI_CORE_ENV_FILE="${env_file}"

set -a
source "${env_file}"
set +a

[[ -n "${ORBI_BACKUP_ENCRYPTION_KEY:-}" ]] || {
  echo "ORBI_BACKUP_ENCRYPTION_KEY is required." >&2
  exit 1
}
command -v openssl >/dev/null 2>&1 || {
  echo "openssl is required to decrypt backups." >&2
  exit 1
}

if [[ -f "${backup}.sha256" ]]; then
  (cd "$(dirname "${backup}")" && sha256sum --check "$(basename "${backup}.sha256")")
fi

restore_file="${backup}"
temporary_plain=""
if [[ "${backup}" == *.enc ]]; then
  temporary_plain="$(mktemp)"
  openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 200000 \
    -in "${backup}" \
    -out "${temporary_plain}" \
    -pass env:ORBI_BACKUP_ENCRYPTION_KEY
  restore_file="${temporary_plain}"
fi
cleanup() {
  [[ -z "${temporary_plain}" ]] || rm -f "${temporary_plain}"
}
trap cleanup EXIT

docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" stop gateway core database-backup
docker compose --env-file "${env_file}" -f "${compose}" exec -T postgres \
  pg_restore --username "${ORBI_POSTGRES_USER:-orbi}" \
  --dbname "${ORBI_POSTGRES_DB:-orbi}" \
  --clean --if-exists --no-owner --no-privileges < "${restore_file}"
docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" start core gateway database-backup

echo "Restore completed. Run reconciliation and the release smoke suite before reopening traffic."
