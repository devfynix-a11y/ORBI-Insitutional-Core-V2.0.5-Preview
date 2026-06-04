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

## Production Safety Rule

When the standalone gateway is used, Core must not run legacy provider-gateway execution routes.

```env
ORBI_ENABLE_CORE_PROVIDER_GATEWAY_ROUTES=false
ORBI_ALLOW_STUB_PROVIDER_RECONCILIATION=false
ORBI_PAY_GATEWAY_BASE_URL=https://pay.orbifinancial.com
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
