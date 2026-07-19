# ORBI Core Engineering Architecture

**Classification**: FINANCIAL CORE / ENGINEERING SOURCE OF TRUTH  
**Status**: Canonical engineering contract  
**Last Updated**: 2026-07-19  

This document is the high-level engineering constitution for ORBI Core. It
connects the existing architecture, security, ledger, gateway, PaySafe, shared
finance, notification, and deployment documents into one operational contract.

Every engineer should read this before changing financial flows. If a change
conflicts with this document, pause and update the architecture through review
before editing code.

## 1. Purpose

ORBI Core is the financial authority for consumer, merchant, agent,
organization, PaySafe, shared finance, gateway, audit, and reconciliation
operations.

Its job is not only to make features work. Its job is to make financial truth
boring, auditable, replay-safe, and difficult to corrupt.

The platform must preserve these truths:

- PostgreSQL is the authoritative store for identity, wallet balances, ledger
  entries, transaction states, audit evidence, PaySafe, shared pots, shared
  budgets, merchant records, and gateway payment intents.
- Valkey is coordination only. It can hold locks, counters, sessions, OTPs,
  queues, and short-lived state, but it must never become the financial source
  of truth.
- Financial mutations must go through Core services, service-role database
  functions, or signed internal workers. Clients must not write financial
  tables directly.
- Every money movement must be deterministic, balanced, idempotent, and
  auditable.

## 2. Canonical Reference Map

Use this document as the entry point, then open the specific canonical doc:

| Area | Canonical document |
| :--- | :--- |
| Container and self-hosted topology | `SELF_HOSTED_PLATFORM_ARCHITECTURE.md` |
| Business and operating model | `ORBI_BUSINESS_OPERATIONAL_PLAYBOOK.md` |
| Core banking model | `CORE_BANKING_ARCHITECTURE.md` |
| Banking engine and double-entry posting | `BANKING_ENGINE_V2.md` |
| Pay Gateway boundary | `ORBI_PAYMENT_GATEWAY_INTEGRATION.md` |
| System separation | `ORBI_SYSTEM_SEPARATION.md` |
| Internal worker authentication | `INTERNAL_WORKER_AUTH.md` |
| Movement classification | `TRANSACTION_MOVEMENT_CLASSIFICATION.md` |
| Shared finance and PaySafe remediation | `SHARED_FINANCE_AND_PAYSAFE_AUDIT.md` |
| Audit model | `AUDIT_TRAIL_MODEL.md` |
| Reconciliation | `RECONCILIATION_ENGINE.md` |
| Release gates | `RELEASE_CHECKLIST.md` |
| Security validation | `SECURITY_ATTACK_SIMULATION_PLAN.md` |
| Test plan | `FINANCIAL_CORE_TEST_PLAN.md` |

## 3. Runtime Topology

Current self-hosted production-style topology:

```txt
Internet
  |
  v
Cloudflare / Edge Tunnel
  |
  v
ORBI Edge / public HTTPS hostnames
  |
  +--> ORBI Core API
  |      - /v1 public API
  |      - /api/v1 compatibility alias
  |      - /api/internal signed worker routes
  |      - /nexus-stream WebSocket stream
  |
  +--> ORBI Pay Gateway
  |      - public checkout/payment intent API
  |      - hosted challenge UI
  |      - provider callbacks
  |
  +--> ORBI Talk Gateway
         - SMS/email/push/template delivery

Private Docker network
  |
  +--> PostgreSQL
  +--> Valkey
  +--> Object Storage
  +--> Backup and recovery jobs
```

Core owns financial decisions. Gateway and Talk services carry envelopes,
provider-specific work, hosted UX, and messaging delivery. They must not become
ledger authorities.

## 4. Domain Ownership

