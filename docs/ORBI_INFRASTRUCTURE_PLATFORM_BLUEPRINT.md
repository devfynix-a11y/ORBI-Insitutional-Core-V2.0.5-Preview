# ORBI Infrastructure Platform Blueprint

This blueprint defines ORBI as a financial infrastructure platform that lets
merchants, marketplaces, organizations, agents, and third-party builders create
their own products on top of ORBI without becoming independent financial
authorities.

## 1. Platform Intent

ORBI should operate as:

```text
Financial OS + PaySafe Escrow + Wallet/Payment Profile Infrastructure
+ Hosted Secure UI + Pay Gateway + Webhooks
```

External apps own their user experience and business domain. ORBI owns the
money layer.

```text
Merchant App / Marketplace / Organization System
-> ORBI Pay Gateway
-> ORBI Hosted Secure UI when sensitive action is required
-> ORBI Core/Auth
-> Ledger, PaySafe, risk, receipts, notifications, reconciliation
-> Webhook/return result back to the external app
```

## 2. Authority Boundary

### Merchant Or Third-Party Owns

```text
customer relationship
storefront, products, orders, delivery, subscriptions
merchant-specific user profile
merchant-specific login where applicable
business workflow and service UI
customer support context for their product
payment profile references returned by ORBI
```

### ORBI Owns

```text
financial identity verification
payment profile creation/linking
wallet and ledger authority
PaySafe escrow lifecycle
payment confirmation and strong customer authentication
balance read consent
withdrawal consent and execution
risk, compliance, limits, fraud controls
receipts and audit trail
webhook signing and reconciliation truth
```

Core must never delegate ledger authority, wallet secrets, account status,
registry authority, or balance mutation to a merchant application.

## 3. Hosted ORBI Secure UI

Sensitive financial actions should be completed inside ORBI-hosted pages or
secure challenge surfaces.

Examples:

```text
Add payment information
Create or link ORBI payment profile
Verify phone/email
Set ORBI PIN/passkey/password where required
Authorize payment
Authorize withdrawal
Consent to balance read
Accept PaySafe terms
Open release/refund/dispute action
```

The hosted UI must support:

```text
returnUrl
cancelUrl
webhookUrl
challenge expiry
language selection
merchant branding within ORBI safety limits
clear ORBI PaySafe branding for financial trust
```

Hosted UI can be opened through redirect, popup, or iframe only when the
security policy permits it. High-risk actions should prefer redirect or a
top-level hosted challenge.

## 4. Payment Profile Model

Merchants should store payment profile references, not wallet secrets.

Merchant-side reference:

```json
{
  "merchantCustomerId": "shop-customer-456",
  "orbiPaymentProfileId": "pp_...",
  "orbiCustomerId": "OB26-...",
  "status": "active",
  "scopes": [
    "payment_profile:read",
    "payments:create"
  ]
}
```

ORBI-side truth:

```text
user_id
customer_id
payment_profile_id
service_code
external_customer_id
consent status
allowed service code
allowed scopes
expiry
risk state
linked merchant/service
```

Payment profiles are permissioned references. They do not grant automatic fund
movement.

## 5. Scopes And Consent

Every merchant capability must be scoped.

Recommended scope families:

```text
identity:resolve
payment_profile:create
payment_profile:read
balance:read
payments:create
escrow:create
escrow:read
escrow:release:request
escrow:refund:request
escrow:dispute:create
withdrawal:request
webhooks:receive
receipts:read
```

Rules:

```text
No scope = no access.
No consent = no user financial data.
No idempotency key = no retryable financial action.
No Core-approved intent = no ledger movement.
No signed webhook = no external state transition.
```

Balance read access must be explicit, time-bound, and revocable. It should
return only the data the user authorized.

## 6. Merchant Registration Pattern

Merchant apps may use their own onboarding UI.

```text
Merchant collects business/product data
-> Merchant asks ORBI to add payment/business information
-> ORBI hosted UI collects financial requirements
-> ORBI Core creates or links financial identity
-> ORBI Core creates business registration/access request
-> ORBI returns payment/business profile reference
```

Merchant apps may keep:

```text
externalBusinessId
externalCustomerId
store profile
service profile
orbiCustomerId
orbiPaymentProfileId
orbiMerchantReference
```

Merchant apps must not keep:

```text
ORBI password
wallet secrets
ledger account IDs as authority
raw OTP/PIN/passkey material
Core admin tokens
unscoped balance snapshots
```

## 7. Payment Flow

```text
1. Merchant creates payment intent through Pay Gateway.
2. Gateway returns hostedChallengeUrl or payment status.
3. Customer completes ORBI hosted confirmation.
4. Core validates identity, balance, risk, idempotency, and consent.
5. Core creates PaySafe escrow or posts the approved ledger movement.
6. Gateway receives Core event and updates intent.
7. Gateway redirects user back to merchant returnUrl.
8. Gateway sends signed webhook to merchant webhookUrl.
9. Merchant updates order status from signed webhook, not from UI redirect alone.
```

Redirect is user experience. Webhook is system truth.

## 8. PaySafe For Third Parties

Third-party PaySafe payments may skip only the initial native app-to-app escrow
invitation step when the hosted payment challenge has already authenticated the
payer and merchant context.

After funds enter PaySafe hold, the normal PaySafe lifecycle applies:

