# ORBI Platform Operational Accounts

Platform operational accounts are ORBI-owned ledger accounts used for closed-loop platform money movement. They are stored in `platform_vaults` with `metadata.is_platform_operational_account=true` and must never be treated as manually editable balances.

## Financial Invariants

- Every movement must post balanced double-entry ledger legs.
- Staff, agents, admins, and support users must not directly update account balances.
- Funding an operational account requires a source wallet or vault.
- Payouts and refunds debit the operational account and credit the destination wallet or vault.
- Refunds must reference the original transaction ID or original reference ID.
- Escrow refunds must reverse the original ledger transaction instead of changing status only.
- Cached balances are derived from authoritative ledger mutations and are repairable through controlled reconciliation, not manual edits.

## Account Roles

Supported roles:

- `MAIN_COLLECTION`
- `FEE_COLLECTION`
- `TAX_COLLECTION`
- `SALARY`
- `PLATFORM_FUNDING`
- `REFUND_RESERVE`
- `CHARGEBACK_RESERVE`
- `PROVIDER_SETTLEMENT`
- `ESCROW_RESERVE`
- `OPERATING_RESERVE`
- `CUSTOM`

Example uses:

- Salary payments: fund a `SALARY` operational account from `PLATFORM_FUNDING`, then payout to staff wallets through ledger transactions.
- Refund handling: debit `REFUND_RESERVE` and credit the customer wallet, referencing the original payment transaction.
- Provider settlement: move collections into `PROVIDER_SETTLEMENT` before external settlement workflows.

## Admin API

All routes are under `/api/admin` and require admin session auth.

```http
GET /api/admin/platform-operational-accounts
POST /api/admin/platform-operational-accounts
PATCH /api/admin/platform-operational-accounts/:id
GET /api/admin/platform-operational-accounts/:id/ledger
POST /api/admin/platform-operational-accounts/:id/fund
POST /api/admin/platform-operational-accounts/:id/payout
POST /api/admin/platform-operational-accounts/:id/refund
```

Funding payload:

```json
{
  "sourceWalletId": "source-wallet-or-vault-id",
  "amount": 100000,
  "currency": "TZS",
  "reason": "Move approved platform operating capital into salary account"
}
```

Payout payload:

```json
{
  "targetWalletId": "target-wallet-or-vault-id",
  "amount": 25000,
  "currency": "TZS",
  "reason": "Approved staff salary payout batch 2026-05"
}
```

Refund payload:

```json
{
  "targetWalletId": "customer-wallet-id",
  "amount": 5000,
  "currency": "TZS",
  "reason": "Refund approved after support case review",
  "originalTransactionId": "original-transaction-id"
}
```

## Controls

- Create/update accounts: `ADMIN`, `SUPER_ADMIN`, `IT`.
- Ledger/history viewing: `ADMIN`, `SUPER_ADMIN`, `IT`, `ACCOUNTANT`, `AUDIT`.
- Funding/payout/refund: `ADMIN`, `SUPER_ADMIN`.
- Sensitive mutation rate limiting applies to fund, payout, refund, and account mutation paths.
- All movements produce financial audit events with actor ID, account ID, amount, currency, transaction ID, and reference ID.

## UI Requirements

- Never show an editable balance field.
- Show ledger history and reconciliation state for each operational account.
- Require reason text and confirmation for all fund, payout, and refund actions.
- Require original transaction/reference for refunds.
- Show source and destination account summaries before commit.
- Show resulting transaction ID and audit trail link after success.
