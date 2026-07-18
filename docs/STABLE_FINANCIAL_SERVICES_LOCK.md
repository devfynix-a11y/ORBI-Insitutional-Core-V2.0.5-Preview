# Stable Financial Services Lock

## Locked Services

The following mobile services are considered stable and should not be modified casually:

- P2P send money flow
- Transaction history UI and report flow
- Single transaction receipt preview, print, and share flow
- Receipt/report money formatting and audit labels

## Engineering Rule

Do not refactor, rename, simplify, or reuse these flows for unrelated feature work.
Any change that touches these services must be intentional, reviewed, and tested end to end.

## Required Checks Before Any Future Change

- Confirm the change is directly related to P2P, transaction history, or receipts.
- Verify preview, settle, receipt preview, PDF/print/share, and transaction history still work.
- Confirm financial labels remain user-friendly and audit-safe.
- Avoid fallback logic that can hide missing financial data.

## Current Status

As of 2026-07-16, P2P, transaction history, and receipt flows are treated as complete and protected.
