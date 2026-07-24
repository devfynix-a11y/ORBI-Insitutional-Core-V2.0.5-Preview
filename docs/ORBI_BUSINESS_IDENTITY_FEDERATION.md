# ORBI Business Identity Federation

This document defines how ORBI Core, ORBI Shop, ORBI Pay Gateway, and future
ORBI business surfaces share business identity without duplicating financial
authority.

For the wider BaaS/platform model, see
[ORBI Infrastructure Platform Blueprint](./ORBI_INFRASTRUCTURE_PLATFORM_BLUEPRINT.md).

## 1. Objective

ORBI must let a business user register once and operate across the ORBI
ecosystem:

- ORBI Mobile/Core for identity, wallets, PaySafe, merchant status, risk, and
  settlement authority.
- ORBI Shop for storefront, products, orders, seller tools, and marketplace
  profile.
- ORBI Pay Gateway for third-party checkout, challenge flows, idempotency, and
  merchant payment intents.

The business must not need separate financial passwords, balances, or merchant
records per app.

## 2. Authority Boundaries

Core/Auth is the identity and financial authority.

Core owns:

- credentials and password reset;
- sessions, MFA, OTP, device trust, lock/freeze;
- `users`, `registry_type`, `role`, and account status;
- merchant and agent approval;
- `merchants`, `merchant_wallets`, `merchant_fees`,
  `merchant_settlements`, and merchant PaySafe settlement records;
- all ledger-backed balances and settlement state.

ORBI Shop owns:

- storefront profile;
- product catalog;
- stock, bundles, seller promotions, pricing presentation;
- orders and delivery lifecycle;
- marketplace chats and seller support surfaces.

ORBI Pay Gateway owns:

- payment request envelope;
- hosted challenge UX;
- return URLs and callbacks;
- idempotency keys and request correlation;
- signed communication with Core.

Pay Gateway must not own passwords, merchant balances, or settlement truth.

## 3. Core Business Identity Model

The canonical business actor starts as a Core user.

Consumer signup:

```text
users.registry_type = CONSUMER
users.role = CONSUMER or USER
```

Business access request:

```text
service_access_requests.requested_role = MERCHANT | AGENT
service_access_requests.requested_registry_type = MERCHANT | AGENT
service_access_requests.status = pending | under_review | approved | rejected
```

Approved merchant provisioning:

```text
users.registry_type = MERCHANT
users.role = MERCHANT
merchants.owner_user_id = users.id
merchant_wallets.owner_user_id = users.id
merchant_wallets.merchant_id = merchants.id
merchant_fees.merchant_id = merchants.id
merchant_settlements.merchant_id = merchants.id
```

The `registry_type` field is identity classification, not a transaction
shortcut. Financial actions must still verify the merchant record, wallet
ownership, account status, and ledger state.

## 4. Shop Linkage Model

ORBI Shop seller profiles are product and marketplace profiles. They must link
to Core rather than duplicate Core financial identity.

Recommended Shop seller linkage fields:

```text
sellers.core_user_id
sellers.core_merchant_id
sellers.core_registry_type
sellers.core_sync_status
sellers.core_approved_at
sellers.core_last_synced_at
sellers.core_sync_error
```

Recommended seller status interpretation:

- `pending_core_approval`: seller application exists but Core merchant access
  is not approved.
- `active`: Core merchant is active and linked.
- `frozen`: local marketplace freeze or Core account freeze.
- `suspended`: marketplace or Core compliance suspension.

Shop may cache these values for UX, but Core remains the authority.

## 5. Login And Password Flow

Users should not have separate passwords for Core and Shop.

Preferred flow:

1. User opens ORBI Shop login.
2. Shop redirects to the central ORBI identity surface, preferably
   `auth.orbifinancial.com`.
3. Shop receives a signed user token/session.
4. Shop calls Core to resolve business access:

```text
GET /v1/business/me
```

5. Core returns user identity, merchant status, agent status, organization
   memberships, and service access state.
6. Shop routes the user:

- buyer UI if no business access exists;
- pending business screen if approval is pending;
- seller dashboard if `merchant.status = active`;
- locked/frozen screen if Core account status blocks access.

Shop must not store plaintext or encrypted user passwords in its own business
tables.

`auth.orbifinancial.com` is the public identity experience. Core remains the
financial resource server and business authority behind it. ORBI Shop, Mobile,
Gateway, and future portals should not implement independent password stores.

## 6. Registration Flow

### 6.1 Consumer/Buyer

Buyer registration can remain lightweight, but the identity should still be
created through Core/Auth or synced immediately to Core.

### 6.2 Seller, Producer, Industrial, Wakala

Business registration should create a Core service access request.

