# ORBI Open Digital Banking And BaaS Roadmap

This roadmap captures the remaining work required for ORBI to become a mature
Open Digital Banking, BaaS, and merchant/developer platform.

The rule is simple: finish one phase to production quality before moving to the
next. Stable financial services should not be reopened unless a phase
explicitly requires it.

## Current Foundation

Already established or actively stabilized:

```text
ORBI Core ledger authority
ORBI Pay Gateway boundary
ORBI hosted challenge direction
PaySafe escrow lifecycle
Payment profiles
Business identity federation
Business registration protocol
P2P transaction flow
Transaction history and receipts
Shared finance baseline
Self-hosted Core/Auth/Gateway infrastructure
Pay Gateway Developer Portal contracts
Node SDK bootstrap
```

## Full Completion Gate

ORBI should be considered Open Digital Banking/BaaS complete only when the
platform can safely serve external businesses without engineering help, without
manual database fixes, and without bypassing Core financial rules.

The completion gate is:

```text
1. External services can onboard, request scopes, receive keys, configure
   webhook endpoints, test in sandbox, and move to live through approval.
2. Every user/business consent is explicit, scoped, revocable, language-aware,
   and stored as audit evidence.
3. Payment intents, hosted challenges, PaySafe escrow, payment profiles,
   account/balance read access, payout/withdrawal requests, refunds, disputes,
   and webhooks all use stable versioned contracts.
4. Every money movement is idempotent, double-entry, reconciled, and traceable
   from merchant order to Core ledger to webhook delivery.
5. Merchant and organization actors have registry families, roles, wallets,
   limits, KYB/KYC state, risk profile, settlement profile, and operational
   controls.
6. Developers have SDKs, API references, sandbox users, sample apps, webhook
   replay tools, error catalog, status dashboard, and certification checklist.
7. ORBI operators have a control room for payment intents, hosted challenges,
   webhooks, escrows, disputes, refunds, risk blocks, sessions, provider health,
   and manual recovery with dual-control.
8. Compliance has AML/risk alerts, consent evidence, audit-chain monitoring,
   data-retention policy, timezone-safe reporting, and regulator-ready exports.
9. Production has SLOs, monitoring, backups, disaster recovery drills, load
   tests, key rotation, secret custody, incident runbooks, and release gates.
```

Anything missing from this gate should stay visible in the phase TODOs below.

## Active Hardening Memory

This is the current operator and engineering sequence. Complete it one step at
a time, verify each step, then commit and deploy before moving forward.

```text
1. Secure internal service link.
   Gateway and Core must prove they are talking to each other. HMAC remains
   mandatory. Live mTLS is enabled only after a maintenance window and smoke
   evidence.

2. Developer Portal is backend-driven.
   The portal is only the screen. Login, roles, service requests, approvals,
   keys, rotations, sandbox/live access, and activity must come from Gateway
   APIs. The browser must never connect to a database or hold secrets.

3. Developer domains are verified.
   A developer must register the website domain, return URL, and payment update
   URL they will use. ORBI approves them before live payments are accepted.

4. Every request is traceable.
   SDK, Gateway, Core, hosted challenge, payment updates, operator actions, and
   reconciliation must share request IDs so support can follow one payment end
   to end.

5. Payment update retry is safe.
   Webhook replay must be controlled, signed, logged, and visible. Developers
   should not manually repeat payment actions and risk duplicate movement.

6. SDKs are the main integration path.
   Node, Python, PHP, and future SDKs must use friendly methods such as
   `orbi.transfers.send(...)`, `orbi.payments.createIntent(...)`, and
   `orbi.webhooks.verify(...)` instead of raw HTTP for normal developers.

7. Open Banking/BaaS compliance is complete.
   Consent receipts, permissions, revocation, access grants, rate limits,
   audit exports, and certification checks must be ready before ORBI calls the
   platform complete.
```

Developer-facing rule:

```text
Developers should understand the flow without knowing ORBI internals:
create account -> test in sandbox -> add domains -> request live access ->
receive keys -> use SDK -> receive payment updates -> reconcile safely.
```

## Phase 1: Platform Contracts Lock

Status:

```text
COMPLETE
```

Goal:

```text
Freeze the public contract language before expanding integrations.
```

TODO:

