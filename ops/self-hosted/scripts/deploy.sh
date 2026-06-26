#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
compose="${root}/ops/self-hosted/docker-compose.prod.yml"
env_file="${ORBI_CORE_ENV_FILE:-${root}/ops/self-hosted/.env.production}"

export ORBI_CORE_ENV_FILE="${env_file}"

bash "${root}/ops/self-hosted/scripts/validate-deployment.sh"

docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" pull --ignore-buildable
docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" build --pull core
docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" up -d --remove-orphans

echo "Waiting for Core health..."
for _ in $(seq 1 60); do
  if docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" exec -T core \
    node -e "fetch('http://127.0.0.1:3000/ready').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"; then
    docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" ps
    echo "ORBI deployment is healthy."
    exit 0
  fi
  sleep 5
done

docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" ps
docker compose --profile direct-edge --env-file "${env_file}" -f "${compose}" logs --tail=200 core postgres valkey
echo "Deployment did not become ready." >&2
exit 1