| Domain | Owns | Must not own |
| :--- | :--- | :--- |
| Core API | auth, policy, risk, financial orchestration, ledger decisions | provider credentials, public checkout UI |
| Ledger service | balanced postings, transaction state, balance verification, reversals | UI labels, report formatting, recipient guessing |
| Movement classifier | read-model classification and display context | ledger writes, balance mutation, settlement |
| PaySafe service | escrow state machine and protected holds | bypassing ledger or registry protocol |
| Shared Pot/Fungu | pooled contribution and withdrawal lifecycle | pretending UI counters are ledger truth |
| Shared Budget/Meza | controlled allocation/spending lifecycle | treating a budget limit as funded money |
| Pay Gateway | payment intents, hosted challenge, provider webhooks, signed callbacks | direct wallet mutation, ORBI credential ownership |
| Talk Gateway | message templates and delivery routing | determining financial success/failure |
| Mobile/Web clients | UX, local cache, request payloads, diagnostics | direct financial writes or authoritative balances |

## 5. Non-Negotiable Financial Invariants

These rules are mandatory for every financial feature:

1. Every monetary operation posts balanced debit and credit legs.
2. Balance mutation and lifecycle mutation happen atomically or not at all.
3. Every write has a durable idempotency key, unique business reference, or
   database-enforced replay guard.
4. User-submitted wallet IDs, roles, owner IDs, merchant IDs, registry types,
   challenge status, and fee values are never trusted directly.
5. Core resolves identities and wallets server-side from authenticated actor,
   trusted worker metadata, and database records.
6. Public/mobile clients may read their own financial projections, but must not
   insert or update `transactions`, `wallets`, `platform_vaults`, or ledger
   tables.
7. Ledger posting is not modified to fix UI wording. Use movement
   classification and display resolution instead.
8. Notifications, push, SMS, email, and webhooks are side effects. They must
   not decide whether the committed financial operation succeeded.
9. If the system cannot prove safety, it must fail closed with a stable domain
   error.
10. Reconciliation must be able to derive every displayed balance from the
    ledger and lifecycle tables.

## 6. Identity And Registry Protocol

`registry_type` is identity classification and provenance. It answers:

- what kind of platform identity this is;
- how it was registered or approved;
- which service actor records should exist;
- which operational workflows can resolve it.

`registry_type` must not be used as a lazy transaction shortcut.

Good use:

- consumer signup starts as `registry_type=CONSUMER`;
- admin-approved merchant access promotes identity to `MERCHANT` and provisions
  merchant records;
- agent approval promotes identity to `AGENT` and provisions agent records;
- organization membership is represented through organization/member tables.

Bad use:

- hardcoding PaySafe as `CONSUMER -> CONSUMER`;
- hardcoding third-party checkout as `CONSUMER -> MERCHANT`;
- denying or allowing money movement only because a registry string matches;
- accepting a client-sent registry type as authority.

Correct protocol:

1. Resolve the actor from authenticated session or signed worker identity.
2. Resolve the counterparty through canonical identity lookup.
3. Verify account status and service linkage.
4. Verify service actor record when relevant, for example `merchants`,
   `merchant_wallets`, `agents`, `agent_wallets`, or organization membership.
5. Verify wallets/vaults belong to the resolved identities and are active,
   unlocked, and currency-compatible.
6. Execute through the ledger/state machine.

## 7. Wallet, Vault, And Service Bucket Model

Core currently uses wallet-like records and vault records to represent different
money containers. The naming can differ by historical module, but the rule is
stable:

- Operating wallet/vault is the customer's spendable ORBI balance.
- PaySafe/Internal Transfer vault is an internal hold or escrow bucket.
- Shared Pot/Fungu is a pooled service balance with membership rules.
- Shared Budget/Meza is a controlled allocation/spending service. A configured
  budget limit is not money until funds are allocated.
- Merchant wallets are merchant projections and settlement/PaySafe buckets.
- System wallets/vaults are internal financial authority accounts.

General transaction history should show the operating balance after the
movement. Product-specific screens may show product balances.

## 8. Ledger Commit Boundary

All money movement must enter one of these trusted paths:

- `TransactionService.postTransactionWithLedger`
- `BankingEngineService.process`
- approved service-role SQL RPCs
- signed internal worker routes that call Core financial services

Direct table mutations are not valid financial operations unless they are part
of a reviewed emergency repair procedure.

Client-facing routes should return stable domain errors, not raw database
errors. Internal logs and audit tables may retain the technical error.

## 9. PaySafe / Escrow Protocol

PaySafe is a protected hold and agreement lifecycle. It can be used by P2P,
merchant checkout, ORBI Shop, and future third-party services, but the
financial protocol is one.

Create:

1. Resolve sender and recipient identities.
2. Resolve source operating vault, sender PaySafe/internal vault, and recipient
   receiving vault.
3. If merchant context exists, validate merchant record, active status, owner
   linkage, and merchant PaySafe/settlement wallets.
4. Debit sender operating balance.
5. Credit sender PaySafe/internal hold vault.
6. Create transaction, ledger legs, and `escrow_agreements` state.
7. Dispatch notifications asynchronously.

Release:

1. Validate actor and current escrow state.
2. For normal PaySafe, follow sender/receiver confirmation state machine.
3. For merchant/service PaySafe, settle according to merchant settlement rules.
4. Move funds from hold vault to recipient/merchant settlement destination.
5. Record audit and notify both sides.

Refund:

1. If receiver has not accepted and the acceptance window expires, auto-refund.
2. If funds are confirmed, return requires the configured dispute/acceptance
   protocol.
3. Reverse through ledger legs. Do not delete or rewrite history.

Dispute:

1. Only escrow parties or authorized service actors can dispute.
2. Funds remain locked until resolution.
3. Customer care/admin sees the flagged lifecycle through audit and
   reconciliation surfaces.

PaySafe must never depend on registry string shortcuts. It depends on resolved
identity, linked service records, wallet ownership, lifecycle state, and ledger
invariants.

## 10. ORBI Pay Gateway Protocol

Third-party products must enter through ORBI Pay Gateway, not direct Core
wallet endpoints.

Gateway flow:

1. Product creates payment intent with service identity and return URLs.
2. Gateway signs a service payment request to Core.
3. Core resolves customer, merchant/service context, risk, and challenge need.
4. Gateway displays hosted challenge UI when required.
5. Core verifies challenge response and creates the PaySafe hold.
6. Core persists result and emits event to Gateway.
7. Gateway calls product webhook/return URL.

Rules:

- Gateway may carry `merchantId`, service code, route, idempotency key, and
  metadata.
- Gateway must not send wallet IDs as authority.
- Gateway must not verify ORBI credentials independently of Core.
- Hosted challenge UI is UX; Core remains the auth and financial authority.
- All internal Gateway-to-Core calls require signed worker headers and scopes.

## 11. Shared Pot / Fungu Protocol

Fungu is pooled shared finance.

Required behavior:

- creator/admin/member roles are enforced server-side;
- invited and created Fungu must be visually distinct in UI;
- spender/viewer roles must not access invite, report, or member management;
- activity views for non-admin members show only their own activity unless the
  role explicitly allows broader visibility;
- contributions and withdrawals must be atomic and idempotent;
- contribution notifications must include contributor name, amount, and Fungu
  name in the user's language;
- deletion/archive must respect balance and membership rules.

Deletion protocol:

- if balance > 0, withdraw or resolve funds first;
- if balance = 0 and members > 1, creator/admin can archive; UI hides it and
  backend lifecycle/reaper can purge after the configured window;
- invited member can leave a Fungu/Meza they do not own;
- local-only archive is not sufficient for cross-device consistency.

## 12. Shared Budget / Meza Protocol

Meza is a controlled funded budget, not a simple label.

Required behavior:

- creating a Meza can be free, but spending requires allocated funds;
- allocation moves money from operating wallet into the budget reserve through
  official ledger legs;
