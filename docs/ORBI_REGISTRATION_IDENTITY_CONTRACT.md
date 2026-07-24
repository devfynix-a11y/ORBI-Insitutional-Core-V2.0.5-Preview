# ORBI Registration Identity Contract

This contract defines the minimum identity data ORBI requires before an
account can safely participate in financial flows.

## 1. Canonical Identity Source

ORBI Core/Auth is the single registration authority. Other products, including
ORBI Mobile, ORBI Shop, ORBI Pay Gateway, and future business portals, must
create or upgrade identities through Core-controlled flows.

Applications may collect their own product profile data, but they must not
become independent financial identity authorities.

## 2. Required Consumer Signup Payload

Consumer registration must send these fields explicitly:

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

`email` or `phone` is required, but mobile should send both when available.
`currency` is mandatory because transfers are blocked when the sender profile
has no assigned account currency.

## 3. Public Users Table Requirements

`public.users` must contain these financial identity fields:

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
```

Recommended but channel-dependent fields:

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

Missing `fcm_token` must not block financial correctness, but it prevents push
delivery until the mobile app syncs a fresh token.

## 4. Registration Families And Access Levels

`registry_type` is identity classification, not transaction authority.

Supported families:

```text
CONSUMER: everyday ORBI account.
MERCHANT: approved business seller/service receiver.
AGENT: approved ORBI wakala/service actor.
STAFF: internal institutional staff/admin.
```

Access rules:

```text
CONSUMER -> mobile consumer services, P2P, PaySafe, goals, pots, budgets.
MERCHANT -> consumer services plus approved merchant services.
AGENT -> consumer services plus approved agent services.
STAFF -> institutional/admin node only; blocked from consumer mobile node.
```

Business access is not created by normal signup. It is requested through:

```text
POST /v1/business/registrations
```

Trusted external systems submit through Pay Gateway:

```text
POST /v1/business/registrations
```

Pay Gateway signs and forwards internally to Core. Core creates
`service_access_requests`; admin approval provisions merchant or agent records.

## 5. Transaction Readiness Requirements

Before financial preview or settlement, Core must be able to prove:

```text
account_status = active
currency is present and normalized
source operating wallet exists and belongs to the actor
target wallet or recipient identity resolves
wallet currencies are known
registry_type and role are current in Core, not trusted from client text alone
request carries timestamp/timezone metadata
financial commit carries idempotency key
```

The client may send helpful context, but Core resolves final authority from
PostgreSQL and the wallet/ledger registry.

## 6. Do Not Use Defaults As Financial Authority

Database defaults exist only for legacy compatibility and schema safety. New
clients must send explicit `currency`, `app_origin`, and `registry_type`.

If a profile is missing required financial fields, the correct behavior is to
block the transaction and repair the profile, not to infer financial authority
from fallback values.