- [x] Lock Payment Profile contract.
- [x] Lock Hosted Challenge contract.
- [x] Lock Payment Intent contract.
- [x] Lock PaySafe Escrow Lifecycle contract.
- [x] Lock Webhook Event contract.
- [x] Lock Developer/Merchant Scope contract.
- [x] Add versioning policy for all public contracts.
- [x] Add breaking-change policy.
- [x] Add request/response examples for each endpoint.
- [x] Add error-code catalog.
- [x] Enforce standard Pay Gateway error response shape on public contract routes.
- [x] Normalize public payment intent statuses to contract vocabulary.
- [x] Add contract tests for standard error response shape.
- [x] Add contract tests for public payment intent response shape.
- [x] Add executable response schemas for payment profile, hosted challenge,
  PaySafe escrow intent, and webhook event payloads.

Active artifacts:

```text
Pay Gateway docs/PLATFORM_INTEGRATION_CONTRACTS.md
Pay Gateway docs/CONTRACT_VERSIONING_AND_ERROR_CODES.md
Core docs/ORBI_INFRASTRUCTURE_PLATFORM_BLUEPRINT.md
Core docs/ORBI_PAYMENT_GATEWAY_INTEGRATION.md
Core docs/registration/ORBI_API_REQUEST_CONTRACTS.md
```

Definition of done:

```text
Docs, code, gateway payloads, Core worker routes, and merchant examples use the
same field names and lifecycle names.
```

## Phase 2: Developer Portal

Status:

```text
IN_PROGRESS
```

Goal:

```text
Give merchants and developers a controlled place to create and operate ORBI
integrations.
```

TODO:

- Service/app registration UI.
- API key creation and rotation.
- Sandbox/live environment switch.
- Redirect URL allowlist.
- Webhook URL allowlist.
- Webhook signing secret rotation.
- Scope request and approval workflow.
- Service profile dashboard.
- Event logs and replay UI.
- Integration health dashboard.
- API docs browser.
- SDK download links.
- [x] Define service application contract.
- [x] Define service profile response contract.
- [x] Define developer scope request contract.
- [x] Define redirect/webhook allowlist update contract.
- [x] Define API key rotation request contract.
- [x] Define developer portal event contract.
- [x] Add bootstrap persistence for service applications and service records.
- [x] Add operator-only bootstrap endpoints for applications, approvals,
  service profiles, scope requests, allowlists, API key rotation requests, and
  developer portal events.
- [x] Add tests for developer portal store lifecycle.
- [x] Add operator approve/reject decisions for scope requests.
- [x] Add operator approve/complete/reject decisions for API key rotations.
- [x] Enforce Developer Portal redirect/webhook allowlists on payment intent
  and PaySafe runtime requests when a portal service record exists.
- [x] Add one-time API key issuance with stored fingerprint-only metadata.
- [x] Add one-time webhook signing secret issuance with stored fingerprint-only
  metadata.
- [x] Add webhook signing secret rotation request and decision workflow.
- [x] Add Developer Portal UI blueprint for service applications, service
  details, scopes, allowlists, keys, webhook secrets, events, integration
  health, docs, and sandbox tools.
- [x] Add webhook delivery log persistence for Core-to-service webhook attempts.
- [x] Add operator webhook delivery list and replay bootstrap endpoints.
- [x] Document webhook replay rules and delivery record shape for Developer
  Portal UI.
- [x] Add integration health summary endpoint with service, key, webhook,
  allowlist, scope, provider readiness, and recent error warnings.
- [x] Add integration health dashboard contract and test coverage.
- [x] Add API docs browser catalog endpoint.
- [x] Add sandbox tools catalog endpoint.
- [x] Add SDK links catalog endpoint.
- [x] Add explicit sandbox/live environment profile endpoints and separation
  contract.
- [x] Add sandbox simulator flow endpoint for payment intent, hosted challenge,
  signed webhook, reconciliation, and replay testing.
- [x] Add catalog test coverage for docs, sandbox tools, and SDK metadata.
- [x] Add bootstrap TypeScript/Node SDK package with payment intent, PaySafe,
  identity, business registration, payment profile, and webhook verification
  helpers.

Active artifacts:

```text
Pay Gateway docs/DEVELOPER_PORTAL_CONTRACTS.md
Pay Gateway src/contracts/developerPortalContract.ts
Pay Gateway tests/developerPortalContract.test.ts
```

Definition of done:

```text
A new merchant can register a service, request scopes, get sandbox keys, test a
payment intent, receive a signed webhook, and view logs without engineer help.
```

## Phase 3: OAuth/OIDC Consent Center

Status:

```text
NOT_STARTED
```

Goal:

```text
Make user/business consent explicit, scoped, revocable, and auditable.
```

TODO:

