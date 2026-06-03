# ORBI Business Operational Playbook

**Classification:** ORBI BUSINESS / OPERATIONS / PLATFORM CONTROL  
**Status:** Canonical business and operating model manual  
**Audience:** Founders, operators, compliance, support, finance, product, engineering, partners  
**Last updated:** 2026-06-03

## 1. Purpose

ORBI Financial OS is a secure financial operating system for wallets, accounts, providers, payments, FX, fees, settlement, risk, support, and operational governance. This playbook explains how ORBI operates as a business and platform: who uses it, how money moves, how staff control risk, how merchants and agents work, and how the admin portal drives the backend.

This is the business manual. Technical contracts still live in the API, schema, deployment, and SDK documents referenced by [DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md).

## 2. Operating Principles

- Backend is the source of truth.
- Every financial movement must be double-entry and ledger-backed.
- No staff member can directly edit balances.
- Refunds, reversals, payouts, commissions, and repairs must reference a source transaction, source wallet, or operational ORBI account.
- Every operator action must be auditable by actor, role, route, timestamp, device, trace, reason, and target.
- Dangerous actions require reason capture, permission gating, and audit output.
- Automated locks/freezes must attach reasons so support and compliance can resolve cases.
- Messaging must use approved ORBI Talk templates for customer-facing communications.
- The portal is the control room, not a database editor.

## 3. Business Model

ORBI runs a B2C, B2B, and B2B2C financial operating model.

### B2C: Consumers

Consumers use ORBI for wallets, transfers, bills, savings goals, shared pots, shared budgets, escrow/TrustBridge, external funds, and account security.

Primary business value:
- safe money movement
- wallet and ledger trust
- personal wealth controls
- customer support and dispute resolution
- security-first account protection

### B2B: Organizations

Organizations use ORBI for treasury, limits, cost centers, departmental budgets, maker-checker approvals, and organization-level risk controls.

Primary business value:
- business account governance
- organization spending limits
- treasury reserves and auto-sweep logic
- employee role separation
- audit and compliance visibility

### B2B2C: Merchants And Agents

Merchants and agents serve end customers through ORBI.

Merchants:
- accept payments
- view merchant transactions
- configure settlement destination/schedule
- register customers when permitted
- receive settlement reports

Agents:
- register customers
- support cash deposit and withdrawal workflows
- hold operational float
- earn commissions where configured
- operate under float controls and dispute governance

## 4. Role Model

### Platform Staff Roles

| Role | Operational Scope |
| :--- | :--- |
| `SUPER_ADMIN` | Full platform control, bootstrap, high-risk decisions, break-glass actions. |
| `ADMIN` | Platform operations, configuration, staff support, service access review. |
| `ACCOUNTANT` | Fees, reconciliation, merchant settlement reports, commission review. |
| `AUDIT` | Read-only audit, transaction review, evidence collection. |
| `CUSTOMER_CARE` | User support, tickets, service access visibility, customer messaging. |
| `HUMAN_RESOURCE` | Staff lifecycle, employee roles, employee profile management. |
| `RISK_OFFICER` | Risk alerts, freezes, broker thresholds, B2B risk dashboards. |
| `FRAUD` | Fraud investigation, risk review, suspicious activity analysis. |
| `MARKETING` | Approved campaign/template messaging only. |
| `IT` | Infrastructure visibility, safe deployment and technical operations. |

### Public Roles

| Role | Operational Scope |
| :--- | :--- |
| `USER` / `CONSUMER` | Normal retail financial use. |
| `MERCHANT` | Merchant account, customer payment acceptance, merchant customer registration. |
| `AGENT` | Cash service desk, agent customer registration, float operations, commissions. |

## 5. Money Movement Model

ORBI uses a closed-loop money lifecycle:

1. Preview calculates fees, FX, provider readiness, risk context, and user-facing confirmation data.
2. Commit/settle requires idempotency and immutable preview context.
3. Ledger posting writes balanced entries.
4. Transaction lifecycle updates status.
5. Reconciliation verifies internal and external state.
6. Messaging notifies required parties through ORBI Talk.
7. Admin and audit surfaces expose results without allowing direct balance edits.

Forbidden actions:
- manual balance editing
- silent commit retry
- refund without source context
- account/wallet lock without reason
- provider config commit without preview/diff
- exposing provider or monitor secrets in browser state

