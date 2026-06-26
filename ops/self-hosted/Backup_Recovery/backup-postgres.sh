#!/bin/sh
set -eu

interval="${ORBI_BACKUP_INTERVAL_SECONDS:-86400}"
retention_days="${ORBI_BACKUP_RETENTION_DAYS:-14}"

while true; do
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  output="/backups/orbi-${timestamp}.dump"
  temporary="${output}.partial"

  pg_dump --format=custom --no-owner --no-privileges --file="${temporary}"
  mv "${temporary}" "${output}"
  sha256sum "${output}" > "${output}.sha256"
  find /backups -type f -mtime "+${retention_days}" -delete

  sleep "${interval}"
done
