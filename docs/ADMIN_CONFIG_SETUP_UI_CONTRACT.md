# ORBI Admin Configuration Setup UI Contract

This document defines a simple professional admin UI flow for configuring FX rates, FX conversion fees, and payment providers without asking operators to edit SQL or raw database rows.

The goal is one clear frontend screen with input fields, a preview console, editable JSON, copyable examples, and a single backend POST request that saves the correct production configuration into the database.

## Design Principle

Frontend should collect human-friendly fields. Backend should normalize, validate, secure secrets, and write database records.

Do not let the frontend write directly to these tables:

- `infra_system_matrix`
- `platform_fee_configs`
- `financial_partners`
- `provider_routing_rules`
- `provider_config_versions`

Instead, frontend posts one setup payload to an admin endpoint. Backend decides which tables to update.

## Recommended Backend Endpoint

Implemented endpoint:

```http
POST /api/admin/config/bootstrap
Authorization: Bearer <admin-token>
Content-Type: application/json
```

Required permission. The backend route accepts any one of these operational permissions plus the allowed admin roles:

```text
provider.write, provider_routing.write, platform_fee.write, infra_config.write
```

Recommended allowed roles:

```text
ADMIN, SUPER_ADMIN, IT
```

Preview is handled by the same endpoint with `"mode": "preview"`. Commit is handled with `"mode": "commit"`.

## Single Payload Shape

```json
{
  "mode": "preview",
  "fx": {
    "rates": {
      "USD": 1,
      "TZS": 2550,
      "KES": 135,
      "UGX": 3900,
      "RWF": 1280,
      "EUR": 0.92,
      "GBP": 0.78
    },
    "fee": {
      "name": "Default FX conversion fee",
      "percentageRate": 0.01,
      "fixedAmount": 0,
      "minimumFee": 0,
      "maximumFee": null,
      "taxRate": 0,
      "govFeeRate": 0,
      "stampDutyFixed": 0,
      "priority": 100,
      "status": "ACTIVE"
    }
  },
  "providers": [
    {
      "name": "Vodacom M-Pesa",
      "type": "mobile_money",
      "status": "ACTIVE",
      "logicType": "REGISTRY",
      "supportedCurrencies": ["TZS"],
      "providerCode": "MPESA_TZ",
      "rail": "MOBILE_MONEY",
      "apiBaseUrl": "https://provider.example.com",
      "clientId": "provider-client-id",
      "connectionSecret": "provider-api-key-or-token",
      "clientSecret": "provider-client-secret",
      "webhookSecret": "provider-webhook-secret",
      "operations": [
        {
          "operationCode": "COLLECTION_REQUEST",
          "method": "POST",
          "path": "/collections",
          "requestTemplate": {
            "amount": "{{amount}}",
            "currency": "{{currency}}",
            "phone": "{{recipient.phone}}",
            "reference": "{{reference}}"
          },
          "responseMapping": {
            "providerRef": "data.transaction_id",
            "status": "data.status",
            "message": "message"
          },
          "callback": {
            "path": "/webhooks/mpesa",
            "referenceField": "transaction_id",
            "statusField": "status"
          }
        },
        {
          "operationCode": "DISBURSEMENT_REQUEST",
          "method": "POST",
          "path": "/disbursements",
          "requestTemplate": {
            "amount": "{{amount}}",
            "currency": "{{currency}}",
            "phone": "{{recipient.phone}}",
            "reference": "{{reference}}"
          },
          "responseMapping": {
            "providerRef": "data.transaction_id",
            "status": "data.status",
            "message": "message"
          },
          "callback": {
            "path": "/webhooks/mpesa",
            "referenceField": "transaction_id",
            "statusField": "status"
          }
        }
      ],
      "routingRules": [
        {
          "rail": "MOBILE_MONEY",
          "countryCode": "TZ",
          "currency": "TZS",
          "operationCode": "COLLECTION_REQUEST",
          "priority": 100,
          "status": "ACTIVE"
        },
        {
          "rail": "MOBILE_MONEY",
          "countryCode": "TZ",
          "currency": "TZS",
          "operationCode": "DISBURSEMENT_REQUEST",
          "priority": 100,
          "status": "ACTIVE"
        }
      ]
    }
  ]
}
```

`mode` values:

- `preview`: validate only and return normalized write plan.
- `commit`: validate and save records.

Frontend should default to `preview`. The user should explicitly press `Apply configuration` to send `mode = commit`.

## FX UI Fields

Recommended simple fields:

- `USD`: base rate. Always `1`.
- `TZS`: Tanzanian shilling per USD.
- `KES`: Kenyan shilling per USD.
- `UGX`: Ugandan shilling per USD.
- `RWF`: Rwandan franc per USD.
- `EUR`: EUR per USD.
- `GBP`: GBP per USD.

Recommended fee fields:

- Fee name
- Percentage rate
- Fixed amount
- Minimum fee
- Maximum fee
- Tax rate
- Government fee rate
- Stamp duty fixed
- Priority
- Status

Important percentage rule:

```text
0.01 = 1%
0.025 = 2.5%
1 = 100%
```

Frontend should show helper text next to percentage inputs.

## Provider UI Fields

Recommended simple provider form:

- Provider name
- Provider type: `mobile_money`, `bank`, `card`, `crypto`
- Status: `ACTIVE`, `INACTIVE`, `MAINTENANCE`
- Provider code: example `MPESA_TZ`
- Rail: example `MOBILE_MONEY`
- Supported currencies
- API base URL
- Client ID
- API key / connection secret
- Client secret
- Webhook secret
- Operations
- Routing rules

Operations editor should be repeatable. Each operation needs:

- Operation code: `COLLECTION_REQUEST`, `DISBURSEMENT_REQUEST`, `TRANSFER_REQUEST`
- HTTP method
- Path
- Request template JSON
- Response mapping JSON
- Callback config

Routing rules editor should be repeatable. Each rule needs:

- Rail
- Country code
- Currency
- Operation code
- Priority
- Status

## Partner Bank / Sponsored Switch UI

For production launch, ORBI should prefer a partner bank or sponsored switch profile instead of manually configuring every downstream provider. The partner bank owns or sponsors access to clearing networks such as TIPS, while ORBI Core remains the ledger and banking engine and ORBI Pay Gateway remains the payment execution boundary.

Use `partnerBanks` when ORBI connects through a bank partner that can reach TIPS, mobile money networks, or other national/regional rails:

```json
{
  "mode": "preview",
  "partnerBanks": [
    {
      "partnerCode": "NMB_SPONSORED_TIPS",
      "name": "NMB Sponsored TIPS Access",
      "status": "INACTIVE",
      "payGatewayProviderCode": "nmb-obp-sandbox",
      "clearingNetwork": "TIPS",
      "messageStandard": "PROVIDER_NATIVE",
      "settlementModel": "SANDBOX",
      "supportedCurrencies": ["TZS"],
      "countries": ["TZ"],
      "operations": [
        "COLLECTION_REQUEST",
        "DISBURSEMENT_REQUEST",
        "REVERSAL_REQUEST"
      ],
      "downstreamCapabilities": [
        {
          "capabilityCode": "M_PESA_TZ",
          "displayName": "M-Pesa Tanzania",
          "rail": "MOBILE_MONEY",
          "countryCode": "TZ",
          "currency": "TZS",
          "operationCodes": ["COLLECTION_REQUEST", "DISBURSEMENT_REQUEST"],
          "status": "INACTIVE",
          "priority": 20,
          "requires": { "msisdn": true }
        },
        {
          "capabilityCode": "AIRTEL_MONEY_TZ",
          "displayName": "Airtel Money Tanzania",
          "rail": "MOBILE_MONEY",
          "countryCode": "TZ",
          "currency": "TZS",
          "operationCodes": ["COLLECTION_REQUEST", "DISBURSEMENT_REQUEST"],
          "status": "INACTIVE",
          "priority": 30,
          "requires": { "msisdn": true }
        }
      ],
      "priority": 40,
      "metadata": {
        "environment": "sandbox",
        "sponsor_model": "partner_bank"
      }
    }
  ]
}
```

Production ISO 20022 partner profile example:

```json
{
  "mode": "preview",
  "partnerBanks": [
    {
      "partnerCode": "ORBI_TIPS_PARTNER",
      "name": "ORBI Partner Bank TIPS Switch",
      "status": "ACTIVE",
      "payGatewayProviderCode": "tips-partner-bank",
      "clearingNetwork": "TIPS",
      "messageStandard": "ISO20022",
      "iso20022Profile": "tips-iso20022-pacs-v1",
      "settlementModel": "REALTIME_GROSS",
      "participantId": "ORBI",
      "sponsoredParticipantId": "PARTNER_BANK_PARTICIPANT_ID",
      "supportedCurrencies": ["TZS"],
      "countries": ["TZ"],
      "operations": [
        "COLLECTION_REQUEST",
        "DISBURSEMENT_REQUEST",
        "REVERSAL_REQUEST",
        "BENEFICIARY_VALIDATE"
      ],
      "priority": 30
    }
  ]
}
```

