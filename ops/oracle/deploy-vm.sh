#!/usr/bin/env bash

set -euo pipefail

APP_DIR="${APP_DIR:-/opt/orbi/orbi-institutional-core}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.oracle.yml}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required on the Oracle Cloud VM" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin is required on the Oracle Cloud VM" >&2
  exit 1
fi

if [[ -z "${ORBI_IMAGE:-}" ]]; then
  echo "ORBI_IMAGE is required" >&2
  exit 1
fi

if [[ -z "${ORBI_ENV_FILE_B64:-}" ]]; then
  echo "ORBI_ENV_FILE_B64 is required" >&2
  exit 1
fi

mkdir -p "${APP_DIR}"
cd "${APP_DIR}"

printf '%s' "${ORBI_ENV_FILE_B64}" | base64 -d > .env
printf 'ORBI_IMAGE=%s\n' "${ORBI_IMAGE}" > .env.deploy

docker compose --env-file .env.deploy -f "${COMPOSE_FILE}" pull
docker compose --env-file .env.deploy -f "${COMPOSE_FILE}" up -d --remove-orphans
docker image prune -f
