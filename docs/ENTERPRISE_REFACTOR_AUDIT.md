# ORBI Enterprise Refactor Audit

Date: 2026-04-01

This document captures the backend technical audit produced from direct inspection of the local ORBI repository. No code changes were made during this audit.

## 1. Current Architecture Summary

- Entry point is `server.ts`, a large Express gateway.
- Core application facade is `backend/server.ts`, which composes auth, wallets, ledger, KYC, devices, documents, treasury, service actors, messaging, settlement, and offline flows.
- Folder structure is domain-oriented but mixed in maturity:
  - `ledger/` holds core transaction service and reconciliation helpers.
  - `backend/ledger/` holds orchestration engines like transaction engine, FX, policy, reconciliation, and state machine.
  - `backend/payments/` holds provider routing, external funds, settlement lifecycle, gateway routes, and fee logic.
  - `iam/` holds auth, KYC, device, and document services.
  - `wealth/` and `backend/wealth/` split wallet/business account concerns.
  - `strategy/` holds goals, tasks, and category planning.
  - `backend/offline/` holds SMS/offline bridge flows.
  - `database/` contains schema and RPC functions.
- Server bootstrap is centralized in `server.ts`:
  - env validation
  - Express app creation
  - static file serving
  - security middleware
  - router mounting
  - WebSocket server
  - warmup and background jobs
- Routing organization is mostly monolithic:
  - internal routes under `/api/internal`
  - admin routes under `/api/admin`
  - main application routes under `/v1` and `/api/v1`
  - most route definitions live inside `server.ts`
- Middleware chain in `server.ts` is:
  - static files
  - idempotency middleware
  - CORS
  - Helmet
  - app trust middleware
  - JSON body parser
  - WAF inspection
  - sanitizer
  - risk assessment
  - `/api/v1` session monitor
  - router mounting
  - 404/error handlers
- Auth/authorization:
  - `iam/authService.ts` uses Supabase auth plus local session tables.
  - refresh-token hashing, rotation, device fingerprinting, trust flags, and brute-force protection exist.
  - authorization is inconsistent:
    - some routes use `authenticate`
    - some also use `requireSessionPermission(...)`
    - some only check role metadata
- Ledger engine:
  - core posting is in `ledger/transactionService.ts`
  - orchestration is in `backend/ledger/transactionEngine.ts`
  - DB RPC functions `post_transaction_v2` and `append_ledger_entries_v1` are used for atomic insert/update batches
  - ledger is intended to be source of truth, with reconciliation against cached wallet balances
- Transaction orchestration:
  - `backend/ledger/transactionEngine.ts` derives legs, calculates fees, transitions status, commits, and triggers settlement/notifications
  - `TransactionStateMachine` is used
- Settlement lifecycle:
  - schema-backed via `settlement_lifecycle`
  - scheduler in `backend/payments/settlementScheduler.ts`
  - external fund movement model exists via `external_fund_movements`
- Provider integration layer:
  - provider registry in `financial_partners`
  - routing rules in `provider_routing_rules`
  - resolver in `backend/payments/ProviderRoutingService.ts`
  - external movement orchestration in `backend/payments/InstitutionalFundsService.ts`
  - gateway adapter pattern via `gatewayService.ts` and provider factory
- Encryption/KMS:
  - `backend/security/kms.ts`
  - `backend/security/encryption.ts`
  - AES-GCM envelope-style encryption with versioning and key rotation support
- Supabase/Postgres access patterns:
  - mostly direct table access through `getSupabase()` / `getAdminSupabase()`
  - very admin-client heavy, so many paths bypass RLS
  - some critical flows use RPC
  - many other flows still do direct inserts/updates from route handlers
- Background jobs:
  - warmup in `backend/server.ts`
  - scheduler in `backend/payments/settlementScheduler.ts`
  - additional repeating jobs in both `backend/server.ts` and `server.ts`
- WebSocket/realtime:
  - WSS at `/nexus-stream` in `server.ts`
  - local socket registry in `backend/infrastructure/SocketRegistry.ts`
  - cross-node fanout via Supabase Realtime broadcast
- Offline/SMS:
  - `backend/offline/OfflineGatewayService.ts`
  - `backend/offline/OfflineOrbiBridge.ts`
  - SMS request -> challenge -> confirmation -> ORBI bridge flow exists
  - currently supports confirmed offline `SEND` flow
- Shared finance and wealth:
  - schema-backed shared pots, shared budgets, invites, approvals, bill reserves, wealth snapshots
  - many routes are in `server.ts` under `/wealth/*`

## 2. Critical Production Risks

- `server.ts` is a 6,658-line monolith. Routing, middleware, money flows, shared finance, WebSockets, and admin endpoints are concentrated in one file.
- `ledger/transactionService.ts` is 1,516 lines and mixes posting, balance derivation, events, AML, reconciliation, and admin/audit utilities.
- Several money-sensitive route handlers appear to write directly to `financial_ledger` instead of going through the canonical ledger service/RPC path.
  - Example hotspots in `server.ts` around shared pot contribution/withdrawal and bill reserve helper logic.