Backend normalization converts each `partnerBanks[]` item into:

- A `financial_partners` record with `provider_metadata.registry_kind = UNIVERSAL_SWITCH`.
- A `provider_config_versions` record that points to `ORBI_PAY_GATEWAY_BASE_URL`.
- Auto-generated `provider_routing_rules` for every submitted country, currency, and operation.
- `payment_rail_capabilities` rows for only the manually submitted consumer-visible options, such as M-Pesa, Airtel Money, Tigo Pesa, HaloPesa, or TIPS bank transfer.
- Pay Gateway provider routing through `provider_metadata.pay_gateway_provider_code`.

Operational rule:

- ORBI Core does not create default downstream payment options. Operators must add each mobile-visible rail in the Configuration Studio with a stable code, display name, currency, rail type, status, limits, and required fields.
- Removing a downstream capability from the latest partner-bank configuration payload soft-retires it by setting it `INACTIVE`; this preserves audit/history while removing it from mobile payment method discovery.
- Keep partner bank profiles `INACTIVE` until sandbox credentials, callback validation, settlement reconciliation, and risk controls are confirmed.
- Use `messageStandard = PROVIDER_NATIVE` for early bank sandbox APIs that are not ISO 20022 yet.
- Use `messageStandard = ISO20022` only when the Pay Gateway profile has certified ISO 20022 mapping and clearing-network rules.
- Never store bank credentials in this bootstrap payload. Secrets belong in Pay Gateway environment/configuration and tokenized provider manifests.
- Consumer apps must load selectable methods from `GET /v1/payment-methods`; they must not hardcode M-Pesa, Airtel, or bank lists.

## Preview Console UI

The admin screen should have three panels:

1. `Input Fields`
2. `Generated JSON`
3. `Backend Preview`

`Generated JSON` should be manually editable. If the operator edits JSON, frontend should parse it and use that edited payload for preview/commit.

Recommended actions:

- `Generate JSON`
- `Copy JSON`
- `Load FX example`
- `Load Provider example`
- `Preview backend write plan`
- `Apply configuration`

The preview result should show:

- FX rates to be written.
- FX fee row to be inserted/updated.
- Provider records to be inserted/updated.
- Provider secrets detected but masked.
- Routing rules to be inserted/updated.
- Validation warnings.
- Blocking errors.

## Backend Save Responsibilities

The backend handler should perform this sequence:

1. Validate admin session and permission.
2. Normalize currency codes, provider codes, rails, operation codes, and status.
3. Validate FX rates are positive numbers.
4. Validate `USD = 1`.
5. Validate fee rates are decimals, not whole percent values.
6. FX market rates are not manually edited. The transaction path uses `LiquidityProviderAdapter`; admin UI should manage `fx_margin_policies` only.
7. Upsert `platform_fee_configs` row where `flow_code = 'FX_CONVERSION'` and name matches the submitted fee name.
8. For each provider, normalize into `financial_partners`.
9. Encrypt or wrap provider secrets using existing provider secret handling.
10. Write provider mapping into `mapping_config` and `provider_metadata`.
11. Create a `provider_config_versions` row.
12. Upsert `provider_routing_rules`.
13. Clear or invalidate relevant config caches.
14. Return a structured result.

## Suggested Backend Service Skeleton

Create:

```text
backend/admin/AdminConfigBootstrapService.ts
```

Suggested public method:

```ts
type BootstrapMode = 'preview' | 'commit';

export class AdminConfigBootstrapService {
  async apply(payload: any, actorId: string) {
    const normalized = this.normalize(payload);
    const plan = await this.buildWritePlan(normalized, actorId);

    if (normalized.mode !== 'commit') {
      return {
        success: true,
        mode: 'preview',
        plan,
      };
    }

    const result = await this.commit(plan, actorId);
    return {
      success: true,
      mode: 'commit',
      result,
    };
  }
}
```

Implemented route:

```ts
admin.post(
  '/config/bootstrap',
  requireSessionPermission(
    ['provider.write', 'provider_routing.write', 'platform_fee.write', 'infra_config.write'],
    ['ADMIN', 'SUPER_ADMIN', 'IT'],
  ),
  async (req, res) => {
    try {
      const actorId = (req as any).session?.sub;
      const data = await AdminConfigBootstrapService.apply(req.body, actorId);
      res.json({ success: true, data });
    } catch (e: any) {
      res.status(400).json({
        success: false,
        error: e.message,
      });
    }
  }
);
```

## Backend Write Mapping

### FX rates

