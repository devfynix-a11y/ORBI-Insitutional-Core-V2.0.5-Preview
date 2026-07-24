# ORBI Service Actor Registration Rules

This document defines registration rules for agents, merchants, and trusted
service actors that help onboard customers.

## 1. Assisted Registration Principle

An agent or merchant may help a customer register, but the customer identity
still belongs to Core/Auth.

The actor never owns the customer's wallet, password, PIN, KYC status, or
financial account.

## 2. Required Actor Evidence

Assisted registration must capture:

```text
actor_user_id
actor_registry_type
actor_service_status
source_service_code
relationship_type
consent evidence
registration timestamp
device or service trace
```

## 3. Customer Consent

Every assisted registration requires customer confirmation through one of:

```text
OTP
hosted challenge
mobile app confirmation
verified signed consent record
```

If consent is missing, Core may create a quarantined draft but must not activate
financial services.

## 4. Relationship Records

Core should store service relationships separately from `users`:

```text
service_actor_customer_links.actor_user_id
service_actor_customer_links.actor_registry_type
service_actor_customer_links.customer_user_id
service_actor_customer_links.relationship_type
service_actor_customer_links.status
metadata
```

This prevents actor/customer ownership confusion.

## 5. Prohibited Actor Actions

Actors must not:

```text
set customer wallet balances
set customer account_status active without Core activation
set KYC verified directly
choose customer registry_type final authority
reuse customer OTP/PIN
submit financial commits without idempotency
```

## 6. Allowed Actor Actions

Approved actors may:

```text
initiate customer registration
submit identity hints
submit business or service documents
request customer challenge
receive relationship status
perform approved agent or merchant operations after Core validation
```

## 7. Notifications

Customer and actor both receive messages for:

```text
registration initiated
activation challenge sent
registration activated
registration rejected or quarantined
service relationship linked
service relationship removed
```

Language should follow the customer's stored language preference where
available.

## 8. Endpoints

Assisted registration should enter through Gateway unless the actor is inside
an official ORBI app session.

Gateway service endpoint:

```text
POST https://pay.orbifinancial.com/v1/business/registrations
```

Core internal endpoint:

```text
POST /api/internal/pay-gateway/business/registrations
```

Core relationship/status endpoints should be introduced separately when
service actor customer-link management is implemented:

```text
GET  /v1/service-actors/customers
POST /v1/service-actors/customers
PATCH /v1/service-actors/customers/:id/status
```

These relationship endpoints are planned contracts. They must not mutate
wallet balances or financial identity directly.
