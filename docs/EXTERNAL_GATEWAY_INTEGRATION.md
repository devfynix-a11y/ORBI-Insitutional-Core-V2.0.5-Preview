# External Gateway Integration

This app now includes a dedicated client for the backend gateway flow used by real external provider integrations such as banks, mobile money, and card processors.

## Files

- `lib/features/payment/data/gateway_payment_service.dart`
- `lib/features/payment/data/gateway_payment_models.dart`
- `lib/core/config/app_config.dart`

## Backend Contract Read From

- `D:\FYNIX\SYSTEM ISSUES\backend\payments\PROVIDER_REGISTRY_INTEGRATION.md`
- `C:\Users\danie\Downloads\ORBI-Insitutional-Core-V2.0.4-Preview Stable\backend\payments\gatewayRoutes.ts`

## Important Backend Reality

The markdown guide mentions `provider_type` values like `MPESA` or `STRIPE`, but the actual backend route implementation currently loads providers by:

- `GET /v1/gateway/providers` -> returns provider `id`
- `POST /v1/gateway/payment/initiate` -> expects `providerId`
- backend query: `financial_partners.id = providerId`

That means the mobile app should use the provider `id` returned by `/gateway/providers`, not just the human name or type.

## Mobile Flow

1. Call `listProviders()`
2. Let the user choose a provider
3. Collect the provider-specific `paymentMethodId`
4. Call `initiatePayment(...)`
5. Call `settlePayment(...)` with the chosen ORBI wallet
6. Poll `getSettlementStatus(...)`
7. If needed, call `confirmSettlement(...)` or `disputeSettlement(...)`

## Example

```dart
final gateway = GatewayPaymentService();

final providers = await gateway.listProviders();
final provider = providers.first;

final initiated = await gateway.initiatePayment(
  providerId: provider.id,
  paymentMethodId: '255712345678',
  amount: 50000,
  currency: 'TZS',
  description: 'Wallet funding',
);

final settlement = await gateway.settlePayment(
  orderId: initiated.orderId,
  providerId: provider.id,
  targetWalletId: 'wallet-uuid-here',
  autoSettleMinutes: 5,
);

final status = await gateway.getSettlementStatus(settlement.settlementId);
```

## Current Scope

This work adds the mobile integration layer only. It does not yet replace the existing outbound transfer screen because that screen uses a different backend path and business meaning.
