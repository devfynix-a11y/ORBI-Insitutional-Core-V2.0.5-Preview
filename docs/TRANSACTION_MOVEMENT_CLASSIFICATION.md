# Transaction Movement Classification

**Classification**: FINANCIAL CORE / READ MODEL ARCHITECTURE  
**Last Updated**: 2026-07-15

This document is the canonical contract for how ORBI classifies transaction
movements for history, reports, receipts, reconciliation views, and
customer-facing labels.

The accounting ledger remains the financial source of truth. Movement
classification is a read/business interpretation layer built on top of ledger
legs, wallet metadata, and transaction metadata. It must not mutate balances,
replay ledger entries, or replace ledger invariants.

## Architecture Decision

ORBI separates financial truth from business presentation:

- **Ledger** answers: what happened financially?
- **Movement classification** answers: what kind of movement was this?
- **Display resolution** answers: what should the customer or auditor see?

This avoids the old pattern where individual screens, reports, or route helpers
try to infer meaning independently. All clients should consume the same
classification contract instead of rebuilding their own rules.

## Design Principles

- Keep ledger posting boring, atomic, and untouched by UI/report wording.
- Keep movement naming in one classifier module, not scattered helper logic.
- Prefer deterministic IDs and wallet ownership over description text.
- Treat PaySafe, Escrow, Fungu, Mezani, goals, budgets, and reserves as
  internal ORBI services unless the money leaves ORBI through an external rail.
- Always expose machine-readable classification fields alongside display names
  so mobile, reports, and audit tools do not guess.

## Module Structure

Canonical implementation:

- `backend/transactions/movement/types.ts`
- `backend/transactions/movement/movementRules.ts`
- `backend/transactions/movement/TransactionMovementClassifier.ts`

Consumers:

- `ledger/transactionService.ts`
- `src/routes/public/coreFinance.ts`

The classifier is intentionally separated from ledger write paths. Ledger
services may import it for read responses, but ledger commit logic must not
depend on display labels or report categories.

## Boundary Contract

The classifier may read:

- transaction IDs and metadata
- ledger legs
- wallet ownership and wallet role metadata
- product identifiers such as `shared_pot_id`, `shared_budget_id`, and escrow
  identifiers

The classifier must not:

- write ledger entries
- update wallet balances
- finalize settlement
- change transaction state
- infer accounting truth from labels only
- hide raw ledger legs from audit views

## Movement Families

| Family | Meaning | Examples |
| :--- | :--- | :--- |
| `INTERNAL_P2P` | Money moves between two different ORBI users/accounts. | Daniel sends money to Catherine. |
| `INTERNAL_SS` | Money remains inside ORBI but moves through a self-service product or internal bucket. | PaySafe escrow, Fungu contribution, Fungu withdrawal, Mezani allocation, goal/budget movement. |
| `EXTERNAL` | Money enters or leaves ORBI through an external rail. | Bank payout, mobile money cashout, card rail, provider settlement. |
| `UNKNOWN` | The movement could not be classified deterministically. | Legacy or malformed transaction with insufficient ledger/wallet context. |

## Movement Codes

Current codes include:

| Code | Family | Meaning |
| :--- | :--- | :--- |
| `P2P_TRANSFER` | `INTERNAL_P2P` | Internal transfer between different ORBI identities. |
| `SS_PAYSAFE_ESCROW` | `INTERNAL_SS` | PaySafe or escrow hold movement. |
| `SS_PAYSAFE_RELEASE` | `INTERNAL_SS` | PaySafe or escrow release movement. |
| `SS_PAYSAFE_REFUND` | `INTERNAL_SS` | PaySafe or escrow refund movement. |
| `SS_SHARED_POT_CONTRIBUTION` | `INTERNAL_SS` | Fungu/shared pot contribution. |
| `SS_SHARED_POT_WITHDRAWAL` | `INTERNAL_SS` | Fungu/shared pot withdrawal. |
| `SS_SHARED_BUDGET_MOVEMENT` | `INTERNAL_SS` | Mezani/shared budget movement. |
| `SS_INTERNAL_REALLOCATION` | `INTERNAL_SS` | Same owner internal reallocation. |
| `SS_INTERNAL_MOVEMENT` | `INTERNAL_SS` | Generic internal multi-leg movement. |
| `EXTERNAL_DEPOSIT` | `EXTERNAL` | External-to-ORBI money in. |
| `EXTERNAL_WITHDRAWAL` | `EXTERNAL` | ORBI-to-external money out. |
| `UNKNOWN_MOVEMENT` | `UNKNOWN` | Not enough deterministic context. |