```text
held
release requested
release confirmed
released
refund requested
refunded
disputed
expired
reconciled
```

Release, refund, dispute, and expiry rules must not be bypassed. A third-party
merchant can request actions, but Core decides whether the action is valid.

## 9. Withdrawal Through Merchant

Merchants may initiate a withdrawal request on behalf of a user only with ORBI
consent.

```text
Merchant requests withdrawal
-> ORBI hosted challenge
-> Core validates payment profile, consent, balance, destination, risk
-> Core posts ledger movement
-> Gateway sends webhook result
```

If the destination is outside ORBI, provider settlement proof is required. If
the destination is an ORBI agent or ORBI account, Core must still record the
full double-entry movement.

## 10. Webhook Contract

Webhook events should be signed and replay-safe.

Recommended events:

```text
payment_profile.created
payment_profile.updated
payment_profile.revoked
payment_intent.created
payment_intent.requires_action
payment_intent.completed
payment_intent.failed
escrow.created
escrow.held
escrow.release_requested
escrow.released
escrow.refund_requested
escrow.refunded
escrow.disputed
withdrawal.requested
withdrawal.completed
withdrawal.failed
balance_consent.granted
balance_consent.revoked
```

Every webhook should carry:

```json
{
  "eventId": "evt_...",
  "eventType": "payment_intent.completed",
  "occurredAt": "2026-07-20T04:30:00.000Z",
  "serviceCode": "orbi_shop",
  "externalReference": "order-123",
  "orbiReference": "opi_...",
  "status": "completed",
  "metadata": {}
}
```

Merchant systems must dedupe by `eventId` and verify the signature before
changing order or payout state.

## 11. Developer Surface

Future ORBI Developer Portal should expose:

```text
service registration
API keys and key rotation
allowed return URLs
allowed webhook URLs
webhook signing secrets
scope request and approval
test credentials
event logs
hosted UI branding settings
documentation and SDKs
```

Initial payment profile endpoint:

```text
POST https://pay.orbifinancial.com/v1/payment-profiles
```

The endpoint creates or links a Core-owned payment profile for a trusted
service and returns a `pp_...` reference that the merchant may store.

OIDC discovery remains documented for identity integrations, but external
financial actions must pass through Pay Gateway and Core policy.

## 12. Non-Negotiables

```text
Core is ledger truth.
Gateway is service boundary.
Hosted UI is consent and challenge boundary.
Merchant owns product UX, not financial authority.
Every retryable financial action has idempotency.
Every external state change has signed webhook evidence.
Every balance read is scoped, consented, and revocable.
Every PaySafe hold follows the same lifecycle after funds are held.
```

## 13. External Platform Contract Families

All future merchant, marketplace, agent, organization, and developer
integrations should be designed around these contract families.

```text
Payment Profile
Hosted Challenge
Payment Intent
PaySafe Escrow Lifecycle
Webhook Events
Developer/Merchant Scopes
```

### Payment Profile

The payment profile is the long-lived reference that lets an external service
recognize a Core-owned financial identity without seeing wallet internals.

```text
External app stores: paymentProfileId, service customer id, consent status.
Gateway validates: service key, scopes, idempotency, allowed service.
Core validates: identity, account status, consent, risk, wallet authority.
```

No profile may debit, credit, withdraw, release, refund, or read balance unless
the requested action has an approved scope and a fresh Core decision.

### Hosted Challenge

The hosted challenge is ORBI's secure customer authorization surface for
third-party actions.

```text
Gateway returns hostedChallengeUrl.
User completes OTP/PIN/passkey/consent on ORBI-hosted UI.
Core verifies challenge evidence.
Gateway continues the payment intent.
Merchant receives redirect for UX and signed webhook for truth.
```

Hosted challenge pages must use generic platform wording. They must not be
named after one merchant such as ORBI Shop. Merchant branding may appear only
inside ORBI safety limits.

### Payment Intent

The payment intent is the retry-safe envelope for checkout, collection,
withdrawal, or PaySafe creation.

```text
POST /v1/payment-intents
Idempotency-Key: <stable-service-operation-key>
```

The intent records amount, currency, external reference, customer lookup,
merchant context, return URL, cancel URL, webhook URL, and metadata. Core is
the only service that decides whether the intent can move funds.

### PaySafe Escrow Lifecycle

Third-party PaySafe may use hosted challenge to enter the escrow lifecycle, but
after funds are held it follows the same release, refund, dispute, expiry, and
reconciliation rules as native ORBI PaySafe.

```text
requested -> requires_action -> held -> release/refund/dispute path -> final
```

No merchant route may bypass held-funds rules after escrow is created.

### Webhook Events

Redirects are user experience. Signed webhooks are system truth.

```text
Merchant state changes only after signature verification and event dedupe.
Webhook eventId is globally unique.
Webhook externalReference maps to merchant order/service reference.
Webhook orbiReference maps to Core/Gateway truth.
```

### Developer And Merchant Scopes

Scopes must be granted per service, per capability, and per environment.

```text
identity:resolve
payment_profile:create
payment_profile:read
payments:create
escrow:create
escrow:read
escrow:release:request
escrow:refund:request
escrow:dispute:create
withdrawal:request
balance:read
webhooks:receive
```

No service should receive broad financial access simply because it is a known
merchant. Merchant registration proves business identity; scopes prove allowed
integration behavior.
