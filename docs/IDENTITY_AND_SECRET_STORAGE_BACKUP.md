# ORBI Identity And Secret Storage Backup

This document defines the official storage and backup rules for login
identities, password hashes, developer API keys, webhook secrets, and restore
evidence.

## Authority

ORBI must not store raw passwords, OTPs, PINs, challenge answers, API keys, or
webhook secrets in application tables, logs, JSON files, or backups.

Official authority:

| Data | Official storage | Stored value | Backup requirement |
| --- | --- | --- | --- |
| User login identity | Keycloak/Auth PostgreSQL database | Identity rows and password hashes | Encrypted database dump plus restore drill |
| Core financial profile | ORBI Core PostgreSQL database | Users, wallets, ledgers, audit chain | Encrypted database dump plus reconciliation |
| Developer API key | Pay Gateway control-plane PostgreSQL tables | Key fingerprint/hash only | Encrypted database dump |
| Developer webhook secret | Pay Gateway control-plane PostgreSQL tables | Fingerprint plus encrypted signing secret | Encrypted database dump plus encryption-key custody |
| One-time issued secret | Not stored | Display once to authorized operator/developer | Developer must store in their own secret manager |

## Password Rule

Passwords are never backed up as readable secrets. The auth database stores only
password hash material produced by the auth provider. Restoring the auth
database restores login capability because the password hash, salt, credential
metadata, user identity, and realm/client relationships are restored together.

If an encrypted backup is lost or cannot be restored, users must reset their
passwords through the official password reset flow. Operators must never repair
accounts by inserting raw passwords.

## Developer Secret Rule

Developer API keys and webhook secrets are issued once:

```text
issue request -> generate random secret -> store fingerprint/hash -> encrypt recoverable signing secret where runtime must sign -> return raw secret once
```

Runtime request validation:

```text
incoming secret -> hash/fingerprint -> compare active non-expired key
```

The database stores:

- `environment`: `sandbox` or `live`
- `service_code`
- `key_id` or `secret_id`
- `fingerprint`
- `status`
- `issued_at`, `expires_at`, `revoked_at`
- audit actor and reason

API keys must not be stored as recoverable secrets; a fingerprint is enough for
request authentication. Webhook signing secrets are different because ORBI must
sign outbound webhooks after restart. They are stored only as encrypted vault
material using `ORBI_SECRET_ENCRYPTION_KEY`; plaintext webhook secrets must never
be stored in tables, files, logs, or backups.

## Backup Set

The official self-hosted backup set must include at minimum:

- `orbi` database
- `keycloak` database
- Pay Gateway control-plane tables, if stored inside `orbi`
- encrypted object-storage metadata backups where applicable
- signed restore manifests and SHA-256 checksums

The backup worker supports:

```env
ORBI_BACKUP_DATABASES=orbi,keycloak
ORBI_BACKUP_ENCRYPTION_KEY=<strong offline-controlled key>
ORBI_SECRET_ENCRYPTION_KEY=<strong server secret-vault key>
ORBI_BACKUP_RETENTION_DAYS=14
```

Backups are encrypted before being mirrored outside the primary host. Raw
database dumps must never be copied to public storage.

## Restore Drill

Every production restore drill must prove:

1. Keycloak/Auth users can log in after restore.
2. Password hashes work without exposing raw passwords.
3. Core `public.users` links still match auth identities.
4. Wallet balances reconcile to ledger totals.
5. PaySafe, P2P, Shared Pot, and Shared Budget histories reconcile.
6. Developer API key fingerprints resolve correctly.
7. Webhook signatures can be generated from restored encrypted webhook-secret vault material.
8. Audit chain integrity is verified after restore.

## Production Gate

Real-money live traffic must not run unless encrypted backups and restore
evidence exist for both identity and financial databases.
