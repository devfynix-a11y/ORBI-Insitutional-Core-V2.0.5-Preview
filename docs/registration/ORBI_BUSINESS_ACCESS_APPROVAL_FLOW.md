# ORBI Business Access Approval Flow

This document defines the approval flow for turning a normal ORBI identity into
a merchant or agent-capable identity.

## 1. Core Rule

Business access is an upgrade, not a signup shortcut.

```text
CONSUMER -> service_access_requests -> review -> provisioning -> MERCHANT/AGENT
```

## 2. Request Creation

Business requests may come from:

```text
ORBI Mobile
ORBI Auth Web
ORBI Admin Portal
ORBI Shop through Pay Gateway
trusted partner through Pay Gateway
```

Core stores:

```text
user_id
requested_role
requested_registry_type
current_user_role
current_user_registry_type
business_name
phone
submitted_via
metadata
status
```

## 3. Review States

```text
pending
under_review
approved
rejected
cancelled
```

Only approved requests can provision service authority.

## 4. Merchant Approval

On approval:

```text
users.role = MERCHANT
users.registry_type = MERCHANT
merchant profile is created or activated
merchant wallets are created or validated
fee and settlement configs are attached
approval audit is written
merchant notification is sent
```

Merchant financial actions must still validate active merchant records and
wallets.

## 5. Agent Approval

On approval:

```text
users.role = AGENT
users.registry_type = AGENT
agent profile is created or activated
agent wallets/float controls are created or validated
commission settings are attached
approval audit is written
agent notification is sent
```

Agent actions must validate active agent status, float, commission rules, and
risk controls.

## 6. Rejection

On rejection:

```text
request.status = rejected
review_note stored
user remains in current registry family
notification sent
audit written
```

Do not delete rejected requests. They are compliance evidence.

## 7. Duplicate Requests

If a pending or under-review request exists for the same role, Core returns the
existing request instead of creating duplicates.

If the role is already active, Core returns `ROLE_ALREADY_ACTIVE`.

## 8. Deactivation

Merchant/agent authority may be suspended without deleting the underlying user.

Preferred states:

```text
active
suspended
frozen
closed
```

Ledger and audit history remain immutable.

## 9. Endpoints

User/session endpoints:

```text
GET  /v1/business/me
POST /v1/business/registrations
GET  /v1/service-access/requests/my
POST /v1/service-access/requests
```

Admin/control-room endpoints:

```text
GET   /v1/admin/service-access/requests
POST  /v1/admin/service-access/requests/:id/review
```

Gateway-to-Core endpoint:

```text
POST /api/internal/pay-gateway/business/registrations
```

Approval implementation must call provisioning logic that creates or validates
merchant/agent service records after the request is approved.