## 6. ORBI Operational Accounts

Operational ORBI accounts represent platform-owned money positions used for controlled flows such as:

- platform funding
- salary and payroll funding
- fee collection
- tax/government fee collection
- settlement clearing
- suspense and reconciliation holds
- promotional credits
- escrow/PaySafe reserves

Rules:
- Funds can be created into user or service accounts only through approved operational source wallets.
- Operational account movements must still be double-entry.
- Every platform funding action requires actor, reason, source, target, and ledger evidence.

## 7. Merchant Operations

Merchant operations are business-payment projections over the canonical ledger.

Core records:
- `merchants`
- `merchant_wallets`
- `merchant_transactions`
- `merchant_settlements`
- `merchant_settlement_reports`

Control room duties:
- approve merchant service access
- monitor merchant payment success/failure
- configure settlement destination and schedule
- generate merchant settlement reports
- investigate delayed provider callbacks
- create support tickets and customer messaging

Merchant payment flow:
1. Customer or merchant initiates payment preview.
2. Backend resolves merchant context and fees.
3. Customer wallet is debited through canonical ledger posting.
4. Merchant projection is credited for reporting.
5. Settlement lifecycle handles payout readiness.
6. ORBI Talk sends transactional messages to relevant parties.

## 8. Agent Operations

Agents are service actors for field operations, especially customer onboarding and cash-in/cash-out workflows.

Core records:
- `agents`
- `agent_wallets`
- `agent_transactions`
- `agent_float_controls`
- `service_actor_customer_links`
- `service_commissions`
- `service_commission_disputes`

Agent capabilities:
- register customers through `/v1/agent/customers/register`
- list sponsored customers
- preview and settle cash deposit/withdrawal flows
- view commissions
- operate within configured float controls

Control room duties:
- approve agent access
- configure float policy
- review cash-in/out pressure
- handle commission disputes
- freeze/suspend agent access with reasons when risk exceeds threshold

## 9. Commission And Fee Model

All merchant, agent, and system fees should resolve through `platform_fee_configs`.

Canonical flow codes:
- `MERCHANT_PAYMENT`
- `AGENT_CASH_DEPOSIT`
- `AGENT_CASH_WITHDRAWAL`
- `AGENT_REFERRAL_COMMISSION`
- `AGENT_CASH_COMMISSION`
- `SYSTEM_OPERATION`

Commission lifecycle:
1. Source transaction settles.
2. Commission is staged in `service_commissions`.
3. Commission becomes payable only when policy conditions are met.
4. Disputes are opened in `service_commission_disputes`.
5. Payout is a separate ledger-backed transaction.

## 10. Organization-Level Controls

Organizations are the root for B2B tenants.

Core records:
- `organizations`
- `organization_members`
- `treasury_approvers`
- `organization_limit_configs`
- corporate `goals`
- corporate `categories`

Organization limits include:
- max amount per transaction
- daily limit
- monthly limit
- maker-checker threshold
- auto-freeze threshold

Enterprise operations:
- onboarding organization
- assigning organization admins and finance users
- setting departmental budgets
- treasury withdrawal approval
- auto-sweep reserves
- enforcing hard limits

## 11. Risk And Security Operations

ORBI risk operations combine automated and human controls.

Automated controls:
- velocity checks
- impossible travel/geographic checks
- high-risk transaction scoring
- suspicious route/funding detection
- dynamic broker alerts
- auto-freeze rules with reason capture
- stale transaction recovery logic

Human controls:
- risk dashboard review
- transaction hold/reversal review
- account and wallet freeze resolution
- support ticket linking
- audit evidence export

Every freeze/deactivation/lock must include:
- reason
- reason code where possible
- actor or automation source
- timestamp
- affected entity
- resolution path

## 12. Support And Case Management

Support must be able to resolve user, merchant, agent, and organization cases without database access.

Common support cases:
- incomplete registration
- OTP/account activation support
- stuck transaction
- provider callback delay
- merchant settlement question
- commission dispute
- wallet lock/freeze review
- KYC/document issue
- escrow dispute

Support standards:
- create or link a ticket for every meaningful customer issue
- never expose internal secrets or monitor keys
- use approved templates for customer messages
- keep internal notes separate from customer-facing copy

## 13. Messaging And ORBI Talk

ORBI Core sends messages through ORBI Talk Gateway.

