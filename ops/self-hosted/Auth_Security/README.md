# Auth and Security Containers

This module owns the private PostgreSQL, Keycloak, and Valkey containers.

- PostgreSQL stores the ORBI schema in `orbi` and Keycloak's internal schema in
  the separate `keycloak` database.
- Keycloak owns credentials, OAuth 2.0/OIDC, JWT signing, refresh tokens,
  identity sessions, password policy, brute-force controls, and future MFA.
- `orbi_auth.identity_links` maps Keycloak subjects to immutable ORBI user IDs,
  preserving wallet, ledger, KYC, and device foreign keys.
- Valkey provides OTP state, brute-force controls, replay protection, queues,
  locks, and session-related caches.
- Production does not publish PostgreSQL or Valkey. Development publishes
  Keycloak only on loopback port `8081`.
- Core validates RS256 access tokens through Keycloak JWKS and then loads
  financial authorization state from ORBI PostgreSQL.

The SQL initialization mounts are resolved relative to the root compose file.
Start this module using the commands in the parent self-hosted README rather
than running this compose file by itself.