- Consent screen for external services.
- [x] User-readable scope descriptions.
- Business-readable merchant consent.
- [x] Consent expiry and renewal.
- [x] Consent revocation UI contract.
- Consent audit trail.
- Balance-read consent.
- Payment-profile consent.
- Withdrawal consent.
- Hosted challenge consent language.
- Language support for English and Swahili.
- OAuth/OIDC client registration for ORBI-owned apps and approved external
  services.
- Authorization-code flow with PKCE for browser/mobile-safe integrations.
- Client credentials flow for server-to-server trusted services.
- Token introspection and revocation endpoints.
- Consent receipts that bind user, service, scope, timestamp, locale, device,
  IP/network context, and challenge evidence.
- Scope enforcement middleware shared by Core and Pay Gateway.
- Consent renewal notifications before expiry.
- Consent revocation webhook to merchants.
- [x] Add bootstrap consent receipt contract for service, subject, scopes,
  purpose, locale, timezone, channel, challenge evidence, expiry, and
  revocation.
- [x] Add bootstrap consent receipt store and operator endpoints to create,
  list, read, and revoke consent evidence.
- [x] Add contract and store tests for active, expired, and revoked consent
  receipts.
- [x] Add bootstrap runtime guard for Developer Portal services so scoped
  balance reads, identity reads, and payment profile actions fail closed when
  granted scopes or active consent evidence are missing.
- [x] Auto-create consent receipts from successful hosted challenge approvals
  when explicit consent scopes and stable subject identity are present.
- [x] Make hosted challenge consent receipt creation idempotent by payment
  intent and Core challenge evidence.
- [x] Deliver signed `consent.revoked` webhooks to services when consent
  receipts are revoked.
- [x] Archive sanitized webhook payloads in delivery records and replay generic
  service webhook events, not only payment intent events.

Definition of done:

```text
No external service can access identity, balance, payment profile, or financial
actions without explicit scope and consent evidence.
```

## Phase 4: Sandbox Environment

Status:

```text
NOT_STARTED
```

Goal:

```text
Let developers test safely without touching live money or live customers.
```

TODO:

- Sandbox service keys.
- Sandbox ORBI users.
- Sandbox wallets and balances.
- Sandbox PaySafe escrows.
- Sandbox hosted challenges.
- Sandbox webhook delivery.
- Sandbox provider rails.
- Test cards/mobile-money/bank rails where applicable.
- Deterministic error simulation.
- Sandbox reset tools.
- Sandbox hosted challenge test PIN/OTP flows.
- [x] Sandbox webhook replay and delivery failure simulator guide.
- Sandbox risk decisions: allow, warn, block, manual review.
- Sandbox PaySafe lifecycle scenarios: accept, release, refund request,
  dispute, expiry, auto-refund.
- Sandbox settlement reports and reconciliation exports.
- Public sandbox seed data for sample merchants, sellers, users, agents,
  organizations, and SACCOS members.
- Sandbox-to-live promotion checklist.

Definition of done:

```text
Developers can complete end-to-end payment, escrow, refund, dispute, webhook,
and failure scenarios in sandbox.
```

## Phase 5: Webhook Reliability

Status:

```text
IN_PROGRESS
```

Goal:

```text
Make external state updates reliable even when merchant systems or networks are
unavailable.
```

TODO:

- Webhook retry queue.
- Dead-letter queue.
- [x] Bootstrap webhook delivery log persistence.
- [x] Operator webhook delivery list endpoint.
- [x] Operator webhook replay endpoint.
- Production webhook retry queue.
- Production dead-letter queue.
- Developer webhook delivery dashboard UI.
- [x] Signature verification SDK.
- Event ordering rules.
- Idempotent event processing guide.
- Per-service webhook timeout policy.
- Backoff and retry schedule.
- Webhook failure notifications.
- Webhook event sequence numbers per service.
- Webhook event deduplication keys.
- Webhook replay audit trail with actor, reason, and result.
- Merchant endpoint health scoring.

Definition of done:

```text
Merchant order/payment state can always be reconciled from signed ORBI events,
even after outages.
```

## Phase 6: Merchant And Organization Onboarding

Status:

```text
NOT_STARTED
```

Goal:

```text
Make business onboarding strong enough for real merchants, agents,
organizations, SACCOS, and future B2B partners.
```

TODO:

- Merchant application workflow.
- Organization application workflow.
- Agent application workflow.
- KYB/KYC document upload.
- Business document verification.
- Risk profile assignment.
- Fee profile assignment.
- Settlement profile setup.
- Merchant wallet provisioning.
- Service access request review.
- Admin approval and rejection workflow.
- Suspension, freeze, and reactivation workflow.
- Business account linking through ORBI Business registration protocol.
- Merchant seller payment-profile linking flow.
- Organization member role model.
- Agent float and cash-desk registration.
- SACCOS/member registry support.
- Settlement destination verification.
- Merchant fee/tax profile policy.
- Business webhooks and event subscriptions.
- Business-facing onboarding status API.

Definition of done:

```text
Business actors are not just local app users; they become Core-approved service
actors with correct registry, role, wallets, scopes, limits, and audit trail.
```

## Phase 7: SDKs And Integration Tooling

Status:

```text
IN_PROGRESS
```

Goal:

```text
Make integration easy and safe for developers.
```

TODO:

- [x] Bootstrap TypeScript/Node SDK.
- [x] Bootstrap webhook verifier helper.
- [x] Add SDK consent receipt helpers for create, list, read, and revoke.
- [x] Add SDK webhook delivery helpers for delivery listing and replay.
- [x] Add SDK batch replay helper for failed webhook deliveries.
- [x] Add typed SDK webhook events for `payment_intent.updated` and
  `consent.revoked`.
- [x] Add SDK verify-and-parse webhook helper and typed event router.
- Production TypeScript/Node SDK package release.
- Web checkout helper.
- [x] Hosted Challenge helper.
- Webhook verifier standalone package if separated from SDK.
- [x] Hosted challenge redirect helper.
- [x] Payment intent helper.
- [x] Payment profile helper.
- [x] Error-code helpers.
- Flutter/mobile helper only where appropriate.
- [x] Bootstrap merchant checkout example app.
- [x] Bootstrap seller linking example app.
- [x] Bootstrap SACCOS member payments example app.
- [x] Bootstrap OpenAPI 3.1 contract specification.
- OpenAPI specification generation from source contracts.
- [x] Bootstrap Postman/Insomnia collection.
- [x] Bootstrap CLI for sandbox checkout, webhook replay, and webhook signature verification.
- [x] Bootstrap CLI for sandbox service setup automation.
- [x] Developer Portal guided UI blueprint for sandbox service setup automation.
- [x] SDK methods for sandbox/live environment profiles and sandbox simulator
  flow.
- Developer Portal guided UI implementation.
- Versioned SDK release policy.
- SDK security guide for server-only keys.

Definition of done:

```text
Developers can integrate without hand-coding signatures, webhook validation,
or fragile payload mapping.
```

## Phase 8: Reconciliation And Reporting

Status:

```text
NOT_STARTED
```

Goal:

```text
Make financial truth visible, exportable, and auditable.
```

TODO:

- Merchant settlement reports.
- PaySafe escrow reports.
- Payout reports.
- Refund and dispute reports.
- Balance movement reports.
- Daily reconciliation exports.
- Webhook reconciliation view.
- Provider reconciliation view.
- Core/Gateway event correlation report.
- CSV/PDF exports.
- Audit-ready timestamp and timezone presentation.
- Merchant order-to-payment-to-ledger correlation report.
- Service balance and settlement statement.
- PaySafe escrow aging report.
- Dispute and refund aging report.
- Idempotency replay/reuse report.
- Consent and scope access report.
- Signed report export hash for audit evidence.

Definition of done:

```text
Every merchant, platform, and operator can reconcile orders, escrows, payments,
settlements, and ledger movement from ORBI truth.
```

## Phase 9: Risk And Compliance Platform

Status:

```text
IN_PROGRESS
```

Goal:

```text
Make risk controls explicit and controllable without breaking good customers.
```

TODO:

- Risk score explanation model.
- Velocity limits by service and user.
- Device/IP/location risk rules.
- Merchant risk profile.
- Transaction risk profile.
- Manual review queue.
- Hold/release controls.
- AML suspicious pattern monitoring.
- Risk override audit.
- User-friendly block and retry messages.
- Operator alert integrity and JSON-safe actions.
- Per-service risk profiles and velocity policies.
- Hosted challenge risk step-up policy.
- Merchant onboarding risk scoring.
- Fraud pattern rules for repeated payment-intent creation, abandoned
  challenges, webhook abuse, and high-frequency refunds.
- Compliance case management for blocked or flagged payments.
- Audit-chain integrity user-facing notification policy.
- Regulatory export package for disputes, AML alerts, and large transactions.

Definition of done:

```text
Risk blocks are explainable, auditable, and recoverable through approved
operator workflows.
```

