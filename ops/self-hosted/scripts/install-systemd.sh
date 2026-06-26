#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
install -m 0644 "${root}/ops/self-hosted/systemd/orbi-stack.service" \
  /etc/systemd/system/orbi-stack.service
systemctl daemon-reload
systemctl enable orbi-stack.service
echo "Enabled orbi-stack.service. Run deploy.sh before starting it."
