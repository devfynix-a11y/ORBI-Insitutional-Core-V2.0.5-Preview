# ORBI Auth Migration Playbook

This is the first executable Supabase replacement slice. It is intended for a
clean development environment where the former Supabase project is unavailable.

## Implemented in this slice

- Private PostgreSQL and Valkey development containers.
- An ORBI-owned `auth.users` compatibility table.
- Existing financial foreign keys to `auth.users` remain valid.
- Native password hashing with bcrypt.
- ORBI-issued 15-minute access JWTs.
- Opaque 30-day refresh tokens stored only as SHA-256 hashes.
- Refresh-token rotation, family reuse detection, device binding, revocation,
  and access-token logout revocation.
- Runtime provider selection through `ORBI_AUTH_PROVIDER=local`.
- Signup, login, session verification, refresh, logout, and profile reads use
  private PostgreSQL in local-auth mode.

## Not yet replaced

- Admin/staff bootstrap and staff lifecycle.
- OTP account confirmation and password reset persistence.
- Passkeys, PIN credentials, and biometric login repositories.
- Supabase-shaped financial, wallet, PaySafe, shared-pot, and admin queries.
- Realtime subscriptions.
- Object storage for avatars, receipts, and KYC documents.
- Production asymmetric signing keys and JWKS rotation.

Do not remove the existing Supabase implementation files yet. They remain a
reference while each subsystem is replaced and tested.

## Development reset

The local database volume is the new development authority. Resetting it deletes
all local development identities and financial data.

Create a local `.env` from `.env.example` and set at minimum:

```env
JWT_SECRET=<at-least-64-random-characters>
KMS_MASTER_KEY=<at-least-64-random-characters>
ORBI_AUTH_PROVIDER=local
ORBI_DATA_PROVIDER=local
ORBI_LOCAL_AUTH_REQUIRE_CONFIRMATION=false
ORBI_POSTGRES_PASSWORD=<strong-local-password>
ORBI_VALKEY_PASSWORD=<strong-local-password>
```

The Compose stack supplies `DATABASE_URL` and `VALKEY_URL` to Core.
Use URL-safe password characters for this development Compose file because the
credentials are embedded in connection URLs.

Start the stack from the repository root:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  up --build -d
```

Inspect initialization:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  logs -f postgres core
```

Verify:

```bash
curl --fail http://127.0.0.1:3000/health
curl --fail http://127.0.0.1:3000/ready
```

Stop without deleting data:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  down
```

Development-only destructive reset:

```bash
docker compose --env-file .env \
  -f ops/self-hosted/docker-compose.dev.yml \
  -f ops/self-hosted/Auth_Security/docker-compose.yml \
  -f ops/self-hosted/Storage/docker-compose.yml \
  down --volumes
```

Never run the volume-removal command against a production project.

## Auth API smoke sequence

Create a user:

```bash
curl -X POST http://127.0.0.1:3000/v1/auth/signup \
  -H "Content-Type: application/json" \
  -H "x-orbi-app-id: mobile-android" \
  -H "x-orbi-app-origin: ORBI_MOBILE_V2026" \
  -d '{
    "email": "local.user@example.com",
    "password": "ChangeThis123!",
    "full_name": "Local User",
    "phone": "+255700000001",
    "currency": "TZS"
  }'
```

Log in and retain both returned tokens:

```bash
curl -X POST http://127.0.0.1:3000/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "x-orbi-fingerprint: local-device-1" \
  -d '{
    "email": "local.user@example.com",
    "password": "ChangeThis123!"
  }'
```

Verify the access token:

```bash
curl http://127.0.0.1:3000/v1/auth/session \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "x-orbi-app-id: mobile-android" \
  -H "x-orbi-app-origin: ORBI_MOBILE_V2026"
```

Rotate the refresh token:

```bash
curl -X POST http://127.0.0.1:3000/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -H "x-orbi-fingerprint: local-device-1" \
  -d '{"refresh_token":"<REFRESH_TOKEN>"}'
```

The old refresh token must fail after rotation. Reusing it revokes the entire
refresh family and increments the user's token version.

## Next migration slices

1. Implement local admin bootstrap and staff identity repositories.
2. Move OTP challenges and password reset into PostgreSQL and Valkey.
3. Move passkey and PIN repositories.
4. Introduce a PostgreSQL repository layer compatible with current financial
   services.
5. Migrate wallet and ledger reads, then atomic financial RPCs.
6. Migrate PaySafe, shared pots, budgets, and admin operations.
7. Add local object storage and realtime event delivery.
8. Replace HS256 with offline-generated asymmetric signing keys and JWKS before
   internet production.

Every money-domain slice must include idempotency tests, rollback behavior,
ledger reconciliation, and repeated-request tests before it becomes authoritative.

## Supabase deletion gate

The Supabase package and client files must remain until all of these searches
return no runtime matches:

```bash
rg "getSupabase|getAdminSupabase|createAuthenticatedClient" \
  backend iam ledger services src strategy wealth
rg "@supabase/supabase-js" package.json package-lock.json \
  backend services
```

Deletion is allowed only after local replacements cover:

- all financial PostgREST table reads and writes;
- every ledger and settlement RPC;
- OTP, passkey, PIN, device, and staff identity repositories;
- object storage;
- realtime and socket fan-out;
- audit, KMS, queue, and operational-health persistence;
- read/write database integration tests against private PostgreSQL.

At the start of this migration, 115 tracked files still referenced the
Supabase client or configuration contract. Removing the package before that
count reaches zero would disable financial operations rather than migrate them.
