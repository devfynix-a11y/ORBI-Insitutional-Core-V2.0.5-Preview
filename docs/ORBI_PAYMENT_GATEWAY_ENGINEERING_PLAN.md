# ORBI Payment Gateway Engineering Plan

## Purpose

The ORBI Payment Gateway is the dedicated integration layer for real external money movement providers such as mobile money, bank transfer rails, card processors, crypto ramps, and future payout partners.

It is intentionally separate from ORBI Talk Gateway. ORBI Talk handles SMS, email, push, and templates. ORBI Payment Gateway handles collections, payouts, refunds, provider callbacks, settlement status, and payment rail health.

## Architecture

```txt
Provider / Partner
  -> gateway.orbifinancial.com
  -> ORBI Payment Gateway
  -> signed internal worker callback
  -> ORBI Core /api/internal/gateway/provider-events
  -> ledger, institutional funds, reconciliation, audit
```

The gateway may initially run on the same VM as Core and be exposed through Nginx:

```txt
https://gateway.orbifinancial.com -> 127.0.0.1:3100
https://api.orbifinancial.com/gateway -> 127.0.0.1:3100
```

The service can later move to a separate VM/container without changing the Core trust contract.

## Non-Negotiable Ledger Boundary

The payment gateway must never:

- Directly update wallet balances.
- Insert ledger entries.
- Mark ORBI transactions complete without Core validation.
- Store raw card secrets, OTPs, private keys, or KYC files.
- Trust a provider callback only because it reached the public endpoint.

The gateway may:

- Validate provider signatures.
- Normalize callback status.
- Dedupe provider events.
- Submit signed internal provider events to Core.
- Report provider health and routing capabilities.

Core remains the system of record for double-entry accounting, reversals, refunds, settlement, and reconciliation.

## Current Service Work Structure

```txt
payment-gateway/
  src/server.ts
  src/config.ts
  src/core/orbiCoreClient.ts
  src/security/internalSigner.ts
  src/adapters/AdapterRegistry.ts
  src/adapters/selcom/SelcomAdapter.ts
  src/adapters/mpesa-tanzania/MpesaTanzaniaAdapter.ts
  tests/internalSigner.test.ts
```

The first real adapter slots are scaffolded to keep the production contract stable:

- `selcom`: Tanzania payment rail placeholder awaiting final provider contract mapping.
- `mpesa-tanzania`: M-Pesa Tanzania placeholder awaiting final provider contract mapping.

## Public Gateway API

### Health

```http
GET /health
GET /ready
GET /v1/providers
GET /v1/providers/:providerCode/health
```

Core exposes the gateway readiness view to the Admin Portal through:

```http
GET /api/admin/payment-gateway/readiness
```

The response is read-only and safe for operators. It includes gateway reachability, mTLS mode, provider adapter codes, supported operations, and missing environment variable names, but never returns API keys or provider secrets.

### Collections

```http
POST /v1/collections
```

```json
{
  "providerCode": "mpesa-tanzania",
  "reference": "orbi-tx-reference",
  "amount": 10000,
  "currency": "TZS",
  "phone": "+255700000000",
  "description": "Wallet deposit",
  "metadata": {
    "tenantId": "orbi",
    "channel": "mobile"
  }
}
```

### Payouts

```http
POST /v1/payouts
```

### Refunds

```http
POST /v1/refunds
```

Refunds must be tied to the original Core transaction/reference so Core can keep refund accounting in the same money lifecycle.

### Provider Webhooks

```http
POST /v1/webhooks/:providerCode
```

The adapter parses provider-specific payloads into a normalized event:

```json
{
  "providerId": "mpesa-tanzania",
  "reference": "orbi-tx-reference",
  "status": "completed",
  "message": "Provider confirmed payment",
  "providerEventId": "provider-event-id",
  "rawStatus": "0",
  "payload": {}
}
```

## Core Internal Callback

The gateway posts normalized events to:

```http
POST /api/internal/gateway/provider-events
```

Required worker scope:

```txt
gateway:events:write
```

The Core route is protected by signed internal worker authentication:

```http
x-worker-id: orbi-payment-gateway
x-worker-scopes: gateway:events:write
x-worker-request-id: <uuid>
x-worker-timestamp: <iso-date>
x-worker-nonce: <uuid>
x-worker-signature: <hmac-sha256>
x-worker-key-id: payment-gateway-v1
```

Core validates:

- worker identity
- worker scope
- timestamp freshness
- nonce replay protection
- body hash
- HMAC signature
- optional internal mTLS identity

## Core Boundary Controls

ORBI Core remains the ledger authority and should not run as the live external provider gateway after the standalone Payment Gateway is deployed.

Production defaults:

```env
ORBI_ENABLE_CORE_PROVIDER_GATEWAY_ROUTES=false
ORBI_ALLOW_STUB_PROVIDER_RECONCILIATION=false
```

Behavior:

- `/v1/external-funds/*` remains a Core-owned intent, preview, movement, and ledger-settlement surface.
- `/api/internal/gateway/provider-events` remains the trusted signed callback surface from ORBI Payment Gateway.
- Legacy Core `/v1/gateway/*` and `/v1/webhooks/gateway/:providerId` provider-execution routes are disabled unless `ORBI_ENABLE_CORE_PROVIDER_GATEWAY_ROUTES=true`.
- Settlement lifecycle reconciliation fails closed unless the settlement has trusted provider proof from the Payment Gateway, a verified provider webhook, a provider API reconciliation result, or an admin dual-control confirmation record.
- Stub reconciliation is allowed only outside production when `ORBI_ALLOW_STUB_PROVIDER_RECONCILIATION=true`.

This prevents Core from accidentally crediting wallets based on placeholder provider verification. Core can record intents and post double-entry ledger entries only after external proof is normalized, signed, and accepted through the trusted boundary.

## Internal mTLS Plan

### Phase 1: Current Production-Safe Mode

Use signed HMAC worker requests over localhost or private networking:

```env
ORBI_CORE_INTERNAL_BASE_URL=http://127.0.0.1:3000
WORKER_SIGNING_SECRET=<same-secret-as-core>
PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED=false
```

Core must temporarily allow signed internal HMAC without certificate attestation while certificates are not installed:

```env
ORBI_INTERNAL_MTLS_MODE=optional
ORBI_INTERNAL_MTLS_SOURCE=proxy
```

This is simple and safe for a same-VM rollout because the HMAC signature, timestamp, nonce replay protection, worker scope, and private/localhost transport still protect the callback. Move to `ORBI_INTERNAL_MTLS_MODE=required` after Phase 2 or Phase 3 is verified.

### Phase 2: Proxy mTLS

Nginx terminates TLS, validates the gateway client certificate, and forwards trusted mTLS attestation headers to Core.

Core:

```env
ORBI_INTERNAL_MTLS_MODE=required
ORBI_INTERNAL_MTLS_SOURCE=proxy
ORBI_INTERNAL_MTLS_PROXY_HEADER=x-orbi-mtls-attested
ORBI_INTERNAL_MTLS_PROXY_SHARED_SECRET=<strong-secret>
```

Nginx should only emit the trusted attestation header after successful client certificate verification.

### Phase 3: Direct mTLS

The gateway calls a private HTTPS Core listener using a client certificate:

```env
PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED=true
PAYMENT_GATEWAY_INTERNAL_MTLS_CERT_PATH=/etc/orbi/certs/payment-gateway.crt
PAYMENT_GATEWAY_INTERNAL_MTLS_KEY_PATH=/etc/orbi/certs/payment-gateway.key
PAYMENT_GATEWAY_INTERNAL_MTLS_CA_PATH=/etc/orbi/certs/orbi-internal-ca.crt
PAYMENT_GATEWAY_INTERNAL_MTLS_REJECT_UNAUTHORIZED=true
ORBI_CORE_INTERNAL_BASE_URL=https://core.internal.orbifinancial.com
```

Core:

```env
ORBI_INTERNAL_MTLS_MODE=required
ORBI_INTERNAL_MTLS_SOURCE=direct
ORBI_INTERNAL_MTLS_CA_PATH=/etc/orbi/certs/orbi-internal-ca.crt
```

HMAC signatures remain enabled even after mTLS. mTLS proves service identity at transport level; HMAC proves request integrity and replay safety at application level.

## Next Development: Internal mTLS Rollout

This is the next security-hardening milestone after the payment gateway bridge is stable with signed HMAC callbacks. Do not remove HMAC when mTLS is introduced; the two controls protect different layers.

### Target Outcome

Core and Payment Gateway must only accept internal money-movement callbacks from authenticated ORBI services:

```txt
Payment Gateway client certificate
+ trusted internal CA
+ HMAC request signature
+ timestamp freshness
+ nonce/idempotency replay protection
= trusted internal provider event
```

### Development Tasks

1. Certificate authority setup
   - Create an ORBI internal service CA outside Git.
   - Store the CA private key in a restricted secrets vault or offline operator store.
   - Define certificate naming such as `orbi-core.internal` and `orbi-payment-gateway.internal`.
   - Document certificate expiry, rotation owner, and emergency revocation procedure.

2. Gateway-to-Core mTLS
   - Add Payment Gateway HTTPS client support for:
     - `PAYMENT_GATEWAY_INTERNAL_MTLS_CERT_PATH`
     - `PAYMENT_GATEWAY_INTERNAL_MTLS_KEY_PATH`
     - `PAYMENT_GATEWAY_INTERNAL_MTLS_CA_PATH`
     - `PAYMENT_GATEWAY_INTERNAL_MTLS_REJECT_UNAUTHORIZED=true`
   - Keep `WORKER_SIGNING_SECRET` enabled for every callback.
   - Keep `x-worker-id`, `x-worker-scopes`, timestamp, nonce, body hash, and request signature validation.

3. Core mTLS verification
   - Start with proxy-attested mTLS if Nginx or a service mesh terminates TLS.
   - Move to direct mTLS only when Core has a private HTTPS listener and certificate lifecycle is proven.
   - Set `ORBI_INTERNAL_MTLS_MODE=required` only after smoke tests pass.