- Generic `post_transaction_v2` updates cached balances but does not visibly enforce row locking in the main transaction-posting path.
- Heavy use of `getAdminSupabase()` means a lot of business logic runs above DB policy controls.
- Multiple schedulers/background loops exist in both `server.ts` and `backend/server.ts`, creating risk of duplicate processing in multi-instance deployments.
- WebSocket auth allows `userId` registration and optionally token verification; the flow is not as strict as bank-grade session binding.
- Realtime delivery is best-effort, not durable. There is no strong delivery guarantee or replay model for critical balance events.
- Middleware and security checks are centralized in the gateway, but business invariants are not fully centralized.

## 3. Fintech-Specific Risks

- Ledger safety is partially centralized, but not universal. Direct ledger-row inserts outside canonical posting create reconciliation and invariant risk.
- Cached balance mutation still exists in RPCs and route handlers, so concurrent-write correctness depends heavily on code path discipline.
- Idempotency exists at HTTP middleware and `reference_id` level, but not every financial path appears uniformly idempotent by domain key.
- Some flows rely on app/business-layer balance derivation before DB write, rather than full DB-locked mutation.
- External settlements and internal ledger movements are modeled separately, which is good, but stage consistency depends on application code and scheduler correctness.
- AML/risk rules are useful but still relatively lightweight for institutional-grade monitoring.
- Offline SMS support currently bridges only a narrow path; extension to withdraw/pay without stronger replay and identity guarantees would be risky.
- Service actor flows, merchant flows, and shared finance flows are real, but they increase mutation surface area substantially.

## 4. Bank-Level Gaps

- No clear universal DB row-locking strategy for all balance-affecting mutations.
- No visible stored-procedure-first standard for all money flows.
- No clear separation between:
  - command layer
  - domain service layer
  - persistence/repository layer
  - route/controller layer
- Authorization is not uniformly policy-driven. Some admin/business routes still rely on role metadata instead of a single hardened permission model.
- WebSocket/session trust is below bank-grade:
  - no strong signed channel auth envelope
  - no explicit per-message authorization policy
- Risk engine is rules-based and useful, but not yet bank-level in areas like sanctions screening, case management depth, step-up decisioning, or real-time hold orchestration.
- Audit and reconciliation exist, but there is no obvious immutable domain-event backbone governing every financial state transition.
- Secrets/KMS handling is better than average, but deterministic fallback keys and runtime fallbacks would need stricter production controls for bank-grade assurance.
- Background processing looks single-process-friendly, not obviously lease/leader-election safe at scale.

## 5. Technical Debt Hotspots

- `server.ts`
  - oversized route file
  - mixed concerns
  - hard to test safely
- `backend/server.ts`
  - large service facade with many responsibilities
- `ledger/transactionService.ts`
  - too many responsibilities in one class
- `backend/ledger/transactionEngine.ts`
  - orchestration logic is dense and high-risk
- `backend/payments/InstitutionalFundsService.ts`
  - large orchestration surface for provider/external movement logic
- `backend/features/ServiceActorOps.ts`
  - large actor/business-domain service mixing provisioning, lookup, wallet mapping, and transaction projection
- Shared finance flows in `server.ts`
  - direct SQL and direct ledger inserts in route handlers
- Supabase access pattern
  - direct table access everywhere
  - inconsistent use of admin vs anon/authenticated client
- Mixed old/new architecture
  - some flows use RPCs and engines
  - some still mutate directly from route handlers
- Naming and structure drift
  - duplicate “core” concepts across root, `backend/core`, `ledger`, `wealth`, and `services`

## 6. Recommended Refactor Phases In Priority Order

### Phase 1. Financial Safety Containment
- Freeze new direct money mutations in route handlers.
- Move every balance-affecting flow behind one canonical posting/settlement command layer.
- Eliminate direct `financial_ledger` inserts outside approved ledger modules.
- Add DB row-locking strategy for all balance-affecting mutations.

### Phase 2. Route Decomposition
- Split `server.ts` into routers by domain:
  - auth
  - wallets
  - transactions
  - wealth
  - merchant
  - agent
  - enterprise
  - admin
  - offline
  - gateway/webhooks
- Keep middleware assembly in bootstrap only.

### Phase 3. Financial Domain Modularization
- Split `TransactionService` into:
  - ledger posting
  - balance derivation/reconciliation
  - transaction events/status
  - admin/audit helpers
- Split `InstitutionalFundsService` into:
  - routing/resolution
  - intent creation
  - external movement persistence
  - settlement commit/reconciliation

### Phase 4. Authorization Hardening
- Standardize all protected routes on one policy layer.
- Stop mixing raw role checks with metadata checks.
- Make service actor/admin/enterprise permissions explicit and centrally enforced.

