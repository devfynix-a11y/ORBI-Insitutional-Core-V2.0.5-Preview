#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash ops/self-hosted/scripts/provision-ubuntu.sh" >&2
  exit 1
fi

source /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" ]]; then
  echo "Supported hosts: Ubuntu LTS or Debian." >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl git gnupg jq openssl rsync ufw fail2ban unattended-upgrades

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${ID}/gpg" \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

arch="$(dpkg --print-architecture)"
codename="${VERSION_CODENAME}"
cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${codename} stable
EOF

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
systemctl enable --now fail2ban

if ! id orbi >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash orbi
fi
usermod -aG docker orbi

install -d -o orbi -g orbi -m 0750 /srv/orbi
install -d -o orbi -g orbi -m 0750 \
  /srv/orbi/app \
  /srv/orbi/backups/database
install -d -o root -g orbi -m 0750 /srv/orbi/secrets /srv/orbi/secrets/tls

ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 443/tcp
if [[ -n "${ADMIN_VPN_CIDR:-}" ]]; then
  ufw allow from "${ADMIN_VPN_CIDR}" to any port 22 proto tcp
else
  echo "ADMIN_VPN_CIDR is unset. SSH firewall rule was not added."
  echo "Add a trusted SSH source before enabling UFW."
fi

cat <<'EOF'
Ubuntu provisioning completed.

Next:
1. Clone the repository into /srv/orbi/app as user "orbi".
2. Run generate-secrets.sh.
3. Install TLS files under /srv/orbi/secrets/tls.
4. Run validate-deployment.sh.
5. Enable UFW only after confirming SSH access: sudo ufw enable
EOF