## Phase 10: Operational Control Room

Status:

```text
NOT_STARTED
```

Goal:

```text
Give ORBI operators full visibility and safe controls.
```

TODO:

- Payment intent monitor.
- Hosted challenge monitor.
- Escrow lifecycle monitor.
- Stuck transaction monitor.
- Webhook delivery monitor.
- Provider health monitor.
- Merchant status monitor.
- User/session status monitor.
- Risk queue.
- Dispute queue.
- Refund queue.
- Manual recovery workflows with dual-control.
- API key and webhook-secret rotation approval console.
- Merchant/service suspension console.
- Consent revocation console.
- Sandbox/live promotion console.
- Ledger-safe recovery commands that never require manual SQL updates.
- Incident timeline view across Core, Pay Gateway, Auth, webhooks, and provider
  callbacks.

Definition of done:

```text
Operations can identify, explain, and resolve platform issues without editing
database rows manually.
```

## Phase 11: Production Hardening

Status:

```text
NOT_STARTED
```

Goal:

```text
Make the platform resilient enough for real scale.
```

TODO:

- Contract tests.
- Gateway/Core integration tests.
- Sandbox smoke tests.
- Live smoke tests.
- Load and timeout tests.
- Backup/restore drills.
- Disaster recovery drills.
- Key rotation runbooks.
- TLS/mTLS roadmap.
- Observability dashboards.
- SLOs for challenge, payment intent, webhook, and escrow.
- Production certification checklist for every external service.
- Security review for service-key custody and webhook signing.
- Penetration testing for hosted challenge, webhook endpoints, and service
  onboarding.
- Privacy/data-retention policy for merchant/customer identities and consent
  receipts.
- Availability target and error budget policy.
- Blue/green or canary deployment process for Core and Pay Gateway changes.
- Backward-compatibility matrix for public API versions.

## Phase 12: Developer Portal UI And Public Launch

Status:

```text
NOT_STARTED
```

Goal:

```text
Turn the contracts and bootstrap endpoints into a polished self-service
developer experience.
```

TODO:

- Developer Portal frontend for service applications.
- Sandbox/live key management screens.
- Scope request and approval screens.
- Redirect and webhook allowlist screens.
- Webhook delivery logs, replay, and failure explanation screens.
- Integration health dashboard.
- API docs browser.
- SDK download pages.
- Sandbox tools UI.
- Merchant launch checklist UI.
- Developer support/contact workflow.
- Public documentation site for Open Banking/BaaS.

Definition of done:

```text
An approved merchant can integrate ORBI from docs and portal without direct
engineering intervention, while ORBI operators retain approval and risk
control.
```

## Phase 13: External Account And Service APIs

Status:

```text
NOT_STARTED
```

Goal:

```text
Expose banking-grade account, balance, profile, payment, and service APIs in a
controlled way.
```

TODO:

- Account information API for consented balance/profile reads.
- Transaction list API with consent and audit filters.
- Payment initiation API for approved service rails.
- PaySafe escrow lifecycle API for third-party platforms.
- Refund/dispute API for service-originated cases.
- Payout/withdrawal initiation API where approved.
- Statement/reporting API.
- Event subscription API.
- Service status API.
- API version negotiation.
- Rate limits by service, user, scope, and risk tier.

Definition of done:

```text
External platforms can build useful financial products on ORBI without direct
database access or ledger bypass.
```

## Phase 14: Certification And Partner Readiness

Status:

```text
NOT_STARTED
```

Goal:

```text
Make ORBI safe to open to real external partners at scale.
```

TODO:

- Partner certification checklist.
- Sandbox test-case completion evidence.
- Live pilot approval process.
- Production risk acceptance workflow.
- Partner incident response agreement.
- Partner data-processing agreement.
- Service-level support model.
- Compliance review before live access.
- Periodic recertification.
- Partner offboarding and key revocation procedure.

Definition of done:

```text
Every live partner has passed a documented technical, operational, security,
and compliance gate.
```

## Phase 15: Bank-Grade Enterprise Open Banking Readiness

Status:

```text
IN_PROGRESS
```

Goal:

```text
Make ORBI acceptable for large-bank integration, sponsored participant
connectivity, regulated partner review, and enterprise BaaS/Open Banking
operations.
```

This phase is stricter than developer launch. A feature is not bank-ready just
because it works in production. It must have controls, evidence, monitoring,
fail-closed behavior, and recovery procedures.

Workstream 1: Transport And Runtime Trust

