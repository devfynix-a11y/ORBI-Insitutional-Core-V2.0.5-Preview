# ORBI Mobile GraphQL Read Model

## Purpose

The mobile GraphQL endpoint is a read-optimized API for app boot, dashboard refresh, transaction history, wealth summary, and PaySafe status views.

It exists to reduce mobile round trips. It does not replace audited financial write flows.

## Endpoint

```http
POST /v1/graphql
POST /api/v1/graphql
GET  /v1/graphql/schema
GET  /api/v1/graphql/schema
```

All requests require the normal authenticated mobile session.

## Safety Rules

- GraphQL is read-only.
- Mutations are rejected.
- Financial actions must continue using the audited REST flows with idempotency keys, quote binding, challenge handling, and ledger controls.
- Query limits are capped server-side to protect mobile and database performance.
- Every resolver filters by the authenticated user session.

## Mobile Snapshot Example

```graphql
query MobileBoot {
  mobileSnapshot(
    dashboard: true
    transactions: true
    wealthSummary: true
    paySafeEscrows: true
    transactionLimit: 20
    escrowLimit: 20
  ) {
    dashboard
    transactions
    wealthSummary
    paySafeEscrows
  }
}
```

## Focused Reads

```graphql
query RecentTransactions {
  transactions(limit: 50, offset: 0)
}
```

```graphql
query ActivePaySafe {
  paySafeEscrows(limit: 20, status: "HELD")
}
```

```graphql
query WealthSummary {
  wealthSummary
}
```

## Database Performance Contract

The main SQL includes mobile read indexes for:

- `transactions(user_id, created_at DESC)`
- `transactions(user_id, status, created_at DESC)`
- `transaction_quotes(user_id, status, updated_at DESC)`
- `financial_ledger(user_id, created_at DESC)`
- `platform_vaults(user_id, vault_role, updated_at DESC)`
- `wallets(user_id, management_tier, updated_at DESC)`
- `escrow_agreements(sender_id, status, created_at DESC)`
- `escrow_agreements(receiver_id, status, created_at DESC)`
- Wealth read tables such as goals, categories, bill reserves, shared pots, and shared budgets.

These indexes support fast app snapshots without weakening financial reconciliation.
