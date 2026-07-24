# ORBI Keycloak Authentication Playbook

Keycloak is ORBI's self-hosted identity provider. It replaces Supabase Auth
without making the identity provider authoritative over wallets, KYC, account
status, or financial permissions.

## Responsibility boundary

Keycloak owns:

- passwords and credential policy;
- OAuth 2.0 and OpenID Connect;
- RS256 access tokens and JWKS rotation;
- refresh tokens and identity sessions;
- brute-force protection;
- browser login, future TOTP, WebAuthn, and passkeys;
- identity-provider audit events.

ORBI Core owns:

- the immutable ORBI user UUID;
- Keycloak-subject-to-ORBI-user mapping;
- account and KYC status;
- consumer, merchant, agent, and staff classification;
- financial permissions and transaction policy;
- devices, PINs, risk checks, OTP step-up, and transaction confirmation;
- wallet, ledger, settlement, PaySafe, pot, and budget authorization.

Keycloak tokens never directly grant financial authority. Core verifies the
token and then loads the current ORBI profile from PostgreSQL.

## Local Windows startup

Install Docker Desktop with WSL2, then run from the Core repository:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/start-windows.ps1
```

The script creates a development `.env` only when one does not exist, then
starts PostgreSQL, Keycloak, Valkey, MinIO, and Core.

Local endpoints:

- Core: `http://localhost:3000`
- Keycloak: `http://localhost:8081`
- Realm: `http://localhost:8081/realms/orbi`
- OIDC discovery:
  `http://localhost:8081/realms/orbi/.well-known/openid-configuration`

Stop without deleting volumes:

```powershell
powershell -ExecutionPolicy Bypass -File ops/self-hosted/scripts/stop-windows.ps1
```

Never use `docker compose down --volumes` against data that must be retained.

## Identity linking

`orbi_auth.identity_links` maps:

```text
Keycloak provider subject -> ORBI auth.users.id
```

All financial foreign keys continue using the ORBI UUID. A verified Keycloak
email may be linked automatically only when exactly one matching ORBI identity
exists. Ambiguous or unverified identities fail closed.

## Mobile migration

The current `/auth/login`, `/auth/refresh`, `/auth/logout`, and `/auth/signup`
contracts remain available while the mobile UI migrates. In Keycloak mode,
these routes delegate credentials and sessions to Keycloak.

This compatibility path temporarily requires Direct Access Grants on the
`orbi-mobile` client. It must be removed after native PKCE is enabled.

The mobile app includes `KeycloakPkceAuthService`. Enable it in a test build:

```bash
flutter run \
  --dart-define=API_BASE_URL_PROD=http://10.0.2.2:3000 \
  --dart-define=KEYCLOAK_PKCE_ENABLED=true \
  --dart-define=KEYCLOAK_ISSUER=http://10.0.2.2:8081/realms/orbi \
  --dart-define=KEYCLOAK_MOBILE_CLIENT_ID=orbi-mobile \
  --dart-define=KEYCLOAK_REDIRECT_URL=com.orbi.mobile:/oauth2redirect
```

Use the host LAN address instead of `10.0.2.2` for a physical Android device.
The identity endpoint must be reachable by that device. For emulator or LAN
testing, update the Core `.env` before starting containers:

```env
ORBI_DEV_BIND_ADDRESS=0.0.0.0
ORBI_KEYCLOAK_PUBLIC_URL=http://<EMULATOR_OR_LAN_HOST>:8081
ORBI_KEYCLOAK_ISSUER=http://<EMULATOR_OR_LAN_HOST>:8081/realms/orbi
```

Use `10.0.2.2` for the Android emulator and the Windows LAN address for a
physical device. Permit ports 3000 and 8081 only on the trusted private
development network, never on a public network.

After signed Android and iOS builds complete PKCE login, refresh, logout,
reinstall, background-resume, and deep-link tests:

1. retain the ORBI `/auth/session` profile exchange;
2. disable `directAccessGrantsEnabled` for `orbi-mobile`;
3. reject password grant requests at the Core compatibility endpoint;
4. remove password fields from the mobile-to-Core login path.

When `KEYCLOAK_PKCE_ENABLED=true`, `AuthRepository.login` already selects the
native PKCE service instead of posting the password to Core.

## Production routing

Production uses:

```text
https://auth.orbifinancial.com/realms/orbi
```

The human-facing root is intentionally branded:

```text
https://auth.orbifinancial.com/
```

It serves a small ORBI Auth landing page from the edge gateway. Do not use the
root URL as the OIDC issuer. Apps and services must continue using
`https://auth.orbifinancial.com/realms/orbi` for discovery, token validation,
and PKCE/OIDC flows.

Developer/OIDC discovery endpoint:

```text
https://auth.orbifinancial.com/realms/orbi/.well-known/openid-configuration
```

This endpoint is for apps, backend services, and the future developer portal.
It should not be presented as a normal customer action on the public Auth
landing page.

## ORBI Business hosted account-link client

External merchant portals must use ORBI-hosted login/signup for ORBI Pay
payment profile linking. The reference ORBI Shop client is:

```text
Realm: orbi
Client ID: orbi-shop-business
Client type: confidential
Issuer: https://auth.orbifinancial.com/realms/orbi
Discovery: https://auth.orbifinancial.com/realms/orbi/.well-known/openid-configuration
Redirect URI: https://shop.orbifinancial.com/api/auth/orbi-business/link/callback
Web origin: https://shop.orbifinancial.com
```

The client secret must live only in the merchant application's server-side
secret store, for example:

```env
ORBI_BUSINESS_AUTH_CLIENT_SECRET=<secret-from-keycloak>
```

Do not expose this secret through Vite, browser JavaScript, mobile apps,
checkout pages, logs, or Git. The hosted account-link flow exchanges the OIDC
code server-to-server, creates or links a Pay Gateway payment profile, then
returns only sanitized references such as `paymentProfileId` and masked ORBI
customer hints to the merchant UI.

DNS for `auth.orbifinancial.com` must point to the ORBI edge. The TLS
certificate mounted into Nginx must cover both:

- `api.orbifinancial.com`
- `auth.orbifinancial.com`

PostgreSQL, Keycloak's internal HTTP port, Valkey, and Keycloak management
health endpoints remain private.

## Session policy

- Access token lifetime: 5 minutes.
- Refresh-token rotation: enabled with zero reuse.
- SSO idle timeout: 30 minutes.
- Maximum SSO session: 8 hours.
- Offline session idle timeout: 30 days.
- Core records logged-out access-token JTIs until their expiry.
- Password reset revokes all Keycloak sessions for the identity.
- Frozen or blocked ORBI accounts are rejected even when a Keycloak token is
  cryptographically valid.

For withdrawals, PaySafe release, refunds, reversals, disputes, beneficiary
changes, and security-setting changes, require recent step-up verification in
Core. A valid login token alone is insufficient.

## Production checks

- OIDC discovery and JWKS are reachable through HTTPS.
- Tokens use RS256 and contain audience `orbi-core`.
- Core rejects incorrect issuer, audience, signature, expiry, and revoked JTI.
- Duplicate or missing identity links fail closed.
- Refresh-token reuse is rejected.
- Logout prevents refresh and Core rejects the recorded access token.
- Password reset revokes existing sessions.
- Blocked/frozen ORBI profiles cannot use valid Keycloak sessions.
- Keycloak and ORBI databases are included in backup and restore drills.
- Direct Access Grants are disabled after mobile PKCE cutover.