- Enforce live mTLS between Gateway and Core during an approved maintenance
  window.
- Keep HMAC signed worker callbacks permanently enabled after mTLS cutover.
- Add certificate expiry monitoring and alerting.
- Document certificate issuance, storage, rotation, and emergency revocation.
- Add mTLS smoke tests to live release gates.
- Add partner/bank mTLS profile support for direct bank or clearing
  integration.

Workstream 2: OAuth2/OIDC And Consent Authority

- Finalize OAuth2/OIDC authorization-code with PKCE for browser/mobile-safe
  flows.
- Finalize client-credentials flow for approved server-to-server services.
- Add token introspection and revocation endpoints.
- Add dynamic client registration only through approved developer portal
  workflows.
- Bind scopes to consent receipts, service identity, environment, and risk
  policy.
- Enforce scope and consent checks consistently in Core and Pay Gateway.
- Add consent renewal, expiry, and revocation notifications.

Workstream 3: Key Custody And Secrets Governance

- Move live secret custody to a formal encrypted secrets store/KMS-compatible
  model.
- Define key ownership for Core, Gateway, Portal, SDK publishing, webhook
  signing, worker signing, mTLS, and provider credentials.
- Add key rotation calendar and dual-control rotation approval.
- Add break-glass access policy with audit evidence.
- Ensure backups can restore encrypted secrets only with approved recovery
  keys.
- Remove every development fallback that can affect live financial flows.

Workstream 4: Reconciliation And Financial Truth

- Build daily Core/Gateway/provider reconciliation exports.
- Reconcile merchant order, payment intent, PaySafe escrow, Core ledger,
  provider proof, webhook delivery, and final merchant state.
- Add exception queues for stuck, mismatched, duplicated, reversed, and
  disputed movements.
- Add signed report export hashes.
- Add immutable idempotency replay/reuse reports.
- Add balance and settlement statements for merchants and platforms.

Workstream 5: Observability, SIEM, And Incident Response

- Add dashboards for Core, Gateway, Auth, Portal, webhooks, mTLS, provider
  health, queue depth, reconciliation, and risk decisions.
- Stream audit/security events to SIEM-compatible sinks.
- Add alert policy for failed callbacks, webhook spikes, risk blocks, mTLS
  expiry, auth anomalies, and ledger/reconciliation mismatches.
- Add SLOs and error budgets for hosted challenge, payment intent creation,
  Core settlement callback, webhook delivery, and reconciliation.
- Add incident runbooks with owner, severity, rollback path, and customer
  communication policy.

Workstream 6: Security Testing And Compliance Evidence

- Complete threat model for Core, Gateway, Portal, SDK, hosted challenge,
  webhooks, and merchant callbacks.
- Run penetration tests for hosted challenge, webhook replay, developer portal,
  service onboarding, and financial commit endpoints.
- Add SAST/dependency scanning to release gates.
- Add DAST smoke checks for public Gateway and Developer Portal routes.
- Add data-retention policy for consent receipts, identity metadata,
  transaction evidence, webhook payloads, and audit events.
- Add regulatory export package for AML/risk alerts, large transactions,
  disputes, refunds, and consent evidence.

Workstream 7: Bank/Provider Certification Pack

- Produce ISO 20022 message samples and validation evidence for `pacs.008`,
  `pacs.002`, and `pacs.004`.
- Produce OpenAPI contract package for payment intent, PaySafe escrow,
  payment profile, consent, webhooks, and developer operations.
- Produce sandbox test evidence for success, timeout, duplicate idempotency,
  failed challenge, refund, dispute, expired escrow, webhook replay, and
  reconciliation.
- Produce operational architecture diagram and data-flow diagram.
- Produce partner onboarding checklist and technical questionnaire answers.
- Produce live pilot checklist and rollback plan.

Definition of done:

```text
ORBI can enter a large-bank or regulated partner technical review with
evidence for transport security, OAuth/consent, key custody, reconciliation,
auditability, incident response, SDK contracts, sandbox/live separation, and
partner certification readiness.
```

Definition of done:

```text
ORBI can prove reliability, rollback safety, auditability, and operational
readiness before opening broader third-party access.
```

## Execution Rule

Before starting any new phase:

```text
1. Confirm the previous phase definition of done.
2. Update docs.
3. Add tests or smoke checks.
4. Deploy safely.
5. Verify logs and health.
6. Mark the phase complete in this roadmap.
```

This roadmap is the working checklist. If a new idea appears, add it here first
unless it is an urgent production fix.
