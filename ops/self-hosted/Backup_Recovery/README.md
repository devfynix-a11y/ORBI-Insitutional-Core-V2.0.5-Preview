# Backup and Recovery

The backup service creates PostgreSQL custom-format dumps, encrypts them with
OpenSSL AES-256-CBC/PBKDF2, writes checksums and manifests, and stores the
encrypted artifacts on the live host disk. A separate R2 replicator mirrors only
the encrypted artifacts to Cloudflare R2.

Live host copy:

```txt
/srv/orbi/backups/database
```

Off-machine copy:

```txt
r2://<ORBI_BACKUP_R2_BUCKET>/<ORBI_BACKUP_R2_PREFIX>/
```

Required secrets:

- `ORBI_BACKUP_ENCRYPTION_KEY`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_ACCESS_KEY_ID`
- `CLOUDFLARE_SECRET_ACCESS_KEY`
- `ORBI_BACKUP_R2_BUCKET`

The backup process intentionally does not copy raw PostgreSQL data-directory
files while the database is running. Use database-consistent dumps for this
baseline, then add WAL archiving and point-in-time recovery before full
production traffic.

Production still requires:

- a restore drill on an isolated machine;
- ledger, wallet, settlement, and audit reconciliation after restore;
- immutable or versioned off-machine retention;
- separate backup credentials with the smallest possible R2 permissions;
- documented recovery-point and recovery-time evidence.

Never treat a successful backup command as proof of recoverability without
restoring it.
