# Provider Adapter Architecture

## Purpose

Provider execution is now formalized around a registry-driven adapter architecture.
The goal is to keep `financial_partners` and `provider_routing_rules` intact while removing hardcoded provider behavior and normalizing execution across mobile money, bank, card, crypto, and universal switch rails.

The preferred production direction is universal switch registration, not one-provider-at-a-time onboarding. ORBI Core routes to a switch or clearing profile. ORBI Pay Gateway handles ISO 20022/ISO8583/provider-native execution.

## Core Model

Runtime provider execution now flows through these layers:

1. `ProviderSelectionService`
2. `ProviderRoutingService`
3. `ProviderFactory`
4. `IProviderAdapter`
5. `GenericRestProvider`

This keeps provider selection separate from provider execution.

## Source Of Configuration

Execution remains registry-driven from existing models:

- `financial_partners`
- `provider_routing_rules`
- `payment_rail_capabilities`
- `financial_partners.provider_metadata`
- `financial_partners.mapping_config`

No runtime path should depend on hardcoded Airtel-style assumptions.

`payment_rail_capabilities` is the consumer-visible option registry. It is where ORBI publishes operator-configured choices such as:

- `M_PESA_TZ`
- `AIRTEL_MONEY_TZ`
- `TIGO_PESA_TZ`
- `HALOPESA_TZ`
- `TIPS_BANK_TRANSFER_TZ`

These are examples, not defaults. Each capability must be created manually in the Configuration Studio or submitted through the partner-bank bootstrap payload with its display name, rail type, currency, status, limits, required fields, and optional Pay Gateway capability mapping.

Each capability is attached to a parent `financial_partners` switch profile, for example `NMB_SPONSORED_TIPS`. The mobile app displays the capability `display_name`, but Core routes execution through the parent partner/switch profile and ORBI Pay Gateway.

`financial_partners` is now treated as an external rail registry. Rows can represent:

- `EXTERNAL_PROVIDER`
- `UNIVERSAL_SWITCH`
- `CLEARING_NETWORK`

This keeps DB compatibility while allowing TIPS and future regional/global switch expansion.

## Normalized Contracts

Formal request/response contracts live in:

- `backend/payments/providers/types.ts`

Key contracts:

- `ProviderExecutionRequest`
- `ProviderExecutionResponse`
- `ProviderCapabilityDescriptor`
- `NormalizedProviderError`

This means provider adapters execute by normalized operation codes such as:

- `COLLECTION_REQUEST`
- `DISBURSEMENT_REQUEST`
- `BALANCE_INQUIRY`

Legacy names like `stkPush` and `disburse` remain compatibility shims only.

## Capability Descriptors

Provider capabilities are derived through:

- `backend/payments/ProviderCapabilityService.ts`

Capabilities describe:

- provider category
- rail
- registry kind
- message standard
- clearing network
- switch profile code
- supported operations
- webhook/polling support
- supported currencies and countries
- routing priority hints

`mobile_money` is treated as a generic provider category, not a named-provider implementation.

For ISO 20022 switch profiles, `ProviderCapabilityService` exposes:

- `registryKind = UNIVERSAL_SWITCH`
- `messageStandard = ISO20022`
- `clearingNetwork = TIPS`
- `payGatewayProviderCode = tips-neighbor-bank`

## Routing Selection

Routing selection is formalized through:

- `backend/payments/ProviderSelectionService.ts`
- `backend/payments/ProviderRoutingService.ts`

The selection service wraps the existing routing model and produces a normalized provider selection result without changing the storage model.

Consumer/mobile selection flow:

1. Mobile calls `GET /v1/payment-methods?countryCode=TZ&currency=TZS&rail=MOBILE_MONEY&operation=COLLECTION_REQUEST`.
2. Core returns active payment rail capabilities only.
3. User selects a capability such as `M_PESA_TZ`.
4. Mobile sends `preferredProviderCode = M_PESA_TZ` during preview/settlement.
5. `ProviderRoutingService` resolves `M_PESA_TZ` to the parent switch partner and records the selected capability in the routing decision metadata.
6. ORBI Core remains ledger/risk authority. ORBI Pay Gateway remains execution authority.

## Error Normalization

Provider errors are normalized through:

- `backend/payments/providers/ProviderErrorNormalizer.ts`

The normalization layer converts raw transport/provider faults into stable categories such as:

- `AUTH`
- `CONFIG`
- `NETWORK`
- `TIMEOUT`
- `RATE_LIMIT`
- `UNAVAILABLE`
- `REJECTED`
- `INVALID_RESPONSE`

## Retry And Failover Hooks

Retry handling is centralized in:

- `backend/payments/providers/ProviderRetryPolicy.ts`

The retry policy now supports hooks for:

- retry observation
- exhaustion handling
- failover candidate resolution

This creates a safe extension point for future provider failover without changing the adapter contract.

## Migration Guidance

When touching provider execution code:

- prefer `execute(partner, request)` over provider-specific methods
- treat capability descriptors as the runtime description of what a provider can do
- route first, then execute
- normalize errors before surfacing them to upstream services
- keep raw provider payloads as diagnostics, not business authority

## Current Compatibility Boundary

The architecture is formalized, but some compatibility shims still exist to preserve current behavior during migration.
Those shims should be treated as transitional and should not be used by new code.
