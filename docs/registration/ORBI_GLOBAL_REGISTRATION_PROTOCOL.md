# ORBI Global Registration Protocol

This blueprint defines the single registration protocol for ORBI identities
across mobile, web, business, gateway, merchant, agent, organization, and
future third-party surfaces.

## 1. Core Principle

ORBI Core/Auth is the single identity authority.

No application outside Core/Auth may become an independent financial identity
authority. External apps may collect product-specific profile data, but Core
must create, classify, approve, activate, and govern the financial identity.

```text
External or ORBI App -> Core/Auth or Pay Gateway -> Core -> public.users
```

Financial authority always comes from Core, PostgreSQL, wallet registry,
ledger state, and approval records. It must never come from a client-declared
role or registry type alone.

## 2. Registration Families

`registry_type` is identity classification, not transaction permission.

```text
CONSUMER
Everyday ORBI user. Can use mobile wallet, P2P, PaySafe, goals, Fungu/Chama,
Mezani, receipts, reports, and notifications.

MERCHANT
Approved business seller or service receiver. Can receive merchant payments,
operate seller tools, use merchant PaySafe, settlements, and merchant reports.

AGENT
Approved ORBI wakala/service actor. Can perform allowed cash and assisted
service operations, subject to float, commission, and risk controls.

STAFF
Internal institutional/admin user. Staff must use institutional/admin nodes
and must not use consumer mobile as a consumer identity.
```

Organization membership is a membership layer, not a primary `registry_type`.
A user may be a `CONSUMER`, `MERCHANT`, or `AGENT` and also belong to an
organization with an organization role.

## 3. Registration Sources

ORBI recognizes these source families:

```text
ORBI_MOBILE
Official ORBI mobile app. Creates consumer identities.

ORBI_AUTH_WEB
Central ORBI auth surface. Creates consumer identities and can start business
access requests.

ORBI_PORTAL
Admin/core/institutional portal. Used for staff, approvals, organization
governance, and operational controls.

ORBI_PAY_GATEWAY
Trusted service boundary for external systems. Signs requests to Core using
worker identity, scopes, timestamp, nonce, body hash, and HMAC.

ORBI_SHOP
Marketplace/product service. Must not call Core directly for financial
registration authority. It submits through Pay Gateway or the central auth
surface.

AGENT_ASSISTED
Agent-assisted customer onboarding. Must capture the actor, consent, source,
and relationship metadata.

MERCHANT_ASSISTED
Merchant/service-assisted customer onboarding. Must capture the merchant or
service actor, consent, source, and relationship metadata.
```

## 4. Canonical User Requirements

Every Core financial identity must resolve to `public.users` with:

```text
id
customer_id
full_name
email or phone
currency
preferred_currency
account_status
registry_type
role
app_origin
language
metadata
created_at
```

Recommended channel fields:

```text
country_code
country_name
dial_code
fcm_token
kyc_status
kyc_level
organization_id
org_role
```

Missing `fcm_token` does not block financial correctness, but it prevents push
delivery until the mobile app syncs a fresh token.

## 5. Transaction Readiness Rules

Before preview or settlement, Core must prove:

```text
account_status = active
currency is present and normalized
source operating wallet exists and belongs to the actor
target wallet or recipient identity resolves
wallet currencies are known
registry_type and role are current in Core
request carries timestamp/timezone metadata
financial commit carries idempotency key
```

If a required financial identity field is missing, block the transaction and
repair the profile. Do not infer financial authority from legacy defaults.

## 6. Consumer Registration

Consumer signup is allowed from official ORBI Mobile and approved ORBI auth
surfaces.

Minimum payload:

```json
{
  "email": "user@example.com",
  "password": "StrongPassword@123",
  "full_name": "Customer Name",
  "phone": "+255700000000",
  "currency": "TZS",
  "preferred_currency": "TZS",
  "language": "sw",
  "country_code": "TZ",
  "country_name": "Tanzania",
  "dial_code": "+255",
  "app_origin": "ORBI_MOBILE_V2026",
  "registry_type": "CONSUMER",
  "fcm_token": "optional-device-push-token",
  "metadata": {
    "app_origin": "ORBI_MOBILE_V2026",
    "registry_type": "CONSUMER",
    "clientTimeContext": {}
  }
}
```

Normal signup must not directly create `MERCHANT`, `AGENT`, or `STAFF`
authority.

## 7. Business Access Upgrade

Business access is an approval flow, not a normal signup shortcut.

