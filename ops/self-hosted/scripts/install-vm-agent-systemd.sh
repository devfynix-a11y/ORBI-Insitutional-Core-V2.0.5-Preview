#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
unit_source="${root}/ops/self-hosted/systemd/orbi-vm-agent.service"
unit_target="/etc/systemd/system/orbi-vm-agent.service"

if [[ ! -f "${unit_source}" ]]; then
  echo "Missing ${unit_source}" >&2
  exit 1
fi

sudo install -m 0644 "${unit_source}" "${unit_target}"
sudo systemctl daemon-reload
sudo systemctl enable orbi-vm-agent.service

echo "Installed orbi-vm-agent.service."
echo "Start it after /etc/orbi/core.env is ready:"
echo "  sudo systemctl start orbi-vm-agent"
