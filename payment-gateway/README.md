# ORBI Payment Gateway

The ORBI Payment Gateway is the provider-facing service for external collections, payouts, refunds, and payment callbacks. It does not mutate balances directly. It normalizes provider events and submits them to ORBI Core through a signed internal worker route.

## Local Run

```bash
cp .env.example .env
npm install
npm run dev
```

Default health endpoint:

```txt
http://127.0.0.1:3100/health
```

## Core Trust Boundary

Gateway to Core callbacks use:

- `x-worker-id`
- `x-worker-scopes`
- `x-worker-request-id`
- `x-worker-timestamp`
- `x-worker-nonce`
- `x-worker-signature`
- optional `x-worker-key-id`

Core validates these with `WORKER_SIGNING_SECRET` and the `gateway:events:write` scope.

## Internal mTLS

Current production-safe path is HMAC-signed internal traffic over localhost/private networking. The gateway is prepared for internal mTLS in two phases:

1. Proxy mTLS: Nginx verifies the gateway client certificate and forwards Core's trusted mTLS attestation headers.
2. Direct mTLS: set `PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED=true` and point the cert/key/CA variables at the client certificate material.

Core should be configured with `ORBI_INTERNAL_MTLS_MODE=required` once certificates are issued and tested.
