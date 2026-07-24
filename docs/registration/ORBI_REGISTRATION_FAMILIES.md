# ORBI Registration Families

This document defines ORBI identity families and the access boundaries attached
to each family.

## 1. Family Rule

`registry_type` classifies an identity. It does not grant financial authority
by itself.

Every financial action must still verify:

```text
account_status
role
service approval
wallet ownership
wallet status
ledger state
risk decision
idempotency
```

## 2. CONSUMER

Default everyday ORBI user.

Allowed surfaces:

```text
ORBI Mobile
ORBI Auth Web
consumer support flows
```

Allowed services:

```text
operating wallet
P2P send/receive
PaySafe personal escrow
goals
Fungu/Chama
Mezani
transaction history
receipts
notifications
```

Business services are not available until an approval flow upgrades access.

## 3. MERCHANT

Approved business identity.

Created only through:

```text
CONSUMER -> service_access_requests -> approval -> MERCHANT
```

Required records:

```text
users.registry_type = MERCHANT
users.role = MERCHANT
merchants.owner_user_id
merchant_wallets
merchant_fees
merchant_settlements
```

Allowed services:

```text
consumer services
merchant checkout receiving
merchant PaySafe holds
settlement reports
merchant payment history
seller/business integrations
```

Merchant payment authority must be resolved from `merchants` and
`merchant_wallets`, not from `users.registry_type` alone.

## 4. AGENT

Approved ORBI wakala/service actor.

Created only through:

```text
CONSUMER -> service_access_requests -> approval -> AGENT
```

Required records:

```text
users.registry_type = AGENT
users.role = AGENT
agents.user_id
agent_wallets
agent_float_controls
commission configuration
```

Allowed services:

```text
consumer services
agent cash-in/cash-out
assisted customer registration
float operations
commission reporting
```

Agent authority must be checked against active agent status, float rules, risk,
and operation class.

## 5. STAFF

Internal institutional identity.

Allowed surfaces:

```text
admin portal
institutional portal
control-room tools
ops APIs
```

Disallowed:

```text
consumer mobile node
normal public signup
external service self-registration
```

Staff identities require bootstrap or admin-controlled creation.

## 6. Organization Membership

Organization membership is not a primary registry family.

A user may have:

```text
registry_type = CONSUMER | MERCHANT | AGENT
organization_id
org_role
organization_members.role
```

Organization services must validate both user identity and organization
membership before allowing actions.

## 7. Invalid Family Changes

These changes are not allowed directly:

```text
client payload -> MERCHANT
client payload -> AGENT
client payload -> STAFF
external app -> direct Core role upgrade
```

Use service access requests and approval provisioning instead.
