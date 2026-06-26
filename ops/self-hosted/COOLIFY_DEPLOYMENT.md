# Coolify Deployment

Use `ops/self-hosted/docker-compose.prod.yml` as the Compose source.

Do not enable the `direct-edge` profile in Coolify. The Nginx gateway is profile
gated so Coolify's own proxy can own ports 80/443, TLS certificates, health
routing, and rolling deployments.

## Coolify resource setup

1. Add the Ubuntu server to Coolify and validate SSH connectivity.
2. Create a Docker Compose resource from the private Git repository.
3. Set the Compose path to `ops/self-hosted/docker-compose.prod.yml`.
4. Import values from `.env.production.example` into Coolify's environment UI.
5. Mark secrets as runtime-only and never commit `.env.production`.
6. Assign `https://api.orbifinancial.com:3000` to the `core` service.
7. Assign `https://auth.orbifinancial.com:8080` to the `keycloak` service.
8. Leave PostgreSQL, Valkey, MinIO, Prometheus, Grafana, and backup services
   without public domains.
9. Keep Grafana/Prometheus accessible only through a VPN or SSH tunnel.
10. Configure persistent volumes and `/srv/orbi/backups`.
11. Enable health checks and block deployment unless Keycloak and Core become
    ready.

## Important limitations

- Coolify manages deployment; it does not replace PostgreSQL replication,
  Valkey Sentinel, off-host backups, or restore drills.
- A single Coolify host is still a single failure domain.
- The production validation gate intentionally blocks deployment while
  `ORBI_DATA_PROVIDER=local` is unfinished or while Supabase compatibility is
  selected without working credentials.
- Use a dedicated build server or registry before adding multiple runtime
  servers.

## Coolify backup

Back up Coolify itself separately from ORBI application data. Coolify settings
and its database do not contain PostgreSQL ledger backups or MinIO objects.