Channels:
- SMS
- email
- push
- WhatsApp where available
- internal portal/operator alerts

Channel policy:
- OTP and account activation use SMS and email for consistency.
- Security-critical events use SMS/email/push where appropriate.
- Marketing uses approved promotional templates and permission checks.
- Not every SMS becomes email; customer experience and regulatory purpose decide channel mix.

Template rules:
- use official template names
- support `en` and `sw`
- keep variables explicit
- automated backend flows must supply variables
- staff portal sends should use templates suitable for staff-initiated support, marketing, or case updates

## 14. Admin Portal Operating Model

The ORBI Platform Admin Portal is the control plane for:

- users and accounts
- staff and roles
- support tickets
- KYC/documents/devices
- transactions and ledger review
- merchants and agents
- B2B risk
- provider/routing/fees/FX
- reconciliation
- operational alerts
- messaging templates and direct messaging
- configuration bootstrap
- IT/Ops visibility

Portal rules:
- no hidden database editing
- no secret exposure
- no dangerous mutation without confirmation
- no final financial truth calculated only in frontend
- all backend errors should show operator-readable context plus original code

## 15. B2B Operations Dashboard

The B2B operations dashboard should answer:

- Are merchant payments healthy?
- Which merchants need settlement review?
- Which agents have low or excessive float?
- Which commissions are disputed?
- Which organizations are near or above limits?
- Which service access requests are pending?
- What B2B risk score is active now?

Core backend surfaces:
- `GET /v1/admin/b2b/risk-dashboard`
- `GET /v1/admin/b2b/merchant-settlement-reports`
- `POST /v1/admin/b2b/merchant-settlement-reports/generate`
- `GET /v1/admin/b2b/agent-float-controls`
- `POST /v1/admin/b2b/agent-float-controls`
- `GET /v1/admin/b2b/agent-float-dashboard`
- `GET /v1/admin/b2b/commission-disputes`
- `POST /v1/admin/b2b/commission-disputes`
- `PATCH /v1/admin/b2b/commission-disputes/:id`
- `GET /v1/admin/b2b/organization-limits`
- `POST /v1/admin/b2b/organization-limits`

## 16. Daily Operating Rhythm

Morning:
- confirm health/readiness
- review operator alerts
- check stuck transactions and reconciliation reports
- review high-risk alerts
- review pending service access requests

Midday:
- monitor provider health
- review support queue
- inspect merchant/agent exceptions
- handle commission disputes

Evening:
- generate settlement reports where needed
- review agent float pressure
- inspect organization limits and treasury requests
- capture release or incident evidence if applicable

Always:
- keep audit trail intact
- require reasons for sensitive actions
- resolve alerts with evidence
- avoid manual balance intervention

## 17. Escalation Matrix

| Incident | First Owner | Escalation |
| :--- | :--- | :--- |
| High-risk transaction | Risk Officer | Admin, Audit |
| Ledger mismatch | Accountant | Admin, Engineering |
| Provider outage | IT/Ops | Admin, Provider owner |
| Customer fraud report | Customer Care | Fraud, Risk Officer |
| Merchant settlement delay | Accountant | Provider Ops, Admin |
| Agent float breach | Risk Officer | Admin, Customer Care |
| Commission dispute | Accountant | Admin, Audit |
| KMS or secret event | IT/Ops | Super Admin, Security |
| Database incident | Engineering | DR owner, Audit |

## 18. Canonical References

- Technical architecture: [Core Banking Architecture](./CORE_BANKING_ARCHITECTURE.md)
- Production deployment: [Production Deployment](./PRODUCTION_DEPLOYMENT.md)
- Environment variables: [Environment Variables Reference](./ENVIRONMENT_VARIABLES_REFERENCE.md)
- Admin SDK: [ORBI Admin Frontend API SDK](./ORBI_ADMIN_FRONTEND_API_SDK.md)
- Provider registry: [Provider Registry Contract](./PROVIDER_REGISTRY_CONTRACT.md)
- ORBI Talk templates: [ORBI Talk Gateway Templates](./ORBI_TALK_GATEWAY_TEMPLATES.md)
- Reconciliation: [Reconciliation Engine](./RECONCILIATION_ENGINE.md)
- Disaster recovery: [Disaster Recovery Runbook](./DISASTER_RECOVERY_RUNBOOK.md)
