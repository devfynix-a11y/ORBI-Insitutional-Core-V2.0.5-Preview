# ORBI Self-Hosted Platform Architecture

## Architecture principles

- Financial correctness is more important than availability shortcuts.
- PostgreSQL is the authoritative identity and financial data store.
- Valkey is ephemeral coordination infrastructure, never the ledger.
- Only the edge gateway is directly internet-accessible.
- Every internal service uses least privilege and a private network.
- Storage objects are private by default and accessed with short-lived signed
  URLs.
- Backups are not considered valid until successfully restored and reconciled.
- Application hosting, data authority, authentication, and object storage are
  migrated independently behind explicit provider boundaries.

## Container topology

```txt
Internet
   |
   v
ORBI Gateway (80/443)
   |
   | orbi-edge
   v
ORBI Core API
   |---------------------- orbi-ops --------------------> Prometheus/Grafana
   |
   | orbi-private
   +--> PostgreSQL
   +--> Valkey
   +--> Object Storage
   +--> Backup/Recovery jobs
```

The current modules are:

| Module | Responsibility | Public ports |
| --- | --- | --- |
| `Gateway` | TLS, request limits, WebSocket proxy, edge logs | 80, 443 |
| Core compose | API, authorization, financial orchestration | loopback 3000 in development |
| `Auth_Security` | PostgreSQL identity/financial schema and Valkey | none |
| `Storage` | private S3-compatible object storage | none |
| `Observability` | protected metrics and operator dashboards | loopback only |
| `Backup_Recovery` | checksummed logical database backups | none |

## Trust zones

### Public edge

Nginx accepts internet traffic and forwards only to Core. It must not have
database, Valkey, storage, or backup credentials.

### Application zone

Core connects to the edge, operations, and private networks. It owns request
authentication, authorization, idempotency, policy enforcement, and financial
workflow orchestration.

### Data zone

PostgreSQL, Valkey, MinIO, and backup jobs share `orbi-private`. No service in
this zone publishes a host port.

### Operations zone

Prometheus accesses only Core's protected metrics endpoint. Grafana accesses
Prometheus. Both operator ports bind to loopback and require VPN or SSH
tunnelling for remote access.

## Data authority

PostgreSQL owns:

- identity UUIDs and credentials;
- refresh-session hashes and access-token revocations;
- wallets, balances, ledger entries, transaction state, PaySafe, shared pots,
  shared budgets, audit evidence, and reconciliation;
- configuration requiring transactionality or durable history.

Valkey owns only bounded, recoverable coordination state:

- rate limits and brute-force counters;
- OTP and short-lived challenge state;
- idempotency caches backed by durable database guarantees;
- distributed locks and worker queues;
- replay windows and transient operational signals.

Valkey uses `noeviction`. If memory is exhausted, writes fail visibly instead
of silently evicting security or idempotency state. Capacity alerts must fire
before the configured memory ceiling is reached.

Object storage owns binary content:

- KYC documents;
- avatars and receipts;
- generated reports and controlled exports;
- encrypted backup objects after the backup uploader is implemented.

The database stores object identifiers and metadata, not public permanent URLs.

## Authentication architecture

The first local implementation runs identity logic inside Core and stores
credentials in PostgreSQL. Access JWTs are short-lived and refresh tokens are
opaque, hashed, rotated, device-bound, and family-revoked on reuse.

Before internet production:

1. Replace symmetric JWT signing with an offline-generated asymmetric key.
2. Store the private signing key outside Git and images.
3. Publish current and previous public keys through JWKS.
4. Add key identifiers and rehearsed rotation.
5. Move OTP, passkeys, PINs, staff bootstrap, and password reset fully to local
   repositories.
6. Extract identity into a separate internal service only after Core has a
   stable internal auth client and mTLS.

## Valkey evolution

Development begins with one persistent Valkey node using AOF and RDB snapshots.
The ioredis package remains a wire-protocol client; deployment configuration
uses `VALKEY_*`.

Production availability phases:

1. Single Valkey node with monitored persistence and tested restart recovery.
2. One primary, replicas, and three Sentinel voters on independent failure
   domains.
3. Valkey Cluster only when measured capacity or shard isolation requires it.

Sentinel and Cluster improve availability but do not make Valkey a financial
source of truth. Core must fail closed for security and idempotency operations
when required Valkey state is unavailable.

## PostgreSQL evolution

Development starts with a single PostgreSQL 16 container. Production requires:

- dedicated encrypted storage;
- a non-superuser application role;
- a separate migration role;
- a separate backup role;
- WAL archiving and point-in-time recovery;
- streaming replica on a separate host or failure domain;
- connection pooling;
- statement, lock, and idle transaction timeouts;
- slow-query and deadlock monitoring;
- regular restore and financial reconciliation drills.

Schema changes must be forward-compatible with the running API during rolling
deployment. Destructive migrations require a separate reviewed release.

## Storage evolution

MinIO is private and initializes separate asset, KYC, and backup buckets.
Before it becomes authoritative:

- add an application S3 adapter;
- use service-specific credentials instead of root credentials;
- enable server-side encryption with ORBI-controlled keys;
- implement signed URL expiry and authorization;
- add malware scanning and file-type validation;
- define retention, legal hold, and deletion policies;
- replicate critical objects to a separate ORBI-controlled location.

## Backup and recovery

The initial backup job produces checksummed PostgreSQL custom dumps. Production
requires WAL/PITR and an encrypted off-host copy. Backup credentials must not
permit application writes.

Recovery acceptance requires:

- successful database restore;
- KMS key recovery;
- critical RPC validation;
- identity login/session validation;
- ledger totals and wallet balance reconciliation;
- PaySafe and settlement lifecycle inspection;
- signed drill evidence with measured RPO and RTO.

## Observability

Prometheus scrapes the protected Core endpoint using a file-mounted monitor
key. Grafana is loopback-only and anonymous access is disabled.

Required alerts include:

- API readiness and elevated latency/error rate;
- PostgreSQL connection saturation, replication lag, WAL/archive failure,
  deadlocks, and disk pressure;
- Valkey memory pressure, rejected writes, persistence failure, and queue lag;
- storage capacity and failed object operations;
- settlement backlog and held/reversal anomalies;
- reconciliation drift and unbalanced ledger attempts;
- failed backups, expired restore evidence, and certificate expiry.

Alertmanager or another approved delivery mechanism remains a required
production module.

## Deployment and rollback

- Build immutable images from an approved commit SHA.
- Run type checks, tests, image scanning, and release smoke checks.
- Apply additive database migrations before application traffic switches.
- Use blue/green Core containers behind the gateway.
- Switch traffic only after health, readiness, authentication, and isolated
  financial smoke checks pass.
- Retain the previous image and compatible schema during the rollback window.
- Never roll back financial state by deleting transactions; use explicit,
  audited reversals.

## Production readiness gates

The architecture is not production-ready until:

- all Supabase runtime references have local adapters;
- local database read/write integration tests pass;
- private storage authorization is implemented;
- asymmetric JWT/JWKS rotation is complete;
- PostgreSQL WAL/PITR and off-host encrypted backups are operational;
- Valkey recovery and fail-closed behavior are tested;
- dedicated worker execution is separated from API processes;
- Alertmanager and host-level monitoring are operational;
- restore, rollback, and reconciliation drills have signed evidence.
