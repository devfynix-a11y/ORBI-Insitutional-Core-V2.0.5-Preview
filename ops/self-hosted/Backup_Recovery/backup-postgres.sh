#!/bin/sh
set -eu

interval="${ORBI_BACKUP_INTERVAL_SECONDS:-86400}"
retention_days="${ORBI_BACKUP_RETENTION_DAYS:-14}"
encryption_key="${ORBI_BACKUP_ENCRYPTION_KEY:-}"

if [ -z "${encryption_key}" ]; then
  echo "ORBI_BACKUP_ENCRYPTION_KEY is required for encrypted database backups." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required for encrypted database backups." >&2
  exit 1
fi

umask 077

while true; do
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  plain="/backups/orbi-${timestamp}.dump.partial"
  output="/backups/orbi-${timestamp}.dump.enc"
  temporary="${output}.partial"
  manifest="/backups/orbi-${timestamp}.manifest"

  pg_dump --format=custom --no-owner --no-privileges --file="${plain}"
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 200000 \
    -in "${plain}" \
    -out "${temporary}" \
    -pass env:ORBI_BACKUP_ENCRYPTION_KEY
  rm -f "${plain}"
  mv "${temporary}" "${output}"
  sha256sum "${output}" > "${output}.sha256"
  {
    echo "created_at=${timestamp}"
    echo "database=${PGDATABASE:-}"
    echo "format=pg_dump_custom_openssl_aes_256_cbc_pbkdf2"
    echo "artifact=$(basename "${output}")"
    sha256sum "${output}"
  } > "${manifest}"
  find /backups -type f -mtime "+${retention_days}" \
    \( -name '*.dump.enc' -o -name '*.dump.enc.sha256' -o -name '*.manifest' \) -delete

  sleep "${interval}"
done
