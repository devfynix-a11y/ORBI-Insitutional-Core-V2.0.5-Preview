# Oracle Cloud Deployment With GitHub Actions

This guide replaces the Render deployment path with an Oracle Cloud Compute VM
that receives releases from GitHub Actions.

## Target Topology

- Oracle Cloud Compute instance running Ubuntu or Oracle Linux
- Docker Engine with the Docker Compose plugin installed
- Nginx, Apache, or OCI Load Balancer terminating public TLS in front of the app
- ORBI Node container listening on internal port `3000`
- GitHub Actions building an image in GitHub Container Registry and deploying it
  over SSH

## Files Added For This Flow

- `Dockerfile`
- `.dockerignore`
- `.github/workflows/deploy-oracle.yml`
- `ops/oracle/docker-compose.oracle.yml`
- `ops/oracle/deploy-vm.sh`

## GitHub Secrets

Create these repository secrets before enabling the workflow:

- `OCI_SSH_HOST`: public IP or DNS of the Oracle VM
- `OCI_SSH_PORT`: usually `22`
- `OCI_SSH_USER`: deployment user on the VM
- `OCI_SSH_PRIVATE_KEY`: the private key contents used to SSH into the VM
- `OCI_APP_ENV_FILE_B64`: base64-encoded production `.env` file contents
- `ORBI_BASE_URL`: public HTTPS base URL for smoke tests
- `ORBI_MONITOR_API_KEY`: monitor token used by `scripts/release-smoke.mjs`

## Encode The Production Env File

PowerShell:

```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content 'C:\path\to\production.env' -Raw)))
```

Store the output as `OCI_APP_ENV_FILE_B64`.

## Prepare The Oracle VM

1. Install Docker Engine and the Docker Compose plugin.
2. Ensure the deployment user can run Docker.
3. Create the target directory:

```bash
sudo mkdir -p /opt/orbi/orbi-institutional-core
sudo chown -R $USER:$USER /opt/orbi/orbi-institutional-core
```

4. Open the required firewall ports:
   - `22` for SSH
   - `80` and `443` for public traffic
   - keep `3000` private unless you intentionally expose Node directly
5. Put a reverse proxy or OCI Load Balancer in front of the app and keep:
   - `ORBI_ENFORCE_HTTPS=true`
   - `ORBI_TLS_ENABLED=false`
   - `ORBI_INTERNAL_MTLS_SOURCE=proxy`

## Domain And TLS

Use a real API domain in production instead of the raw VM IP.

1. Create an `A` record such as `api.orbi.example.com` pointing to the Oracle
   VM public IP or OCI Load Balancer IP.
2. Configure the reverse proxy to forward traffic to `127.0.0.1:3000`.
3. Terminate public TLS at Nginx, Apache, or OCI Load Balancer.
4. Update the production `.env` before base64 encoding it:
   - `BACKEND_URL=https://api.orbi.example.com`
   - `ORBI_BASE_URL=https://api.orbi.example.com`
   - `ORBI_ALLOWED_ORIGINS=https://api.orbi.example.com`
   - `ORBI_WEB_ORIGIN=https://api.orbi.example.com`
   - `ORIGIN=https://api.orbi.example.com`
   - `VITE_API_BASE_URL=https://api.orbi.example.com`
   - `RP_ID=api.orbi.example.com`
5. Set the GitHub secret `ORBI_BASE_URL` to the same HTTPS domain for smoke
   tests.

For direct Nginx TLS on Ubuntu, the common path is:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.orbi.example.com
```

## First Deployment

1. Push this repository to GitHub.
2. Add the secrets above.
3. Run the `Deploy Oracle Cloud` workflow manually or push to `main`.
4. Confirm:
   - `https://api.orbi.example.com/health`
   - `https://api.orbi.example.com/api/admin/monitor/operational-health`

## How The Workflow Works

1. Runs `npm ci`, `npm run lint`, `npm test`, and `npm run build`
2. Builds a Docker image
3. Pushes the image to `ghcr.io`
4. Copies the Oracle deployment bundle to the VM over SSH
5. Writes the production `.env` file on the VM from GitHub Secrets
6. Pulls the new image and restarts the container with Docker Compose
7. Runs the existing smoke test against the deployed base URL

## Oracle Notes

- If you move to an OCI Load Balancer later, this workflow still works unchanged.
- If you prefer direct TLS on Node instead of a proxy, set:
  - `ORBI_TLS_ENABLED=true`
  - `ORBI_TLS_CERT_PATH`
  - `ORBI_TLS_KEY_PATH`
  - `ORBI_INTERNAL_MTLS_SOURCE=direct`
- Keep production secrets only in GitHub Secrets or OCI Vault, not in the repo.
