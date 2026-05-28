# ORBI Platform Admin UI Gemini Prompt

Copy this prompt into Gemini AI Studio. It intentionally does not prescribe the visual UI. It explains the ORBI Financial OS backend, operating model, integration requirements, security constraints, and admin responsibilities so Gemini can understand the platform first, then propose the right frontend architecture.

```text
You are a senior fintech platform architect, backend integration engineer, product systems designer, and frontend application architect.

Your task is to design the frontend architecture for the ORBI Financial OS Platform Admin Console based on the backend operating model described below. Do not start by drawing generic dashboard cards. First understand the platform, its money movement model, governance rules, transaction lifecycle, provider configuration model, admin controls, and security requirements. Then propose and implement a frontend structure that lets authorized ORBI operators run the platform safely.

Product identity:
- Product name: ORBI FINANCIAL OS
- Product meaning: a secure financial operating system for wallets, accounts, providers, payments, FX, fees, settlement, risk, support, and operational governance.
- Suggested human-facing phrase: "Your secure financial platform"

Primary frontend objective:
Build a professional admin console that lets ORBI operators manage and monitor the financial platform without manually editing database rows, SQL, environment files, provider rows, fee rows, routing rules, or secret records.

API SDK reference:
Use the ORBI Admin Frontend API SDK as the implementation contract for frontend data access:
- docs/ORBI_ADMIN_FRONTEND_API_SDK.md
- docs/orbi-admin-sdk.ts
The SDK groups all known functional backend connections across auth, admin transactions, users, staff, KYC, documents, devices, audit, risk, support, messaging, provider configuration, routing, fees, reconciliation, monitor telemetry, core finance, commerce, external funds, gateway, and wealth/shared finance workflows.

Do not over-focus on visual design in the first pass. Focus on information architecture, operating workflows, safe action design, API contracts, validation, and backend integration. After the architecture is correct, propose the UI layout yourself.

Core backend architecture:
ORBI Core is an Express + TypeScript backend with modular route registration, Zod validation, Supabase persistence, Redis-backed infrastructure where configured, audit logging, transaction governance, provider routing, settlement lifecycle, webhook verification, and operational monitoring.

Important technologies:
- Node.js 22
- Express 5
- TypeScript
- Zod for request validation
- Supabase/Postgres for persistence
- Redis/ioredis for monitoring/session/fraud/cache tiers where configured
- Docker deployment
- Nginx + TLS in production
- GitHub-based deployment workflows
- Mobile app and Gateway app consume backend APIs

Primary production endpoints:
- Primary ORBI Core API: https://api.orbifinancial.com
- Fallback ORBI Core API: https://go-api.orbifinancial.com
- Gateway backend: https://gateway.orbifinancial.com

Frontend API rule:
The admin console should present ORBI as one financial platform, not as a server chooser. Use the primary API as default:
- VITE_ORBI_API_BASE_URL=https://api.orbifinancial.com

Fallback API may be used only for safe read/health behavior when explicitly configured:
- VITE_ORBI_FALLBACK_API_BASE_URL=https://go-api.orbifinancial.com

Gateway backend is a separate service behind a custom domain:
- VITE_ORBI_GATEWAY_BASE_URL=https://gateway.orbifinancial.com

Normal operators should not manually switch between AWS, Google, and Gateway backends. Infrastructure target switching should not be a main product concept. If infrastructure status is shown, it belongs in an IT/Ops area as read-only visibility or carefully controlled deployment tooling.

Backend route families:
The backend exposes several route namespaces:
- /health, /ready, /health/deep for public health readiness checks.
- /v1/... for main product and admin-facing routes.
- /api/v1/... may exist as legacy fallback in some clients.
- /api/admin/... for newer admin/system routes.
- /api/admin/monitor/... for protected monitor/operations routes.
- /v1/gateway/... for payment gateway routes.
- /v1/webhooks/gateway/:providerId for gateway/provider webhooks.

Authentication model:
The admin console must use the ORBI Core admin auth/session model.

All normal admin requests should include:
- Authorization: Bearer <token>
- x-orbi-app-id
- x-orbi-app-origin
- x-orbi-trace
- x-orbi-device-id when available
- Content-Type: application/json

Do not hardcode secrets in frontend code.
Do not store provider secrets or monitor keys in browser localStorage.
Do not print secrets to the console.
Do not display submitted secrets after save.
Mask secrets in previews, logs, payload summaries, and error views.

Monitor endpoint security:
The /api/admin/monitor/* endpoints require ORBI_MONITOR_API_KEY. This key must not be exposed to ordinary browser clients. If the admin console is hosted as a browser app, use a backend-for-frontend proxy or internal admin API that holds the monitor key server-side and returns only authorized summaries.

User and role model:
ORBI supports multiple user and operator classes:
- Consumer users
- Merchant/service actors
- Agent/service actors
- Staff/admin users
- Super admin
- Admin
- IT
- Audit
- Accountant
- Customer care
- Human resource

Frontend authorization must be role-aware. Do not show dangerous controls to roles that cannot use them. Backend still remains source of truth and must enforce permissions.

Complete role and permission model:
The backend uses role checks and permission checks together. A session may be allowed because its role is in an allowed role group or because it carries a required permission string. Account status matters: inactive/pending/blocked/frozen staff should effectively have no permissions.

Documented staff/operator roles:
- SUPER_ADMIN
- ADMIN
- IT
- AUDIT
- ACCOUNTANT
- CUSTOMER_CARE
- HUMAN_RESOURCE

Extended institutional/operator roles used by route groups:
- FRAUD
- RISK_OFFICER
- MARKETING
- STAFF as a legacy alias

Customer/service roles:
- CONSUMER
- USER
- MERCHANT
- AGENT
- SYSTEM

Permission strings used by backend sessions:
- auth.login
- auth.logout
- auth.refresh
- auth.pwd_reset
- user.read
- user.update
- user.freeze
- wallet.read
- wallet.create
- wallet.update
- wallet.delete
- wallet.credit
- wallet.debit
- wallet.freeze
- transaction.create
- transaction.view
- transaction.verify
- transaction.reverse
- transaction.delete
- ledger.read
- ledger.write
- admin.approve
- admin.freeze
- admin.audit.read
- admin.user.manage
- staff.read
- staff.write
- provider.read
- provider.write
- institutional_account.read
- institutional_account.write
- provider_routing.read
- provider_routing.write
- config.ledger.read
- config.ledger.write
- config.fx.read
- config.fx.write
- config.commissions.read
- config.commissions.write
- reconciliation.read
- reconciliation.run
- device.read
- device.trust.manage
- kyc.review
- document.review
- service_access.review
- system.wallet.credit
- system.wallet.debit
- goal.read
- goal.create
- goal.update
- goal.delete
- category.read
- category.create
- category.update
- category.delete
- task.read
- task.create
- task.update
- task.delete
- merchant.read
- merchant.create
- merchant.update
- merchant.settlement
- agent.cash.deposit
- agent.cash.withdraw
- agent.float.manage

Role capability summary:
- SUPER_ADMIN: highest platform authority. Can manage users, wallets, transactions, reversals, deletion, ledgers, audit, staff, providers, institutional accounts, routing, FX, commissions, reconciliation, devices, KYC, documents, service access, and system wallet operations.
- ADMIN: general platform administrator. Can view/update wallets, verify transactions, read ledgers, approve admin actions, read audit, manage users/staff, manage providers, institutional accounts, routing, FX/config, commissions, reconciliation, devices, KYC, documents, and service access.
- IT: infrastructure and configuration operator. Can read audit, manage provider and routing configuration, manage institutional accounts, manage device trust, read ledger config, read FX config, and support system wallet technical operations where backend permits.
- AUDIT: read/review role. Can view wallets, transactions, ledgers, audit trail, reconciliation reports, staff records/activity, risk alerts, and support/message history. Should generally not mutate financial configuration.
- ACCOUNTANT: finance/reconciliation role. Can view wallets, transactions, ledgers, reconciliation reports, commission config, and FX config. Should focus on financial reporting, settlement, fees, and reconciliation visibility.
- CUSTOMER_CARE: customer operations role. Can view transactions, review KYC/documents, review service access, view/search users, support tickets, staff/user messages where allowed, and help customers resolve operational issues.
- HUMAN_RESOURCE: workforce/user administration role. Can manage staff, view staff activity, manage user/account status where permitted, view support and message history, and review service access where configured.
- FRAUD/RISK_OFFICER: risk review extension roles. Should be used for AML, anomaly, risky account, provider anomaly, and transaction risk review workflows where backend route groups allow them.
- MARKETING: messaging extension role. Should only access approved promotional/template messaging surfaces where backend route groups allow it.
- MERCHANT: service actor. Can read wallet/merchant data, create/view transactions, update merchant profile/workflows, and access merchant settlement functions.
- AGENT: service actor. Can read wallet/agent data, create/view transactions, perform cash deposit/withdraw workflows, and manage agent float.
- CONSUMER/USER: standard user roles. Can manage own profile, wallets, transactions, goals, categories, and tasks through user-facing APIs. These should not get admin console access unless deliberately provisioned.
- SYSTEM: internal/system identity. Do not build ordinary UI flows for SYSTEM.

Backend role groups used by admin routes:
- ADMIN_ONLY_ROLES: SUPER_ADMIN, ADMIN, IT
- SUPER_ADMIN_AND_ADMIN_ROLES: SUPER_ADMIN, ADMIN
- TRANSACTION_OVERVIEW_ROLES: ADMIN, SUPER_ADMIN, AUDIT, CUSTOMER_CARE, ACCOUNTANT
- TRANSACTION_REVIEW_ROLES: ADMIN, SUPER_ADMIN, AUDIT, CUSTOMER_CARE
- AUDIT_DECISION_ROLES: ADMIN, SUPER_ADMIN, AUDIT
- DOCUMENT_VERIFICATION_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE
- STAFF_ADMIN_ROLES: ADMIN, SUPER_ADMIN, HUMAN_RESOURCE
- STAFF_AUDIT_ROLES: ADMIN, SUPER_ADMIN, HUMAN_RESOURCE, AUDIT
- SERVICE_ACCESS_READ_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, AUDIT, HUMAN_RESOURCE
- SERVICE_ACCESS_REVIEW_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, HUMAN_RESOURCE
- USER_ADMIN_ROLES: ADMIN, SUPER_ADMIN, HUMAN_RESOURCE
- USER_SEARCH_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, AUDIT, HUMAN_RESOURCE
- RISK_REVIEW_ROLES: ADMIN, SUPER_ADMIN, AUDIT, IT, RISK_OFFICER
- STAFF_MESSAGE_READ_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, AUDIT, HUMAN_RESOURCE, IT
- STAFF_MESSAGE_SEND_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, HUMAN_RESOURCE, IT
- STAFF_MESSAGE_FLAG_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, AUDIT, IT
- SUPPORT_TICKET_VIEW_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, AUDIT, HUMAN_RESOURCE
- SUPPORT_TICKET_MANAGE_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, HUMAN_RESOURCE
- MARKETING_MESSAGE_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, MARKETING, IT
- SYSTEM_SMS_ROLES: ADMIN, SUPER_ADMIN, CUSTOMER_CARE, IT
- RECONCILIATION_RUN_ROLES: ADMIN, SUPER_ADMIN, AUDIT
- RECONCILIATION_REPORT_ROLES: ADMIN, SUPER_ADMIN, AUDIT, ACCOUNTANT
- CONFIG_LEDGER_ADMIN_ROLES: ADMIN, SUPER_ADMIN
- CONFIG_COMMISSION_VIEW_ROLES: ADMIN, SUPER_ADMIN, ACCOUNTANT
- CONFIG_FX_VIEW_ROLES: ADMIN, SUPER_ADMIN, ACCOUNTANT, IT

Admin UI RBAC requirements:
- Build a permission map from the authenticated session.
- Hide modules that the role cannot access.
- Disable dangerous actions when permission is missing, with clear explanation.
- Show read-only versions of sensitive pages for audit/accounting roles where appropriate.
- Always let backend be final authority; frontend gating is for UX and safety only.
- Include a "Permissions Preview" admin tool using GET /v1/admin/permissions/preview?role=<ROLE>&status=<STATUS> so operators can see effective permissions before assigning or changing staff roles.
- Surface empty permission state for inactive/pending/blocked/frozen staff.

Activity and audit model:
Every sensitive operator action should be visible as platform activity. The admin console should treat activity as a first-class platform object, not a hidden log.

Activity categories to display:
- Auth activity: login, logout, login_failed, biometric_login, password_change, password reset, session anomaly.
- Security activity: network_attack_blocked, WAF_INTERCEPT, suspicious login, device trust changes, brute-force lock, sensitive action verified/failed.
- Governance activity: role elevation, account status update, staff creation/update, permission preview, service access approval/rejection.
- User/KYC activity: KYC submitted, KYC approved/rejected, document uploaded, document verified/rejected, profile update.
- Money movement activity: transaction preview, transaction created, transaction verified, transaction failed, transaction reversed, settlement started, settlement completed, ledger posted, reconciliation run.
- Wallet activity: wallet created, updated, locked, unlocked, frozen, credited, debited.
- Provider activity: provider created/updated/deleted, provider config version saved, provider routing rule created/updated/deleted, provider webhook received, provider timeout, provider anomaly.
- Fee/FX activity: FX rates updated, FX fee updated, platform fee config created/updated, missing fee config warning.
- Messaging/support activity: staff message sent, system SMS sent, template preview, template send, support ticket opened/updated/resolved.
- Infrastructure activity: health degraded/recovered, Redis instability, DB/RPC warning, deployment/commit visibility, audit integrity compromised.

Activity UI requirements:
- Every activity row should show actor, role, action, target, timestamp, status, risk/severity, related transaction/wallet/provider/user, and trace/request ID when available.
- Sensitive activity should show the audit hash/signature if returned by backend.
- The UI must make it easy to filter by actor, event type, action, transaction ID, user/wallet/provider, severity, and date range.
- Staff detail pages should link to GET /v1/admin/staff/:id/activity.
- Global audit timeline should use GET /v1/admin/audit-trail.
- Risk queues should use GET /v1/admin/risk/alerts.
- Do not invent audit events in frontend; display backend-returned events and add frontend-only annotations separately.

Current backend audit support and required enhancement:
The backend already has an immutable audit ledger through Audit.log(...), persisted in audit_trail with prev_hash, hash, signature, actor_id, transaction_id, action, metadata, and timestamp. It also broadcasts audit events in real time and exposes audit retrieval through /v1/admin/audit-trail and staff activity through /v1/admin/staff/:id/activity.

The backend already audits many critical flows:
- account status changes
- staff profile/password activity through SecurityService.logActivity
- service access review
- template/system SMS sends
- platform fee config changes
- institutional account config changes
- pricing rule rotation
- transaction commit/settlement/reversal
- payment gateway initiation/settlement/refund/dispute
- external fund movement lifecycle
- settlement lifecycle transitions/failures
- webhook signature failures/replay/duplicates/processed/application failures
- provider anomalies
- reconciliation runs and discrepancies
- security and infrastructure alerts

However, do not assume every admin read/write is automatically audited today. Some admin reads are only permission-checked and returned. Some writes store created_by/updated_by fields but are not yet guaranteed to call Audit.log(...). Examples that should be reviewed/hardened before enterprise launch:
- KYC review updates reviewer_id/reviewed_at but should also emit immutable KYC_REVIEWED audit events.
- Document verification updates verified_by/verified_at but should also emit immutable DOCUMENT_VERIFIED/DOCUMENT_REJECTED audit events.
- Support ticket create/update stores created_by/updated_by but should also emit SUPPORT_TICKET_CREATED/UPDATED/RESOLVED audit events.
- Direct staff messages should emit immutable STAFF_DIRECT_MESSAGE_SENT audit events, not only save the message row.
- Sensitive read access such as user profile view, wallet forensics, document view, KYC detail view, and transaction detail view should optionally emit ACCESS_VIEWED audit events for worker accountability.

For the admin console, design as if enterprise worker accountability is mandatory:
- Every write action must be recorded with actor, role, target, action, timestamp, request trace, IP/device where available, and before/after/diff metadata where safe.
- Sensitive read actions should be tracked, especially customer account detail views, KYC/document views, wallet forensic views, transaction detail views, staff activity views, and exported data.
- The frontend should pass x-orbi-trace on every request so backend audit records can connect UI action to API action.
- If a backend endpoint does not yet return or create audit records, mark it as an integration gap and do not fake audit history in the UI.
- Prefer a backend audit middleware or explicit route-level Audit.log(...) calls for every admin route.

Core business model:
ORBI is not just a wallet UI. It is a financial OS with:
- User identities
- Account and KYC status
- Wallets and wallet locks
- Institutional accounts
- Internal wallet transfers
- External fund movement
- Provider-based deposits/collections
- Provider-based disbursements/payouts
- Bill reserves
- Shared pots
- Shared budgets
- Goals and allocations
- Merchant/agent service access
- FX quote and conversion flows
- Platform fees, taxes, government fees, stamp duty
- Ledger-backed balances
- Reconciliation and forensics
- Risk/compliance review
- Audit trail and integrity checks
- Notification and messaging templates
- Gateway integrations

Transaction and money movement principles:
The frontend must understand that every money movement is governed by backend rules. It must never assume the client can calculate final truth.

Backend owns:
- wallet resolution
- source wallet validation
- target wallet validation
- account/wallet status checks
- balance checks
- transaction rule checks
- provider readiness
- routing rule resolution
- FX quote readiness
- fee resolution
- tax/gov/stamp duty resolution
- idempotency
- transaction initialization
- settlement lifecycle
- ledger posting
- reversals
- audit logging
- webhook verification

The frontend must:
- request preview/quote before commit when supported
- show backend-returned validation issues clearly
- show source wallet and target wallet precisely
- block confirmation if backend says source and target are the same
- never edit transaction payload between preview and confirmation unless the user restarts preview
- preserve quote IDs, quote hashes, preview fingerprints, idempotency keys, and server-provided transaction context
- display clear failure states such as insufficient balance, missing fee config, missing FX rates, inactive provider, wallet locked, account frozen, routing missing, stale quote, or invalid webhook state

Ledger and balances:
Balances must be treated as ledger-derived backend truth. The UI should display balances returned by backend APIs but must not perform settlement math locally. For reconciliation or investigation flows, show ledger status, wallet forensic reports, and transaction timelines from backend endpoints.

Provider configuration model:
Providers are configured, not hardcoded.

Provider records include:
- provider code
- provider name
- provider type
- status
- logic type
- API base URL
- supported currencies
- provider metadata
- icon/color/display metadata if configured
- secret material such as client ID, client secret, API key, merchant ID, webhook secret, connection secret
- mapping config
- routing rules

Provider mapping config describes how ORBI calls a provider:
- service roots
- operation code
- HTTP method
- path
- request template
- response mapping
- callback path
- callback reference field
- callback status field

Supported operation codes include:
- AUTH
- ACCOUNT_LOOKUP
- COLLECTION_REQUEST
- COLLECTION_STATUS
- DISBURSEMENT_REQUEST
- DISBURSEMENT_STATUS
- PAYOUT_REQUEST
- PAYOUT_STATUS
- REVERSAL_REQUEST
- REVERSAL_STATUS
- BALANCE_INQUIRY
- TRANSACTION_LOOKUP
- WEBHOOK_VERIFY
- BENEFICIARY_VALIDATE

Routing rules decide which provider is used for a rail/country/currency/operation combination. Rails include:
- MOBILE_MONEY
- BANK
- CARD_GATEWAY
- CRYPTO
- WALLET

Admin provider workbench requirements:
The admin console must let operators:
- view providers
- understand provider readiness
- configure provider basics
- configure operation mappings
- configure callback/webhook mapping
- configure routing rules
- preview generated backend payloads
- validate config before saving
- save config through backend endpoints only
- understand what is missing before a provider can become active

Fee and FX model:
ORBI has configurable platform fee records. Fees can be scoped by:
- flow code
- transaction model
- category code/category ID
- transaction type
- operation type
- direction
- rail
- channel
- provider
- currency
- country
- wallet/account/tenant/business metadata where supported

FX requires:
- active FX rates
- active FX conversion fee configuration
- backend quote logic
- frontend display of quote result and failure reason

Fee values may include:
- percentage rate
- fixed amount
- minimum fee
- maximum fee
- tax rate
- government fee rate
- stamp duty fixed amount
- currency scope
- country scope
- metadata

Important fee helper:
- 0.01 means 1%
- 0.025 means 2.5%
- 1 means 100%

Admin config bootstrap endpoint:
Use this endpoint as the primary safe setup route for FX rates, FX fees, providers, provider config versions, and routing rules.

Endpoint:
- POST /api/admin/config/bootstrap

Modes:
- "preview": validate and return normalized plan without writing
- "commit": validate and write configuration

The UI must always preview before commit. The commit action must require explicit operator confirmation. Never retry commit blindly.

Example payload shape:
{
  "mode": "preview",
  "fx": {
    "rates": {
      "USD": 1,
      "TZS": 2550,
      "KES": 135,
      "UGX": 3900,
      "RWF": 1280,
      "EUR": 0.92,
      "GBP": 0.78
    },
    "fee": {
      "name": "Default FX conversion fee",
      "percentageRate": 0.01,
      "fixedAmount": 0,
      "minimumFee": 0,
      "maximumFee": null,
      "taxRate": 0,
      "govFeeRate": 0,
      "stampDutyFixed": 0,
      "currency": null,
      "countryCode": null,
      "status": "ACTIVE",
      "metadata": {}
    }
  },
  "providers": [
    {
      "providerCode": "MPESA_TZ",
      "name": "Vodacom M-Pesa",
      "type": "mobile_money",
      "status": "ACTIVE",
      "logicType": "GENERIC_REST",
      "apiBaseUrl": "https://provider.example.com",
      "clientId": "",
      "clientSecret": "",
      "apiKey": "",
      "merchantId": "",
      "webhookSecret": "",
      "connectionSecret": "",
      "supportedCurrencies": ["TZS"],
      "providerMetadata": {
        "rail": "MOBILE_MONEY",
        "countries": ["TZ"],
        "supports_webhooks": true,
        "supports_polling": true
      },
      "mappingConfig": {
        "service_roots": {
          "production": "https://provider.example.com"
        },
        "operations": {
          "COLLECTION_REQUEST": {
            "method": "POST",
            "path": "/collections",
            "request_template": {
              "amount": "{{amount}}",
              "currency": "{{currency}}",
              "phone": "{{recipient.phone}}",
              "reference": "{{reference}}"
            },
            "response_mapping": {
              "providerRef": "data.transaction_id",
              "status": "data.status",
              "message": "message"
            },
            "callback": {
              "path": "/webhooks/mpesa",
              "referenceField": "transaction_id",
              "statusField": "status"
            }
          }
        }
      },
      "routingRules": [
        {
          "rail": "MOBILE_MONEY",
          "countryCode": "TZ",
          "currency": "TZS",
          "operationCode": "COLLECTION_REQUEST",
          "priority": 100,
          "status": "ACTIVE",
          "conditions": {}
        }
      ]
    }
  ]
}

Gateway/payment API:
The backend includes gateway/payment routes mounted under /v1:
- GET /v1/gateway/providers
- POST /v1/gateway/payment/initiate
- POST /v1/gateway/payment/:orderId/settle
- POST /v1/gateway/payment/:orderId/refund
- GET /v1/gateway/orders
- GET /v1/gateway/order/:orderId
- GET /v1/gateway/settlement/:settlementId/status
- POST /v1/gateway/settlement/:settlementId/confirm
- POST /v1/gateway/settlement/:settlementId/dispute
- GET /v1/gateway/settlements
- GET /v1/gateway/scheduler/health
- POST /v1/webhooks/gateway/:providerId

External fund/provider routes:
- POST /v1/external-funds/preview
- POST /v1/external-funds/deposit-intents
- POST /v1/external-funds/settle
- GET /v1/external-funds/movements
- GET /v1/external-funds/movements/:id

These routes use Zod validation and backend transaction governance. Some settlement routes require idempotency keys.

Admin operations and audit:
The backend exposes operator-facing endpoints for audit, staff activity, and risk:
- GET /v1/admin/audit-trail
- GET /v1/admin/staff/:id/activity
- GET /v1/admin/risk/alerts
- GET /v1/admin/risk/geo-heatmap
- GET /v1/admin/risk/live-geo
- GET /v1/admin/compliance/node-zones/risk-density

Audit trail filters may include:
- limit
- eventType
- actorId
- transactionId
- action

Audit records include:
- id
- timestamp
- event_type
- actor_id
- transaction_id
- action
- metadata
- hash
- signature

Risk alerts combine AML alerts and provider anomaly details.

Risk geo heatmap:
- Use GET /v1/admin/risk/geo-heatmap for the Risk dashboard geographic heatmap.
- Query filters: days, countryCode, currency, minRiskScore, limit.
- The endpoint returns aggregated country/region buckets with transactionCount, riskSignalCount, alertCount, avgRiskScore, maxRiskScore, totalAmount, currencies, sources, intensity, and severity.
- It intentionally does not return raw coordinates. If mobile or admin clients collect location, send it only as consented transaction metadata under metadata.geo and treat it as a risk signal, not final truth.
- Recommended metadata.geo fields: countryCode, regionCode, region, city, source, accuracyMeters, capturedAt.
- Backend risk logic should compare client-provided geo against provider country, routing country, phone country, IP-derived country where available, KYC/profile country, and device history.
- Transaction preview enforces geo compliance. Missing location blocks preview with TRANSACTION_GEO_REQUIRED, denied consent blocks with TRANSACTION_GEO_CONSENT_REQUIRED, and impossible travel blocks with IMPOSSIBLE_GEO_TRAVEL.
- Impossible travel compares rounded current transaction coordinates against recent transaction metadata and estimates travel speed. Example: Tanga to Dar es Salaam within five minutes should be treated as a high-risk/impossible travel signal.

Compliance Node Zone risk density:
- Use GET /v1/admin/compliance/node-zones/risk-density for the infrastructure/control-plane risk-density heatmap.
- Query filters: windowHours, bucketHours, includeInactive.
- Compliance Node Zones are logical ORBI boundaries mapped to real infrastructure: ORBI-AWS-CORE-PRIMARY, ORBI-GCP-CORE-FALLBACK, ORBI-GATEWAY-EDGE, ORBI-LEDGER-AUTHORITY, ORBI-ADMIN-OPS, and ORBI-PROVIDER-RAILS.
- The endpoint returns zone metadata, currentRiskDensity, currentStatus, maxRiskDensity, topDrivers, and a timeline keyed by zone ID.
- The default view should be a 24-hour timeline split into 12 two-hour buckets.
- Risk density is calculated from real signals: failed/held transactions, impossible geo travel, missing geo compliance, fraud checks, AML alerts, provider anomalies, sensitive admin activity, gateway/provider activity, and ledger governance activity.
- Status thresholds are HEALTHY 0-34, WATCH 35-59, DEGRADED 60-74, and CRITICAL_OVERLOAD 75-100.
- Keep this separate from transaction geo heatmaps: transaction geo shows user/location risk; Compliance Node Zones show infrastructure and control-plane pressure.

Live Google Maps risk operations:
- Use GET /v1/admin/risk/live-geo only for restricted live risk maps and investigation screens.
- Query filters: minutes, countryCode, currency, status, minRiskScore, precision, limit.
- precision values: region, city, approximate.
- The endpoint returns recent transaction markers with rounded latitude/longitude only when consented metadata exists.
- Every call is audited as RISK_LIVE_GEO_VIEWED.
- The frontend must not store marker coordinates in localStorage/sessionStorage.
- Normal dashboard heatmaps should use geo-heatmap; live-geo should be an explicit restricted workflow.

Monitoring and operations:
Protected monitor endpoints include:
- GET /api/admin/monitor/operational-health
- GET /api/admin/monitor/operational-metrics
- GET /api/admin/monitor/operational-metrics/prometheus
- POST /api/admin/monitor/operational-metrics/snapshot
- GET /api/admin/monitor/ledger-health
- GET /api/admin/monitor/wallet-forensics/:walletId

These are not ordinary browser endpoints unless protected through a backend-for-frontend proxy.

Health endpoints:
- GET /health
- GET /ready
- GET /health/deep
- GET /api/broker/health where enabled

Operational states to surface:
- API online/offline/degraded
- provider readiness
- no active providers
- missing FX rates
- missing FX conversion fee config
- routing rule coverage gaps
- callback/webhook misconfiguration
- Redis connectivity instability
- database/RPC readiness
- settlement backlog
- webhook replay/retry status
- audit integrity compromised
- ledger discrepancy
- account frozen/blocked
- wallet locked
- insufficient balance
- stale quote
- provider timeout
- provider unavailable

User and account admin:
The admin console should support workflows for:
- staff/admin login
- managed identity creation where allowed
- user search
- KYC review
- account status update with reason
- service access requests for merchants/agents
- device trust and device review
- staff permissions preview
- staff password reset where permitted
- staff activity review

Wealth and shared finance operations:
The backend supports wealth-related models and should be visible operationally:
- goals
- bill reserves
- shared pots
- shared budgets
- allocation rules
- budget approvals
- shared budget spend
- shared pot contribution/withdrawal

The admin console should help investigate errors around these flows, especially:
- missing source wallet
- locked source wallet
- target/source same wallet
- insufficient balance
- inactive wallet
- account status restrictions
- missing fee/routing/provider config

Messaging and support operations:
ORBI includes staff/system messaging and template support. The console should support:
- template catalog browsing
- template preview
- approved send flows
- support ticket review
- user-specific messaging where allowed
- clear audit trail for every staff message

Frontend implementation expectations:
Use TypeScript and strong API typing. Zod may be used in frontend to mirror request contracts, validate local forms, and protect generated JSON before sending it to backend.

Suggested technical stack if starting new:
- React + Vite
- TypeScript
- TanStack Query or equivalent API state layer
- Zod for frontend validation
- A JSON editor for advanced payload review
- A clean API client abstraction

Do not treat the following as final UI instructions. Use them as product capability areas that the frontend architecture must cover:
- command/overview area
- users/accounts area
- transactions/money movement area
- providers/routing area
- fees/FX area
- risk/compliance/audit area
- support/messaging area
- configuration bootstrap studio
- IT/Ops visibility area

Frontend must propose:
1. Information architecture.
2. Route/page structure.
3. API client architecture.
4. Auth/session handling strategy.
5. Role/permission UI strategy.
6. State management strategy.
7. Data fetching and caching strategy.
8. Error handling strategy.
9. Safe mutation/confirmation strategy.
10. Secret handling strategy.
11. Auditability strategy.
12. How to represent transaction lifecycle and provider readiness.
13. How to separate normal admin operations from IT/Ops infrastructure visibility.

Safety rules:
- Backend is source of truth.
- Never bypass backend validation.
- Never calculate final financial truth only in frontend.
- Never expose monitor keys or provider secrets in browser state.
- Never retry commit mutations without explicit operator confirmation.
- Every dangerous action must show actor, target, timestamp, and consequence.
- Every configuration commit must have preview, diff/plan, confirmation, and readable result.
- Every backend error should become an operator-readable message without hiding the original code.

Deliverable expected from Gemini:
Produce a complete frontend architecture proposal and initial implementation plan for the ORBI Financial OS Platform Admin Console. The proposal should be based on the backend operations above, not on generic dashboard assumptions. Include page/module architecture, API client contracts, data models, mutation flows, permission gating, and implementation steps. Only after the architecture is clear, propose the visual layout and component system.
```