4. Deployment sequencing
   - Deploy certificates first.
   - Enable gateway mTLS client configuration in staging.
   - Confirm Core still accepts signed HMAC callbacks.
   - Turn on mTLS verification in `optional` mode.
   - Verify mTLS evidence appears in audit/operator logs.
   - Switch production to `required`.

5. Operator visibility
   - Add readiness output showing:
     - mTLS mode
     - certificate paths configured/not configured
     - certificate expiry days remaining, without exposing certificate material
     - last successful mTLS-authenticated gateway callback
   - Surface failed mTLS verification as a high-priority operator alert.

### Acceptance Criteria

- Gateway cannot call Core internal callback endpoint without a valid client certificate when mTLS is required.
- A valid client certificate without a valid HMAC signature is still rejected.
- A valid HMAC signature without mTLS is rejected once `ORBI_INTERNAL_MTLS_MODE=required`.
- Replayed callback nonce/idempotency keys are rejected.
- Operator logs show why a request was rejected without exposing secrets.
- `/health` and public admin/mobile routes remain unaffected.

### Rollback Plan

If mTLS causes production callback failure:

1. Keep HMAC validation enabled.
2. Temporarily set `ORBI_INTERNAL_MTLS_MODE=optional`.
3. Restart/reload Core and Gateway.
4. Confirm provider callbacks recover.
5. Investigate certificate path, CA mismatch, expired certificate, proxy headers, or private listener routing before returning to `required`.

### Do Not Do Yet

- Do not expose internal mTLS endpoints publicly.
- Do not put CA keys, service private keys, or generated certificates in Git.
- Do not remove HMAC signatures after mTLS.
- Do not enable account-crediting callbacks from the gateway until Core verifies both service identity and request integrity.

## Environment Variables

Gateway:

```env
PAYMENT_GATEWAY_PORT=3100
PAYMENT_GATEWAY_PUBLIC_BASE_URL=https://gateway.orbifinancial.com
PAYMENT_GATEWAY_PROVIDER_MODE=live
ORBI_CORE_INTERNAL_BASE_URL=http://127.0.0.1:3000
ORBI_CORE_TRUSTED_GATEWAY_EVENT_PATH=/api/internal/gateway/provider-events
PAYMENT_GATEWAY_WORKER_ID=orbi-payment-gateway
PAYMENT_GATEWAY_WORKER_SCOPES=gateway:events:write
WORKER_SIGNING_SECRET=
WORKER_KEY_ID=payment-gateway-v1
PAYMENT_GATEWAY_INTERNAL_MTLS_ENABLED=false
PAYMENT_GATEWAY_INTERNAL_MTLS_CERT_PATH=
PAYMENT_GATEWAY_INTERNAL_MTLS_KEY_PATH=
PAYMENT_GATEWAY_INTERNAL_MTLS_CA_PATH=
PAYMENT_GATEWAY_INTERNAL_MTLS_REJECT_UNAUTHORIZED=true
SELCOM_API_BASE_URL=
SELCOM_API_KEY=
SELCOM_API_SECRET=
MPESA_TZ_API_BASE_URL=
MPESA_TZ_API_KEY=
MPESA_TZ_API_SECRET=
```

Core:

```env
WORKER_SIGNING_SECRET=<same-secret-as-gateway>
ORBI_INTERNAL_MTLS_MODE=required
ORBI_INTERNAL_MTLS_SOURCE=proxy
ORBI_INTERNAL_MTLS_PROXY_HEADER=x-orbi-mtls-attested
ORBI_INTERNAL_MTLS_PROXY_SHARED_SECRET=<strong-secret>
ORBI_GATEWAY_BASE_URL=https://gateway.orbifinancial.com
```

## Nginx Sketch

```nginx
server {
  server_name gateway.orbifinancial.com;

  location / {
    proxy_pass http://127.0.0.1:3100;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
```

Optional same-domain path routing:

```nginx
location /gateway/ {
  rewrite ^/gateway/(.*)$ /$1 break;
  proxy_pass http://127.0.0.1:3100;
}
```

## Security Controls

- Provider webhooks must be signature-verified inside each live adapter.
- Gateway-to-Core callbacks must use signed worker requests.
- Core must apply idempotency, replay protection, ledger state checks, and reconciliation.
- Gateway API routes should sit behind Cloudflare/WAF and Core API Gateway security once routed through Core.
- Secrets must remain in VM/container environment variables, not Git.
- Adapter errors must be normalized before showing to operators.

## Rollout

1. Run gateway locally with provider credentials disabled and confirm it reports adapter readiness accurately.
2. Confirm `/health`, `/ready`, and `/v1/providers`.
3. Configure Core `WORKER_SIGNING_SECRET`.
4. Configure gateway with the same `WORKER_SIGNING_SECRET`.
5. Test a signed provider webhook with a known Core reference after a real adapter contract is configured.
6. Put Nginx in front of `127.0.0.1:3100`.
7. Enable provider credentials one rail at a time.
8. Add proxy mTLS, then direct mTLS once cert lifecycle is stable.
