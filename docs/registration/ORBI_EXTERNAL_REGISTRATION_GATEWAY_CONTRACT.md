# ORBI External Registration Gateway Contract

This document defines how external ORBI services and third parties submit
registration requests without becoming Core financial identity authorities.

## 1. Boundary

External applications do not call Core public registration endpoints for
financial authority.

```text
External Service -> ORBI Pay Gateway -> signed internal Core route -> Core/Auth
```

Pay Gateway authenticates the service. Core authenticates the worker request
and makes the final identity decision.

## 2. Service Authentication

Every external registration request must use an approved service credential at
Pay Gateway.

The Gateway-to-Core request must include:

```text
x-worker-id
x-worker-scopes
x-worker-timestamp
x-worker-nonce
x-worker-body-sha256
x-worker-signature
```

Required Core scope:

```text
gateway:business-registration:write
```

## 3. External Request Types

Supported external registration intents:

```text
consumer_invite
merchant_application
agent_application
service_customer_registration
organization_member_invite
```

Each intent must map to a Core-controlled outcome.

## 4. Required Payload

```json
{
  "email": "user@example.com",
  "phone": "+255700000000",
  "fullName": "Customer Name",
  "requestedRole": "MERCHANT",
  "businessName": "Example Store",
  "externalBusinessId": "shop-seller-123",
  "metadata": {
    "registration_source": "ORBI_SHOP",
    "registration_channel": "pay_gateway",
    "source_service_code": "orbi_shop",
    "consent_captured": true,
    "clientTimeContext": {},
    "riskContext": {}
  }
}
```

## 5. Core Outcomes

Core may return:

```text
identity_created_pending_activation
identity_linked_existing_user
business_request_created
business_request_already_pending
registration_rejected
registration_quarantined
```

Core must not silently create merchant or agent authority from an external
request. Approval is required.

## 6. Idempotency

External registration requests must carry a stable idempotency key at the
Gateway layer.

Recommended key shape:

```text
registration:{service_code}:{external_user_or_business_id}:{intent}
```

Retries must return the same Core registration/access request result.

## 7. Prohibited Fields

External services must not provide these as authority:

```text
sourceWalletId
targetWalletId
ledger account IDs
registry_type as final authority
role as final authority
account_status
wallet balance
KYC status
```

They may provide hints, but Core resolves final truth.

## 8. Audit

Core must audit:

```text
service code
worker id
external reference
target identity
requested role/family
source metadata
approval status
notifications sent
```

## 9. Endpoints

External service endpoint:

```text
POST https://pay.orbifinancial.com/v1/business/registrations
```

Core internal endpoint called by Pay Gateway:

```text
POST /api/internal/pay-gateway/business/registrations
```

Related identity lookup endpoint:

```text
POST https://pay.orbifinancial.com/v1/identity/resolve
POST /api/internal/pay-gateway/identity-resolve
```

Required service access:

```text
Pay Gateway service key accepted by Gateway
Core worker scope: gateway:business-registration:write
Core worker scope for lookup: gateway:identity:read
```

External services should not use:

```text
POST /v1/auth/signup
POST /v1/business/registrations
```

Those are Core/Auth app-facing endpoints, not third-party service authority
endpoints.
