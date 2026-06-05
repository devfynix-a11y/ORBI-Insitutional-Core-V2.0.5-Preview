# External Rail Registry Contract

The ORBI backend uses a dynamic external rail registry stored in `financial_partners`.
The table name is retained for database compatibility, but the business meaning is broader:

- direct external provider profiles
- universal switch profiles
- clearing network profiles

ORBI Core should not onboard every mobile money or bank provider one by one when a regulated switch path can cover the same network. For TIPS and future East African/global pipelines, Core should register a universal switch profile and let ORBI Pay Gateway execute ISO 20022 rail messaging.

## Core Fields

- `name`: operator or provider display label
- `type`: `mobile_money` | `bank` | `card` | `crypto`
- `logic_type`: `REGISTRY` | `GENERIC_REST` | `SPECIALIZED`
- `status`: `ACTIVE` | `INACTIVE` | `MAINTENANCE`
- `api_base_url`: provider base URL
- `mapping_config`: auth, request, response, webhook, and balance registry config
- `provider_metadata`: UI and product metadata

## Registry Kinds

`provider_metadata.registry_kind` defines how Core should understand the row:

- `EXTERNAL_PROVIDER`: a specific provider profile, usually legacy or direct-provider integration.
- `UNIVERSAL_SWITCH`: a switch profile that can reach many banks/wallets through one clearing participant.
- `CLEARING_NETWORK`: a scheme/network profile such as TIPS, EAPS, RTGS, ACH, or a card switch.

For new production bank/switch expansion, prefer `UNIVERSAL_SWITCH` or `CLEARING_NETWORK`.

## Current Routing Model

The backend now supports registry resolution by:

- `rail`
- `operation`
- `country`
- `currency`
- `priority`

Primary routing source:

- `provider_routing_rules`

Fallback routing source:

- `financial_partners.provider_metadata`
- `financial_partners.mapping_config`

## provider_metadata

Supported UI/product fields:

- `registry_kind`: `EXTERNAL_PROVIDER` | `UNIVERSAL_SWITCH` | `CLEARING_NETWORK`
- `message_standard`: `PROVIDER_NATIVE` | `ISO20022` | `ISO8583` | `CUSTOM`
- `clearing_network`: `TIPS`, `EAPS`, `RTGS`, `ACH`, `CARD_SWITCH`, `SWIFT`, or partner-specific code
- `switch_profile_code`: Core-facing switch profile code
- `pay_gateway_provider_code`: provider code configured in ORBI Pay Gateway manifest
- `participant_id`: ORBI or sponsored participant ID
- `sponsored_participant_id`: neighbor bank/sponsor participant ID
- `iso20022_profile`: ISO 20022 implementation profile/version
- `settlement_model`: `REALTIME_GROSS`, `DEFERRED_NET`, `BATCH`, or `HYBRID`
- `group`: `Mobile` | `Bank` | `Gateways` | `Crypto`
- `rail`: `MOBILE_MONEY` | `BANK` | `CARD_GATEWAY` | `CRYPTO` | `WALLET`
- `brand_name`: provider-facing brand label
- `display_name`: optional frontend label override
- `display_icon`: icon URL or asset reference
- `color`: brand accent color
- `checkout_mode`: `redirect` | `embedded` | `tokenized` | `server_to_server` | `ussd` | `stk_push` | `manual`
- `channels`: array of
  - `bank_transfer`
  - `bank_account`
  - `mobile_money`
  - `card`
  - `paypal`
  - `crypto`
  - `ussd`
  - `qr`
  - `checkout_link`
- `sort_order`: numeric ordering value
- `region`: primary region label
- `currency`: primary currency
- `countries`: supported country codes
- `capabilities`: free-form capability labels
- `operations`: supported ORBI money operations
- `routing_priority`: default provider selection priority
- `provider_code`: stable registry-facing provider code
- `supports_webhooks`: callback capability flag
- `supports_polling`: polling capability flag

## Grouping Rules

Gateway provider listing resolves group in this order:

1. `provider_metadata.group`
2. normalized provider `type`
3. fallback to `Gateways`

This means Stripe, PayPal, and similar processors can be stored with:

- `type = "card"` or another supported execution type
- `provider_metadata.group = "Gateways"`

## mapping_config