Save to:

```text
fx_margin_policies
Do not write market rates to infra_system_matrix.FX_RATES.
Admins configure spread_mode, margin_bps, risk_buffer_bps, quote_lock_seconds, and optional min/max amount windows.
```

### FX fee

Save to:

```text
platform_fee_configs
```

With normalized fields:

```json
{
  "name": "Default FX conversion fee",
  "flow_code": "FX_CONVERSION",
  "transaction_model": "FX_CONVERSION",
  "transaction_type": "FX_CONVERSION",
  "operation_type": "FX_CONVERSION",
  "direction": "INTERNAL_TO_INTERNAL",
  "rail": "WALLET",
  "currency": null,
  "percentage_rate": 0.01,
  "fixed_amount": 0,
  "minimum_fee": 0,
  "maximum_fee": null,
  "tax_rate": 0,
  "gov_fee_rate": 0,
  "stamp_duty_fixed": 0,
  "priority": 100,
  "status": "ACTIVE"
}
```

### Provider

Save to:

```text
financial_partners
```

Core fields:

```json
{
  "name": "Vodacom M-Pesa",
  "type": "mobile_money",
  "supported_currencies": ["TZS"],
  "api_base_url": "https://provider.example.com",
  "logic_type": "REGISTRY",
  "status": "ACTIVE"
}
```

Provider metadata should include:

```json
{
  "provider_code": "MPESA_TZ",
  "rail": "MOBILE_MONEY",
  "operations": ["COLLECTION_REQUEST", "DISBURSEMENT_REQUEST"],
  "supports_webhooks": true,
  "callback_config": {
    "COLLECTION_REQUEST": {
      "path": "/webhooks/mpesa",
      "reference_field": "transaction_id",
      "status_field": "status"
    },
    "DISBURSEMENT_REQUEST": {
      "path": "/webhooks/mpesa",
      "reference_field": "transaction_id",
      "status_field": "status"
    }
  }
}
```

Mapping config should include:

```json
{
  "service_root": "https://provider.example.com",
  "operations": {
    "COLLECTION_REQUEST": {
      "method": "POST",
      "path": "/collections",
      "request_template": {
        "amount": "{{amount}}",
        "currency": "{{currency}}",
        "phone": "{{recipient.phone}}",
        "reference": "{{reference}}"
      },
      "response_mapping": {
        "providerRef": "data.transaction_id",
        "status": "data.status",
        "message": "message"
      }
    }
  }
}
```

Routing rules save to:

```text
provider_routing_rules
```

## Example Frontend Fetch

```ts
async function previewConfig(payload: unknown, token: string) {
  const response = await fetch('/api/admin/config/bootstrap', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ ...payload, mode: 'preview' }),
  });

  return response.json();
}

async function applyConfig(payload: unknown, token: string) {
  const response = await fetch('/api/admin/config/bootstrap', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ ...payload, mode: 'commit' }),
  });

  return response.json();
}
```

## Validation Rules

Blocking errors:

- `USD` rate missing or not `1`.
- Any FX rate is zero or negative.
- Fee percentage is greater than `0.5` unless `confirmHighFee = true`.
- Provider active but missing provider code.
- Provider active but missing rail.
- Provider active but missing service root/API base URL.
- Provider active but has no operations.
- Provider operation missing callback config when webhooks are required.
- Routing rule points to provider not in payload or not found in DB.

Warnings:

- Fee is zero. This is allowed for testing but should be visible.
- Provider status is `DRAFT`; routing rules will not be production-active.
- No maximum fee cap.
- Secrets are present in preview and will be masked.

## Recommended UI Copy

Button labels:

- `Preview configuration`
- `Apply configuration`
- `Copy JSON`
- `Load example`
- `Reset form`

Console labels:

- `Generated setup JSON`
- `Backend write plan`
- `Validation messages`
- `Masked secrets`

Safety prompt before commit:

```text
This will update live backend configuration used by transaction previews, FX quotes, provider routing, and settlement. Continue?
```

## Minimal Implementation Path

If we want the fastest safe version:

1. Build UI fields for FX rates and FX fee only.
2. POST to existing:
   - `POST /v1/admin/config/fx-rates`
   - Existing platform fee config route, if exposed.
3. Then add provider setup using:
   - `POST /api/admin/partners`
   - `POST /api/admin/provider-routing-rules`

Best long-term version:

1. Add `POST /api/admin/config/bootstrap`.
2. Frontend sends one payload.
3. Backend saves FX, fee, provider, and routing atomically where possible.
4. Frontend shows preview plan before commit.