```text
CONSUMER identity exists
-> business registration request
-> service_access_requests
-> review and approval
-> users.registry_type and users.role updated
-> merchant or agent profile provisioned
-> wallets, fees, settlement, and service permissions created
```

Approved merchant provisioning must create or validate:

```text
merchants.owner_user_id
merchant_wallets.owner_user_id
merchant_wallets.merchant_id
merchant_fees.merchant_id
merchant_settlements.merchant_id
```

Approved agent provisioning must create or validate:

```text
agents.user_id
agent_wallets.owner_user_id
agent_float_controls
agent commission settings
```

## 8. External Registration Protocol

External services must not call Core public registration endpoints directly for
financial authority.

```text
External App
-> Pay Gateway
-> signed internal Core request
-> Core validates service identity and scope
-> Core creates or links identity
-> Core sends OTP/activation/challenge where required
-> Core stores audit trail
```

External apps may send identity hints:

```text
email
phone
customer reference
business name
business type
documents
consent evidence
source metadata
```

External apps must not send wallet IDs as financial authority.

## 9. Required External Source Metadata

Every external registration request should carry:

```json
{
  "registration_source": "ORBI_SHOP",
  "registration_channel": "pay_gateway",
  "source_service_code": "orbi_shop",
  "external_customer_id": "external-id",
  "created_by_actor_id": "actor-id",
  "created_by_registry_type": "MERCHANT",
  "consent_captured": true,
  "clientTimeContext": {},
  "riskContext": {}
}
```

Core may reject or quarantine external registrations that do not provide enough
source, actor, consent, or risk evidence.

## 10. Trust Boundary

Target production trust model:

```text
ORBI Mobile -> Core/Auth
ORBI Auth Web -> Core/Auth
ORBI Admin Portal -> Core/Auth
ORBI Shop -> Pay Gateway -> Core
Third Party -> Pay Gateway -> Core
```

Shop and third parties should not be direct Core trusted origins for financial
registration or payment actions.

## 11. Audit Rules

Every registration or access upgrade must produce audit evidence:

```text
who initiated it
which app/service initiated it
which user/customer was affected
which registry family was requested
which approver approved or rejected it
which wallets/service records were provisioned
which notification/challenge was sent
```

Audit timestamps remain canonical UTC. User-facing timezone metadata is stored
for display and reconciliation context.

## 12. Endpoint Matrix

These are the canonical endpoint families for registration.

Detailed headers, request payloads, idempotency keys, and method rules are in
[ORBI API Request Contracts](./ORBI_API_REQUEST_CONTRACTS.md).

### Consumer/Auth

```text
POST /v1/auth/signup
POST /v1/auth/account/confirmation/initiate
POST /v1/auth/account/confirmation/complete
POST /v1/auth/login
POST /v1/auth/refresh
GET  /v1/auth/session
GET  /v1/user/profile
```

Purpose:

```text
Create consumer identity, activate account, authenticate, refresh session, and
hydrate the canonical profile.
```

### Business Access

```text
GET  /v1/business/me
POST /v1/business/registrations
GET  /v1/service-access/requests/my
POST /v1/service-access/requests
```

Purpose:

```text
Read business identity state and request MERCHANT or AGENT access.
```

### Trusted External Registration Through Pay Gateway

```text
POST https://pay.orbifinancial.com/v1/business/registrations
```

Purpose:

```text
External trusted services submit business/customer registration requests to
Gateway. Gateway signs the internal request to Core.
```

### Core Internal Worker Routes

```text
POST /api/internal/pay-gateway/business/registrations
POST /api/internal/pay-gateway/identity-resolve
```

Required worker scopes:

```text
gateway:business-registration:write
gateway:identity:read
```

Purpose:

```text
Pay Gateway calls Core with signed HMAC, nonce, timestamp, body hash, worker
identity, and required scopes.
```

### Admin Approval

```text
GET   /v1/admin/service-access/requests
POST  /v1/admin/service-access/requests/:id/review
```

Purpose:

```text
Admin/control-room reviews business access requests and provisions approved
MERCHANT or AGENT service authority.
```

### OIDC/Auth Discovery

```text
GET https://auth.orbifinancial.com/realms/orbi/.well-known/openid-configuration
```

Purpose:

```text
OIDC discovery for official apps, future developer portal, and trusted
integrations. The public root of auth.orbifinancial.com is human-facing and is
not the OIDC issuer.
```