### Phase 5. Background Job Hardening
- Consolidate schedulers.
- Add leader-election / lease-based execution.
- Prevent duplicate settlement/reconciliation loops across instances.

### Phase 6. Realtime and Offline Hardening
- Strengthen WebSocket auth/session binding.
- Add durable notification/replay strategy for critical financial events.
- Expand offline only after replay protection, identity binding, and command-layer safety are uniform.

### Phase 7. Persistence Discipline
- Introduce repository-style boundaries for high-risk tables:
  - `transactions`
  - `financial_ledger`
  - `wallets`
  - `platform_vaults`
  - `external_fund_movements`
  - `settlement_lifecycle`
- Reduce raw table access from route files.

### Phase 8. Bank-Grade Controls
- strengthen sanctions/case workflow
- stronger dual-control / maker-checker for sensitive treasury ops
- stricter production-only KMS policies
- explicit financial invariant tests at DB and service level

## Supplemental: Direct Ledger Write Audit

### Canonical Ledger Path
These go through the intended ledger service:
- `ledger/transactionService.ts`
  - `postTransactionWithLedger(...)`
  - `addLedgerEntries(...)`
- Main callers:
  - `backend/ledger/transactionEngine.ts`
  - `backend/payments/InstitutionalFundsService.ts`
  - `backend/payments/settlementLifecycleManager.ts`
  - `backend/enterprise/treasuryService.ts`
  - `strategy/goalService.ts`
  - `backend/features/ServiceActorOps.ts`
  - `ledger/escrowService.ts`

This is the safer path because it:
- derives balance from ledger
- checks internal wallets
- routes through DB RPC
- emits events
- triggers AML monitoring

### Direct Ledger Bypass Paths
These write to `financial_ledger` directly instead of using `TransactionService.postTransactionWithLedger(...)`.

1. `server.ts:4416`
- helper: `insertBillReserveLedger(...)`
- used by bill reserve create/update/release flows
- inserts rows directly into `financial_ledger`

2. `server.ts:5688`
- route: shared pot contribution
- directly:
  - inserts into `transactions`
  - updates wallet balance
  - updates shared pot balance
  - then inserts ledger rows manually

3. `server.ts:5827`
- route: shared pot withdrawal
- directly:
  - inserts into `transactions`
  - updates wallet balance
  - updates shared pot balance
  - updates member contribution row
  - then inserts ledger rows manually

4. `backend/payments/providers/cardProvider.ts:438`
- card settlement path
- directly:
  - inserts `transactions`
  - inserts `financial_ledger`
  - updates wallet balance

### Why These Bypasses Matter
These paths skip some or all of the canonical guarantees:
- no shared central invariant enforcement
- no shared AML invocation
- no consistent event emission
- no shared idempotency/reference discipline
- no consistent internal-wallet validation logic
- no obvious DB row locking
- cached balances are updated directly in app logic

The highest-risk ones are:
- shared pot contribution/withdrawal
- card provider settlement

because they do:
- transaction header insert
- cached balance update
- ledger insert

as separate application steps, not one canonical commit path.

### Risk Classification
- `Bill reserve helper`
  - medium risk
  - still a bypass, but more localized and easier to fold back into a canonical flow
- `Shared pot contribution/withdrawal`
  - high risk
  - multiple mutable objects updated in one request path without clear atomic RPC boundary
- `Card provider settlement`
  - high risk
  - external settlement touching internal ledger directly is exactly where strong canonical control should exist

### Minimal Migration Plan
1. Shared Pot First
- move shared pot contribution/withdrawal into a dedicated ledger-backed service
- centralize:
  - transaction creation
  - wallet mutation
  - pot balance mutation
  - ledger legs
- ideally behind one DB transaction/RPC or one canonical service command

2. Card Settlement Second
- stop direct ledger insert in `backend/payments/providers/cardProvider.ts`
- route card settlement crediting through `TransactionService.postTransactionWithLedger(...)`
- keep provider/webhook logic where it is, but hand off the money mutation

3. Bill Reserve Third
- replace `insertBillReserveLedger(...)` direct insert helper
- make bill-reserve locking/release use canonical append/post methods or dedicated DB RPC

4. After That
- add one repository/service rule:
  - no route or provider adapter may write `financial_ledger` directly
- only:
  - canonical ledger service
  - DB RPCs owned by that service

### Recommended First Fix
- `shared pot contribution + withdrawal`

Why:
- highest business risk in app-owned feature logic
- easy to hit from normal product usage
- currently clearly split across several direct writes

## Bottom Line

- ORBI already has real fintech depth: ledger, providers, settlements, shared finance, offline SMS, service actors, KMS, and reconciliation are genuinely implemented.
- The biggest issue is not lack of features.
- The biggest issue is architectural concentration and inconsistency in how financial mutations are executed.