The backend currently supports these registry execution fields:

- `service_root`
- `service_roots`
- `auth`
- `operations`
- `stk_push`
- `disbursement`
- `check_status`
- `balance`
- `callback`

Recommended direction:

- new integrations should prefer `operations`
- legacy compatibility can still use `stk_push`, `disbursement`, and `balance`

Example operation-aware registry layout:

```json
{
  "service_root": "https://provider.example.com",
  "service_roots": {
    "auth": "https://auth.provider.example.com",
    "stk_push": "https://collections.provider.example.com"
  },
  "operations": {
    "COLLECTION_REQUEST": {
      "url": "/collections",
      "method": "POST"
    },
    "DISBURSEMENT_REQUEST": {
      "url": "/disbursements",
      "method": "POST"
    },
    "BALANCE_INQUIRY": {
      "url": "/balances",
      "method": "GET"
    }
  },
  "callback": {
    "reference_field": "transaction.id",
    "status_field": "transaction.status"
  }
}
```

Example ISO 20022/TIPS universal switch profile:

```json
{
  "name": "TIPS Universal Switch",
  "type": "bank",
  "logic_type": "REGISTRY",
  "status": "ACTIVE",
  "api_base_url": "https://pay.orbifinancial.com",
  "supported_currencies": ["TZS"],
  "provider_metadata": {
    "registry_kind": "UNIVERSAL_SWITCH",
    "message_standard": "ISO20022",
    "clearing_network": "TIPS",
    "switch_profile_code": "tips-neighbor-bank",
    "pay_gateway_provider_code": "tips-neighbor-bank",
    "provider_code": "tips-neighbor-bank",
    "rail": "BANK",
    "countries": ["TZ"],
    "operations": ["COLLECTION_REQUEST", "DISBURSEMENT_REQUEST", "REVERSAL_REQUEST"],
    "iso20022_profile": "tips-iso20022-pacs-v1",
    "settlement_model": "REALTIME_GROSS"
  },
  "mapping_config": {
    "service_root": "https://pay.orbifinancial.com",
    "operations": {
      "COLLECTION_REQUEST": { "method": "POST", "url": "/v1/collections" },
      "DISBURSEMENT_REQUEST": { "method": "POST", "url": "/v1/payouts" },
      "REVERSAL_REQUEST": { "method": "POST", "url": "/v1/refunds" }
    }
  }
}
```

Core routes to this switch profile. ORBI Pay Gateway maps the request to ISO 20022 and communicates with the neighbor bank or clearing network.

Example NMB OBP sandbox profile:

```json
{
  "name": "NMB OBP Sandbox",
  "type": "bank",
  "logic_type": "REGISTRY",
  "status": "ACTIVE",
  "api_base_url": "https://pay.orbifinancial.com",
  "supported_currencies": ["TZS"],
  "provider_metadata": {
    "registry_kind": "UNIVERSAL_SWITCH",
    "message_standard": "PROVIDER_NATIVE",
    "clearing_network": "NMB_OBP_SANDBOX",
    "switch_profile_code": "nmb-obp-sandbox",
    "pay_gateway_provider_code": "nmb-obp-sandbox",
    "provider_code": "nmb-obp-sandbox",
    "rail": "BANK",
    "countries": ["TZ"],
    "operations": ["COLLECTION_REQUEST", "DISBURSEMENT_REQUEST", "REVERSAL_REQUEST"],
    "settlement_model": "SANDBOX"
  },
  "mapping_config": {
    "service_root": "https://pay.orbifinancial.com",
    "operations": {
      "COLLECTION_REQUEST": { "method": "POST", "url": "/v1/collections" },
      "DISBURSEMENT_REQUEST": { "method": "POST", "url": "/v1/payouts" },
      "REVERSAL_REQUEST": { "method": "POST", "url": "/v1/refunds" }
    }
  }
}
```

Use this for NMB sandbox validation only. Production TIPS/NMB sponsored participant access should use a separate ISO 20022 profile after bank certification.

## API Output

`GET /v1/gateway/providers` returns normalized fields:

- `id`
- `name`
- `brandName`
- `type`
- `group`
- `logicType`
- `status`
- `supportedCurrencies`
- `icon`
- `color`
- `checkoutMode`
- `channels`
- `sortOrder`
- `metadata`
