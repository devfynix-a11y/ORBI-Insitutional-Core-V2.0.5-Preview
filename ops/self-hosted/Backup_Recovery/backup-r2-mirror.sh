#!/bin/sh
set -eu

# Keep this script LF-only. Linux containers fail on CRLF shell flags.
: "${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID}"
: "${CLOUDFLARE_ACCESS_KEY_ID:?Set CLOUDFLARE_ACCESS_KEY_ID}"
: "${CLOUDFLARE_SECRET_ACCESS_KEY:?Set CLOUDFLARE_SECRET_ACCESS_KEY}"

bucket="${ORBI_BACKUP_R2_BUCKET:-${CLOUDFLARE_BUCKET_NAME:-}}"
prefix="${ORBI_BACKUP_R2_PREFIX:-database-backups}"
interval="${ORBI_BACKUP_R2_SYNC_INTERVAL_SECONDS:-300}"
endpoint="${CLOUDFLARE_R2_ENDPOINT:-https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com}"

if [ -z "${bucket}" ]; then
  echo "ORBI_BACKUP_R2_BUCKET or CLOUDFLARE_BUCKET_NAME is required." >&2
  exit 1
fi

mc alias set r2 "${endpoint}" "${CLOUDFLARE_ACCESS_KEY_ID}" "${CLOUDFLARE_SECRET_ACCESS_KEY}" --api S3v4
mc mb --ignore-existing "r2/${bucket}" >/dev/null 2>&1 || true

while true; do
  mc mirror --overwrite /backups "r2/${bucket}/${prefix}"
  sleep "${interval}"
done
