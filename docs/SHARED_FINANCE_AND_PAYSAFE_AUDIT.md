# Shared Finance and PaySafe Engineering Audit

Status: remediation baseline
Reviewed: 2026-06-18
Scope: Shared Budget, Shared Pot, PaySafe escrow, ORBI Pay Gateway

## Objective

This document is the authoritative remediation backlog for the shared-finance
and escrow infrastructure. A feature is not production-ready until its
financial movement, lifecycle state, authorization, idempotency, recovery, and
tests are complete.

## Service Build Order

1. PaySafe escrow lifecycle and merchant settlement foundations.
2. Shared Pot atomic contribution, withdrawal, membership, and invitation flows.
3. Shared Budget atomic spending, approvals, membership, and invitation flows.
4. Durable Pay Gateway intents, challenges, callbacks, and webhook delivery.
5. Reconciliation, operational dashboards, and failure-recovery drills.

## Critical Findings

### PaySafe

- Legacy escrow creation posts only a credit ledger leg. The authoritative
  ledger requires balanced debit and credit legs.
- Legacy release changes the transaction status without moving funds from the
  PaySafe vault to the recipient.
- Escrow reads are not scoped to the sender or receiver.
- Dispute creation does not verify that the actor is an escrow party.
- Legacy transactions and `escrow_agreements` are separate state models.
- Gateway payment challenges are generated but are not durably consumed by a
  complete authorization and execution lifecycle.
- Gateway payment intents are process-local and are lost on restart or
  horizontal scaling.

### Shared Budget

- Limit checks, payment execution, counters, and transaction records are
  separate operations. Concurrent requests can overspend or under-report.
- Approval execution can be claimed more than once.
- Invitation acceptance and owner membership creation are not atomic.
- Membership status and budget status are not consistently enforced.
- REVIEW-mode idempotency is not durable in the budget schema.
- The feature represents spending controls, not a funded pooled wallet. The UI
  and API contract must not imply that the configured budget limit is money.

### Shared Pot

- Atomic contribution and withdrawal RPCs are absent from `database/main.sql`.
- Legacy fallback updates transaction, wallet, pot, member, and ledger records
  separately.
- Existing RPCs trust caller-supplied user and role values.
- RPC execute permissions are not explicitly restricted to `service_role`.
- Withdrawals incorrectly increase `contributed_amount`.
- Wallet and pot currency equality is not enforced.
- Invitation acceptance and owner membership creation are not atomic.

### Cross-Cutting Security and Reliability

- Shared-finance tables need explicit RLS and service-role policies.
- Notification delivery must use an outbox and must not determine whether a
  committed financial or invitation operation is reported as failed.
- Production idempotency must remain durable when Redis is unavailable.
- Database schema parity between `main.sql`, `reset_schema.sql`, and migrations
  must be verified automatically.
- Financial mutation, concurrency, authorization, restart recovery, and replay
  tests are required before production activation.

## Mandatory Engineering Invariants

- Every monetary operation is a balanced, SQL-authoritative ledger mutation.
- Balance mutation and lifecycle state mutation occur in one database
  transaction.
- No user-controlled role, owner, merchant, wallet, or authorization field is
  trusted without server-side resolution.
- Every write has a durable idempotency key or a unique business reference.
- Every lifecycle transition validates current state and actor authority while
  holding database row locks.
- Public responses never expose internal endpoints, secrets, raw provider
  payloads, stack traces, or database errors.
- Notifications are asynchronous side effects recorded after the durable
  business commit.
- Reconciliation can derive and verify every displayed balance from the ledger.

## Delivery Gates Per Service

- Threat model and state machine documented.
- Main schema, reset schema, and migration are equivalent.
- Service-role-only RPC permissions are explicit.
- Unit tests cover validation and authorization.
- Database tests cover concurrency, replay, insufficient funds, locked wallets,
  currency mismatch, and partial-failure prevention.
- Reconciliation query and operational alert exist.
- API and mobile clients handle stable domain errors only.
- Rollback and recovery procedure is documented.

## Current Remediation Progress

- [x] Infrastructure audit recorded.
- [x] Canonical PaySafe escrow state machine implemented; staging DB validation remains.
- [x] Atomic PaySafe create implemented; staging DB validation remains.
- [x] Atomic PaySafe release implemented; staging DB validation remains.
- [x] Atomic PaySafe dispute implemented; staging DB validation remains.
- [x] Atomic PaySafe refund implemented; staging DB validation remains.
- [x] Merchant PaySafe settlement and fee lifecycle implemented; main/reset schema parity and staging RPC rollout verified.
- [x] Durable Gateway intent, challenge, request replay, and result-event outbox store implemented; staging RPC rollout verified.
- [x] Atomic Shared Pot contribution, withdrawal, owner membership, and invitation response implemented; staging RPC rollout verified, concurrency mutation validation remains.
- [ ] Atomic Shared Budget lifecycle.

## Next Tasks Discovered During Remediation

- **P1 - Schema parity automation:** PaySafe capability migrations are not yet
  automatically compared in CI against `database/main.sql` and
  `database/reset_schema.sql`. The current hardening SQL is synchronized, but
  add a CI parity check to prevent future drift.
- **P1 - Merchant settlement reversal:** The merchant PaySafe settlement record
  supports a reversed state, but an atomic reversal/chargeback RPC with balanced
  ledger legs and dual-control authorization is still required.
- **P0 - Core-verified gateway authorization:** Durable challenges must only be
  consumed after ORBI Core verifies PIN, OTP, passkey, or biometric evidence.
  Add the authenticated mobile confirmation endpoint and atomic
  challenge-consume/execution RPC; Pay Gateway must never verify ORBI
  credentials on Core's behalf.
- **P1 - Gateway result outbox worker:** Result events are now persisted before
  delivery. Add a background worker that claims failed/pending outbox rows with
  `SKIP LOCKED`, retries with backoff, and alerts on terminal exhaustion.
- **P1 - TypeScript module export repair:** Full `npm run build` is currently
  blocked outside this remediation scope because `core/types.ts` exports
  `../types` without the NodeNext `.js` extension and `core/utils.ts` cannot
  resolve `Transaction`, `Goal`, `UserRole`, and `Permission` through that
  barrel. Repair the core barrel/import contract and add a build regression
  test.
- **P0 - External deposit accounting model:** Staging has active collection
  provider capabilities but no active `MAIN_COLLECTION` TZS institutional
  account. In addition, `post_transaction_v2` only resolves wallets, platform
  vaults, and goals, while the external deposit service currently emits an
  institutional account ID as a ledger leg. Add SQL-authoritative
  institutional-account ledger support or map collection accounts to internal
  platform vaults before enabling real external deposits.
- **P1 - Demo funding lifecycle:** The sandbox-only, reversible, balanced seed
  at `database/demo/20260618_fund_demo_users.sql` is applied and verified for
  the two demo users. Add an explicit teardown/reversal script before the next
  schema reset drill.
- **P2 - Merchant onboarding atomicity:** Merchant creation, wallet creation,
  and default fee setup currently occur as separate application operations.
  Move them into one service-role-only database transaction.
- **P1 - Shared-finance notification outbox:** Shared Pot invitation delivery is
  now isolated from the committed invitation response, but durable retry still
  needs a shared-finance notification outbox and worker.