Shop collects marketplace-specific fields:

- store name;
- business type;
- TIN/BRELA/VRN where applicable;
- pickup address and coordinates;
- product category;
- documents and verification artifacts;
- contact and payout preferences.

First-party ORBI apps submit the normalized request to Core:

```text
POST /v1/business/registrations
```

Trusted external services such as ORBI Shop must not call Core public business
registration directly. They submit to ORBI Pay Gateway, and Pay Gateway calls
Core through the internal worker route:

```text
POST /api/internal/pay-gateway/business/registrations
scope: gateway:business-registration:write
```

Core creates:

- Core user identity if it does not exist;
- service access request;
- audit record;
- notification to control room;
- notification to applicant.

On admin approval, Core provisions the merchant and returns:

```text
core_user_id
core_merchant_id
registry_type
role
merchant_status
business_id
```

Shop then updates the seller profile linkage.

## 7. Business Profile Sync

Core and Shop need a narrow sync contract. Do not sync ledger balances into
Shop as editable data.

Core-to-Shop events:

- merchant access approved;
- merchant suspended/frozen;
- merchant reactivated;
- merchant settlement status changed;
- merchant PaySafe held/released/refunded/disputed;
- account/session security state changed.

Shop-to-Core events:

- seller application submitted;
- marketplace profile updated;
- business document uploaded;
- store suspended by marketplace policy;
- order payment requested;
- order delivered/buyer confirmed;
- order disputed.

Sync must use signed server-to-server calls with idempotency keys.

## 8. Gateway And Third-Party Checkout

For ORBI Shop and future third parties:

1. Third party submits checkout payment intent to Pay Gateway.
2. Pay Gateway sends merchant context to Core using `core_merchant_id`.
3. Core validates:

- merchant exists;
- merchant is active;
- owner user is active;
- merchant wallets exist and are active;
- PaySafe/settlement rules are configured.

4. Customer completes hosted challenge.
5. Core creates PaySafe hold.
6. Gateway calls the third party return URL/webhook.
7. Shop order moves to `PAYMENT_HELD`.

No third party may send wallet IDs as financial authority.

## 8.1 Business Registration API Contract

Public/session endpoints:

```text
GET /v1/business/me
POST /v1/business/registrations
```

Internal Gateway-to-Core endpoint:

```text
POST /api/internal/pay-gateway/business/registrations
```

The internal request accepts `userId`, `email`, or `phone` to resolve an
existing Core identity, then creates a business service access request. If the
Core identity does not exist yet, the correct next step is the central auth
surface at `auth.orbifinancial.com` to create or link the identity first.

External surfaces must treat Gateway as the only integration root. Core
internal worker endpoints are not public product APIs.

## 9. Failure Rules

If Shop cannot confirm Core merchant identity:

- do not open seller financial dashboard;
- show pending or verification-required state;
- keep product draft capabilities separate from live selling;
- block payout and checkout acceptance.

If Gateway cannot confirm merchant context:

- fail closed;
- return stable domain error;
- do not create escrow;
- do not retry without idempotency.

If Core cannot sync back to Shop:

- Core remains authoritative;
- queue retry with idempotency;
- Shop shows "sync pending" instead of inventing status.

## 10. Migration Plan

Phase 1: Read-only federation

- Add Core `/v1/business/me`.
- Add Shop fields for Core linkage.
- Let Shop login resolve Core merchant status after authentication.
- Display pending/active/frozen states based on Core response.

Phase 2: Unified registration

- Change Shop business registration to submit Core service access request.
- Stop creating financial merchant assumptions inside Shop.
- Keep Shop `sellers` as marketplace profiles only.

Phase 3: Approval webhook

- When Core approves merchant access, Core calls Shop callback with
  `core_user_id` and `core_merchant_id`.
- Shop links existing seller profile or creates a marketplace seller profile.

Phase 4: Password authority migration

- Remove Shop-owned password storage from `customers` and `sellers`.
- Use Core/Auth sessions for Shop.
- Keep legacy password columns read-only until migration is complete, then
  remove or quarantine them.

Phase 5: Production hardening

- Add idempotency to every sync and callback.
- Add audit trails for every registration decision.
- Add support tools to relink duplicate seller/merchant profiles.
- Add reconciliation report for Shop seller records without Core merchant
  linkage.

## 11. Non-Negotiable Rules

- Core/Auth owns passwords and sessions.
- Core owns business financial identity.
- Shop owns storefront data only.
- Gateway owns payment envelope only.
- No app may update balance directly.
- No client-sent merchant ID is trusted without Core verification.
- No duplicate active merchant identities for the same business without an
  explicit multi-branch or multi-store relationship.