- auto-allocation is a rule-driven allocation event, not a silent UI counter;
- invited spender sees their assigned portion, not the full creator budget;
- owner/admin sees full budget and member portions;
- spender can withdraw/spend only within assigned portion and available funds;
- all spending routes must use idempotency keys.

Preferred spend architecture:

1. Withdraw from Meza to user's ORBI account.
2. Credit the user's operating balance.
3. User then pays/sends/cashes out through normal transaction flows.

Agent-assisted spending can be one-click UX, but ledger should still show the
two-step truth: budget release to user, then user-to-agent settlement.

## 13. Dashboard And Snapshot Protocol

The app should not lazily assemble critical financial state from many slow
screens.

Target model:

- `/v1/dashboard` is the canonical dashboard snapshot endpoint.
- `/api/v1/dashboard` remains compatibility only.
- Snapshot includes all core home data needed to render immediately after
  authenticated boot.
- Optional data can load after shell, but must not block the verified financial
  summary.
- Mobile may cache snapshot in memory for fast navigation, but must refresh
  from Core on login, foreground, and meaningful financial events.
- Cache must not override fresher server data.

Dashboard failure handling:

- required financial snapshot failure keeps user in loading/retry state;
- optional modules fail quietly with visible retry affordance;
- dashboard should never render stale critical balances as current without a
  freshness indicator.

## 14. Realtime, Push, And Messaging Protocol

Realtime is for user experience and session/risk awareness. It is not financial
truth.

Channels:

- WebSocket `/nexus-stream` for live app updates, heartbeats, balance refresh,
  status changes, session management, and foreground notifications.
- FCM push for app-background/offline notifications.
- ORBI Talk Gateway for SMS/email/template delivery.

Rules:

- financial commit succeeds or fails based on ledger/state machine, not message
  delivery;
- every important event should write durable notification/message state first;
- delivery workers retry push/SMS/email without replaying money movement;
- both sides of P2P, PaySafe, shared pot, and shared budget events should get
  appropriate messages;
- templates must respect language selection when user preference is known;
- WebSocket heartbeat can be frequent, but client refresh should be event-driven
  or throttled to avoid unnecessary load.

## 15. Idempotency And Retry Protocol

Any flow that can move money or change lifecycle state must have durable
idempotency.

Required for:

- P2P preview/settle;
- PaySafe create/release/refund/dispute/accept;
- Gateway payment intent/challenge response;
- Shared Pot contribution/withdrawal/invitation response;
- Shared Budget allocation/spend/withdraw/approval;
- provider webhook application;
- external deposit/cashout settlement.

Implementation rules:

- mobile and web clients send an idempotency key for submit/settle actions;
- Gateway sends idempotency keys for internal requests;
- Core stores/validates durable result records where replay can occur;
- network timeout must not become duplicate money movement;
- if response is lost but commit succeeded, retry returns the previous result.

## 16. Risk, Geo, And Challenge Protocol

Risk engine may allow, challenge, or block. Challenge must be explicit and
actionable.

Inputs:

- authenticated actor;
- device/session identity;
- client diagnostics;
- geo evidence when available;
- network/IP evidence when GPS is unavailable;
- amount, velocity, route class, wallet status, and historical behavior.

Rules:

- missing geo can be a warning or challenge depending on operation class and
  policy;
- financial commits require idempotency;
- risk blocks must produce stable domain errors and audit evidence;
- challenge UX must dismiss loading overlays before showing OTP/PIN/passkey UI;
- challenge response must be bound to the same request/intent/challenge.

## 17. Time Protocol

Database timestamps are stored in canonical UTC. User-facing messages, receipts,
and reports should display the event time in the user's resolved timezone.

Resolution order:

1. explicit client time context in request metadata;
2. user registration/profile timezone metadata;
3. server UTC for audit-only fallback.

No financial ordering should rely on local display time. Audit and ledger use
UTC. UI and messages can show local time with timezone context.

## 18. Security And RLS Protocol

Current financial table posture:

- users can read their own financial projections;
- users cannot directly insert/update/delete transaction, wallet, vault, or
  ledger records;
- service role and approved SQL RPCs handle financial writes;
- signed internal worker routes are required for service-to-service actions.

Never reintroduce client `FOR ALL` or client financial `INSERT` policies on:

- `transactions`
- `financial_ledger`
- `wallets`
- `platform_vaults`
- service reserve/settlement tables

Emergency repair is allowed only through documented privileged repair flows
with audit reason, actor, before/after evidence, and reconciliation.

## 19. Error Handling And UX Contract

User-facing errors must be clear and stable:

- no raw database errors;
- no stack traces;
- no Flutter red screens caused by expected domain failures;
- no loading overlay should cover a result, challenge, or retry UI;
- session-expired errors should navigate to a locked/login-again UI;
- timeout after commit should reconcile by idempotency key before reporting
  failure.

Backend response pattern:

```json
{
  "success": false,
  "error": "DOMAIN_ERROR_CODE",
  "message": "Human safe explanation.",
  "retryable": true,
  "correlationId": "trace-or-request-id"
}
```

## 20. Reporting, Receipts, And Read Models

Reports and receipts are read models over ledger truth.

Rules:

- transaction reports show oldest to newest for audit flow;
- mobile transaction list defaults newest to oldest;
- receipts must use the same data model for preview, print, and share;
- general transaction history balance after is operating/main wallet balance;
- product reports may show product-specific balances;
- movement labels come from `TransactionMovementClassifier`;
- internal buckets such as PaySafe vault should not appear as final recipient
  when the true business destination is known.

## 21. Deployment Protocol

Safe deployment order:

1. Additive schema migration.
2. Build and type check.
3. Run relevant smoke tests.
4. Deploy Core image.
5. Verify `/health`.
6. Verify logs for startup dependency failures.
7. Run targeted financial smoke against test accounts.
8. Push commit if not already pushed, or tag release after validation.

Do not deploy duplicate stacks with separate databases unless explicitly doing
a migration drill. Duplicate local containers can point services at the wrong
database and create false failures.

## 22. SQL Source Parity

Every schema-affecting change must keep these aligned:

- `database/main.sql`
- `database/reset_schema.sql`
- `database/migrations/*`

Rules:

- migrations describe the forward change;
- `main.sql` is the full current schema source;
- `reset_schema.sql` must rebuild the same effective schema;
- do not patch live DB only and forget source SQL;
- after RLS/security changes, scan for stale policies across all SQL files.

## 23. Completed Service Protection

These flows are considered stable and should not be edited casually:

- registration and password reset;
- P2P send/preview/settle;
- transaction history, receipts, and reports;
- PaySafe/escrow core lifecycle;
- Shared Budget/Meza funded allocation and spending baseline.

If a change touches any stable service:

1. state why the change is required;
2. identify the exact boundary being changed;
3. add or update tests/smoke checks;
4. avoid broad helper rewrites;
5. do not mix UI label changes with ledger logic changes.

## 24. New Feature Engineering Checklist

Before building a new financial feature:

- define the business lifecycle states;
- define who can act at each state;
- define source and destination money containers;
- define ledger legs for each state transition;
- define idempotency keys and replay behavior;
- define notification recipients and templates;
- define audit events;
- define reconciliation query;
- define mobile/web response contract;
- define failure and timeout behavior;
- update docs before or in the same commit as code.

## 25. Decision Rules For Future Engineers

Use these rules when uncertain:

- If it changes money, put it behind ledger and idempotency.
- If it changes meaning, put it in classifier/read model, not ledger posting.
- If it depends on a person or service actor, resolve it server-side.
- If it depends on a third party, require signed gateway/provider proof.
- If it can be retried, make replay return the same result.
- If it is a message, do not let delivery decide financial success.
- If it is a timestamp, store UTC and display resolved local time.
- If it is registry, treat it as identity context, not a shortcut permission.
- If it is unclear, fail closed and write audit evidence.