## Response Contract

Transaction history, transaction detail, and transaction reports should include:

```json
{
  "movement_family": "INTERNAL_P2P",
  "movement_code": "P2P_TRANSFER",
  "movement_group": "Internal P2P movement",
  "movement_classification": {
    "movement_family": "INTERNAL_P2P",
    "movement_code": "P2P_TRANSFER",
    "movement_group": "Internal P2P movement",
    "source_context": "ORBI",
    "destination_context": "INTERNAL_P2P",
    "is_internal": true,
    "is_self_service": false,
    "is_p2p": true,
    "is_external": false
  }
}
```

These fields may also be copied into response metadata for compatibility with
older clients.

## Versioning

Movement families are stable public categories. New product behavior should add
a `movement_code` before adding a new `movement_family`.

Safe changes:

- add a new `movement_code`
- improve source/destination display resolution
- add richer classification metadata

Breaking changes:

- renaming a `movement_family`
- changing the financial boundary of an existing family
- removing fields from the response contract

If a breaking change is unavoidable, introduce a versioned classifier contract
instead of changing the existing one silently.

## Display Guidance

Customer-facing history should use the movement classification as context, then
resolve names from authoritative source/destination wallet and user data.

- `INTERNAL_P2P`: show the real sender and recipient identities.
- `INTERNAL_SS`: show the service name and service object, for example
  `Fungu: Ada ya Shule` or `PaySafe`.
- `EXTERNAL`: show the external rail/provider/destination where available.

Avoid labels such as `Escrow Vault` as the final recipient when the vault is
only an intermediate accounting bucket. The vault can appear in audit details,
but customer history should show the true business destination.

## Balance Rules

General transaction history must show the operating wallet balance after the
movement. Product-specific reports may show product balances:

- General transaction history: operating/main wallet balance after the movement.
- Fungu report: Fungu balance after the contribution/withdrawal.
- PaySafe/Escrow report: escrow or PaySafe held/released/refunded balance.
- Mezani/goals/budgets reports: the relevant service balance.

This prevents internal vault legs from corrupting the customer's main balance
view while preserving auditability in product-specific contexts.

## Operational Rule

When adding a new financial product:

1. Add a new movement code in `TransactionMovementClassifier`.
2. Keep the family stable unless the money truly changes boundary.
3. Do not infer financial meaning from human description text if IDs or wallet
   ownership are available.
4. Do not alter ledger posting just to change reports or UI labels.
5. Add tests or smoke checks for history, detail, and report output.

## Example Interpretation

For a PaySafe-backed internal transfer from Daniel to Catherine:

- ledger may contain intermediate PaySafe vault legs
- movement family should remain `INTERNAL_P2P`
- customer history should show Daniel as sender and Catherine as recipient
- audit details may still expose PaySafe vault legs
- general balance after should be Daniel's operating wallet balance after the
  movement, not the PaySafe vault balance

For a Fungu contribution:

- movement family should be `INTERNAL_SS`
- movement code should be `SS_SHARED_POT_CONTRIBUTION`
- customer history should show the destination as `Fungu: <name>`
- Fungu-specific reports may show Fungu balance after
- general transaction history should show the operating wallet balance after
  the contribution
