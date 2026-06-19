# ORBI Pay Gateway Integration

ORBI Core is the banking engine and ledger authority. ORBI Pay Gateway is a separate external-rail service hosted outside this repository.

It is separate from ORBI Talk Gateway:

- ORBI Pay Gateway handles external money rails and provider callbacks.
- ORBI Talk Gateway handles SMS, email, push, message templates, and delivery queues.
- ORBI Core remains the banking, ledger, risk, and control authority.

Standalone gateway folder during local development:

```txt
D:\FYNIX\ORBI\ORBI CORE\ORBI PAY GATEWAY
```

## Boundary

Core owns:

- users, wallets, balances, ledger, double-entry accounting
- transaction preview, settlement, reversal, escrow, and refund policy
- risk, limits, fraud controls, account/wallet locks, and audit
- provider routing decisions and readiness visibility
- final decision to post ledger entries

ORBI Pay Gateway owns:

- provider credentials
- provider-specific collection, payout, and refund calls
- provider webhook parsing and verification
- provider health/readiness checks
- normalized provider events sent back to Core

## Callback Path

For separate-VM deployments, ORBI Pay Gateway calls Core through the secure Core external root:

```txt
https://api.orbifinancial.com/api/internal/gateway/provider-events
```

The route is externally addressable but private by protocol. It must only accept signed internal worker traffic.

Required worker scope:

```txt
gateway:events:write
```

Required signing controls:

- `x-worker-id`
- `x-worker-scopes`
- `x-worker-request-id`
- `x-worker-timestamp`
- `x-worker-nonce`
- `x-worker-signature`
- optional `x-worker-key-id`

Core validates the worker identity, scope, timestamp freshness, nonce replay protection, body hash, and HMAC signature before processing the event.

## Service Payment Requests

External ORBI products such as ORBI Shop must enter through ORBI Pay Gateway. Pay Gateway then sends a signed internal request to Core:

```txt
POST /api/internal/pay-gateway/service-payment-requests
```

Required worker scope:

```txt
gateway:service-payments:write
```

Core remains the authority for customer lookup, internal/external routing, PaySafe escrow, risk, OTP/PIN/passkey challenge, and ledger settlement. Pay Gateway does not choose providers for third-party service requests.

Service requests are global from Pay Gateway. External products should not use service-specific URLs such as `/v1/services/orbi-shop/...`; the service identity comes from its Pay Gateway API key. Typical external product routes are:

```txt
POST /v1/payment-intents
GET /v1/payment-intents/:intentId
POST /v1/payment-intents/:intentId/confirm
POST /v1/paysafe/escrows
POST /v1/paysafe/escrows/:escrowId/release
POST /v1/paysafe/escrows/:escrowId/dispute
POST /v1/paysafe/escrows/:escrowId/refund
GET /v1/paysafe/users/:userId/balance
GET /v1/paysafe/balances?userId=<orbi-user-id>
```

PaySafe actions arrive in Core as `operation: "paysafe"` with `metadata.paySafeAction` set to `create_escrow`, `release`, `dispute`, or `refund`. Core must treat those as product-level payment instructions, not provider calls.

For ORBI Shop and similar marketplaces, Pay Gateway sends merchant context in request metadata. Pay Gateway does not send wallet IDs. Core resolves the merchant wallets from `merchant_wallets` using the merchant ID:

```json
{
  "merchantId": "merchant-uuid",
  "feeProfileCode": "ORBI_SHOP_PAYSAFE",
  "feeFlowCode": "MERCHANT_PAYMENT"
}
```

Core validates:

- merchant exists and is `active`
- an active PaySafe escrow wallet exists for that merchant (`paysafe_escrow`, `escrow`, or `holding`)
- an active settlement wallet exists for that merchant when settlement reporting or payout flow needs it (`settlement` or `operating`)
- merchant fee quote can be resolved or reported as unresolved

Ledger posting remains a Core responsibility. Pay Gateway only carries the merchant context and request envelope.

When Core needs customer approval, it returns and posts back a service payment event:

```json
{
  "intentId": "pi_xxx",
  "serviceCode": "orbi-shop",
  "status": "requires_action",
  "message": "Customer authorization is required before ORBI Core can continue payment processing.",
  "challenge": {
    "type": "PIN",
    "challengeId": "pay_ch_xxx",
    "prompt": "Approve TZS 125000 for orbi-shop.",
    "expiresAt": "2026-06-17T10:45:00.000Z",
    "delivery": {
      "channel": "in_app",
      "destinationHint": "ORBI mobile app"
    }
  }
}
```

Core sends that result to Pay Gateway:

```txt
POST {ORBI_PAY_GATEWAY_BASE_URL}{ORBI_PAY_GATEWAY_SERVICE_PAYMENT_EVENT_PATH}
```

Required worker scope:

```txt
gateway:service-payments:result
```

## PaySafe Balance Read For Seller Portals

External products must not query Core, wallets, or escrow tables directly. When a seller portal needs to show protected PaySafe funds, it calls Pay Gateway:

```txt
GET /v1/paysafe/users/:userId/balance
GET /v1/merchant/paysafe/balance
GET /v1/merchant/orders/:orderId/payment-status
GET /v1/merchant/settlements
```

Pay Gateway signs read-only internal requests to Core:

```txt
POST /api/internal/pay-gateway/paysafe-balances
POST /api/internal/pay-gateway/merchant-order-payment-status
POST /api/internal/pay-gateway/merchant-settlements
```

Required worker scopes:

```txt
gateway:paysafe-balances:read
gateway:merchant-payments:read
gateway:merchant-settlements:read
```

Core returns a sanitized projection only:

- ORBI user identity summary
- totals by currency
- incoming held/disputed balances
- outgoing held/disputed balances
- optional released/refunded history when requested
- merchant identity used to scope the query

This lets ORBI Shop show "protected incoming payments" in the seller dashboard without exposing internal wallet rows, ledger details, provider secrets, or direct Core access.

Balance reads are merchant-scoped through `metadata.merchantId`, and Core filters escrow rows by `conditions.merchantId`. When Core creates future PaySafe escrow rows from service payment requests, it must persist the merchant context into escrow conditions so seller portals can reconcile accurately.

## Production Safety Rule

When the standalone gateway is used, Core must not run legacy provider-gateway execution routes.

```env
ORBI_ENABLE_CORE_PROVIDER_GATEWAY_ROUTES=false
ORBI_ALLOW_STUB_PROVIDER_RECONCILIATION=false
ORBI_PAY_GATEWAY_BASE_URL=https://pay.orbifinancial.com
ORBI_PAY_GATEWAY_SERVICE_PAYMENT_EVENT_PATH=/v1/internal/core/service-payment-events
ORBI_CORE_PAY_GATEWAY_WORKER_ID=orbi-core
```

Live settlement must require trusted provider proof from ORBI Pay Gateway, a verified provider webhook, provider API reconciliation, or admin dual-control evidence before Core posts ledger entries.

## Core Readiness

Admin Portal reads Core gateway readiness through:

```http
GET /api/admin/payment-gateway/readiness
```

Core checks `ORBI_PAY_GATEWAY_BASE_URL` and reports ORBI Pay Gateway reachability/readiness without exposing provider secrets.

## Internal mTLS Roadmap

HMAC remains required permanently. mTLS is added later as service identity at the transport layer.

Recommended rollout:

1. HMAC over HTTPS external Core root.
2. Proxy mTLS at Nginx or service mesh.
3. Direct mTLS once certificate lifecycle and private service routing are stable.

Do not commit CA keys, service private keys, provider secrets, or generated certificates.
