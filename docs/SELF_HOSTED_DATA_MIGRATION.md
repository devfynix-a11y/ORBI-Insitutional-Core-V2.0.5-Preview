# Self-Hosted Core and Data Migration

ORBI Core is moving to a dedicated, organization-managed VM with a static
public IP. Only the HTTPS API reverse proxy should be internet-accessible.
PostgreSQL, Redis, backup storage, administration ports, and internal service
ports must remain on private interfaces.

Firebase remains supported for mobile push notifications. The current
Supabase client is also retained temporarily as a compatibility layer; removing
its credentials before the database, authentication, realtime, and storage
adapters are migrated would interrupt customer access.

`ORBI_AUTH_PROVIDER=local` moves authentication only. It does not imply that
wallet, ledger, PaySafe, shared-pot, storage, or realtime repositories are
local. Track that separately with `ORBI_DATA_PROVIDER`; production must remain
blocked from local-data mode until the financial repository migration and
database integration suite are complete.

## Deployment boundary

- Publish `api.orbifinancial.com` to the VM static IP.
- Expose TCP 443 publicly. Redirect TCP 80 to 443 if certificate automation
  requires it.
- Restrict SSH to a VPN or a fixed administration allowlist.
- Bind the Node service, PostgreSQL, and Redis to private or loopback
  interfaces.
- Terminate TLS at a maintained reverse proxy and forward trusted proxy
  headers to Core.
- Keep secrets in a root-owned environment file or secret manager, never in
  Git.

## Backup-first migration

1. Take a complete source backup before any schema or traffic cutover.
2. Provision private PostgreSQL with encrypted storage and separate backup
   credentials.
3. Restore the backup into an isolated database and verify row counts,
   constraints, ledger totals, wallet balances, and audit-chain integrity.
4. Add local adapters for database access, authentication, realtime events,
   and object storage while the existing Supabase adapters remain available.
5. Run dual-read comparison and controlled dual-write reconciliation before
   selecting a cutover window.
6. Pause mutations, apply the final change stream, reconcile again, then move
   the API to the private database.
7. Keep the old database read-only during the rollback window. Remove it only
   after signed reconciliation and successful restore drills.

## Backup policy

- Use encrypted daily full backups plus continuous WAL archiving for
  point-in-time recovery.
- Keep at least one encrypted copy outside the primary VM, under ORBI-controlled
  keys and an approved data-residency location.
- Use separate credentials for backup creation and restore operations.
- Define retention by legal and financial-record requirements; do not rely on
  an indefinite single snapshot.
- Perform scheduled restore drills and record recovery point and recovery time
  results.
- Never expose PostgreSQL or raw backup downloads as public APIs. If remote
  backup operations are needed, expose authenticated job triggers and status
  only through the administration API.

## Cutover gate

Production cutover is blocked until automated reconciliation passes, a backup
has been restored successfully, rollback has been rehearsed, and both outgoing
and incoming financial transactions have completed in the isolated environment.
