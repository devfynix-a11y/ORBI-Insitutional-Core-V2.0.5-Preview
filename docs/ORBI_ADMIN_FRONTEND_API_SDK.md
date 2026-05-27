# ORBI Admin Frontend API SDK

This document describes the frontend SDK contract for building the ORBI Financial OS Platform Admin Console. The copyable SDK implementation is in:

`docs/orbi-admin-sdk.ts`

Use it as the API layer for React/Vite, Next.js, or a backend-for-frontend service.

## Base URLs

Primary ORBI Core:

```env
VITE_ORBI_API_BASE_URL=https://api.orbifinancial.com
```

Google fallback ORBI Core:

```env
VITE_ORBI_FALLBACK_API_BASE_URL=https://go-api.orbifinancial.com
```

Gateway backend:

```env
VITE_ORBI_GATEWAY_BASE_URL=https://gateway.orbifinancial.com
```

App identity:

```env
VITE_ORBI_APP_ID=ORBI_NODE_PORTAL_V2026
VITE_ORBI_APP_ORIGIN=ORBI-NODE-PORTAL-V2026
VITE_ORBI_ENABLE_SAFE_READ_FALLBACK=true
```

## Required Headers

Every authenticated normal admin request should include:

```http
Authorization: Bearer <admin-session-token>
x-orbi-app-id: ORBI_NODE_PORTAL_V2026
x-orbi-app-origin: ORBI-NODE-PORTAL-V2026
x-orbi-trace: <uuid>
x-orbi-device-id: <device-id-if-available>
x-orbi-user-role: <role-if-session-role-is-known>
Content-Type: application/json
```

Settlement and commit endpoints that require durable mutation protection should also include:

```http
Idempotency-Key: <stable-uuid-for-this-submit>
```

Monitor endpoints require a monitor key:

```http
x-orbi-monitor-key: <ORBI_MONITOR_API_KEY>
```

Do not expose the monitor key in a public browser build. Put monitor calls behind a backend-for-frontend proxy unless the admin UI is fully internal.

## SDK Initialization

```ts
import { OrbiAdminSdk } from './orbi-admin-sdk';

export const orbi = new OrbiAdminSdk({
  apiBaseUrl: import.meta.env.VITE_ORBI_API_BASE_URL,
  fallbackApiBaseUrl: import.meta.env.VITE_ORBI_FALLBACK_API_BASE_URL,
  gatewayBaseUrl: import.meta.env.VITE_ORBI_GATEWAY_BASE_URL,
  appId: import.meta.env.VITE_ORBI_APP_ID,
  appOrigin: import.meta.env.VITE_ORBI_APP_ORIGIN,
  enableSafeReadFallback: import.meta.env.VITE_ORBI_ENABLE_SAFE_READ_FALLBACK === 'true',
  getToken: () => sessionStore.getAccessToken(),
  getDeviceId: () => deviceStore.getDeviceId(),
  getRole: () => sessionStore.getRole(),
});
```

## Connection Diagnosis

The SDK includes a public health diagnosis helper that does not send auth or custom ORBI headers, avoiding unnecessary browser preflight for public health checks:

```ts
const result = await orbi.health.diagnose();
console.log(result.primary);
console.log(result.fallback);
console.log(result.gateway);
```

Expected live endpoints:

```txt
https://api.orbifinancial.com/health
https://go-api.orbifinancial.com/health
https://gateway.orbifinancial.com/health
```

If `health.diagnose()` works in Node but fails in the browser, the likely issue is CORS or frontend origin configuration, not the SDK request path. Add the admin frontend origin to `ORBI_ALLOWED_ORIGINS` on the backend and restart the backend container.

If authenticated admin calls fail with `ROLE_HEADER_REQUIRED`, make sure:

```ts
getRole: () => sessionStore.getRole()
```

returns the exact backend session role, for example `ADMIN`, `SUPER_ADMIN`, `IT`, `AUDIT`, or `CUSTOMER_CARE`.

If authenticated admin calls fail with `NODE_ORIGIN_MISMATCH`, the logged-in staff session was not issued for an institutional/admin app origin. Use the ORBI admin/portal login flow, not a consumer mobile session.

## Safe Mutation Rules

Use these rules in the admin UI:

- Preview before commit for provider, fee, FX, routing, transaction, bill, merchant, agent, and shared-budget flows where preview exists.
- Never silently retry a commit or settlement mutation.
- Use `Idempotency-Key` for every settlement-style POST.
- Keep quote IDs, preview fingerprints, and server transaction context unchanged between preview and confirmation.
- If the user edits any amount, wallet, target, provider, category, currency, or reference, discard the old preview and request a new one.
- Show backend error codes directly, with human-readable explanations.
- Never calculate final balances, final fees, settlement outcome, provider readiness, or ledger truth in frontend only.

## Functional SDK Groups

### Health

```ts
orbi.health.primary()
orbi.health.ready()
orbi.health.deep()
orbi.health.gateway()
```

### Auth and Session

```ts
orbi.auth.login(body)
orbi.auth.session()
orbi.auth.refresh(body)
orbi.auth.logout()
orbi.auth.bootstrapState()
orbi.auth.bootstrapAdmin(body)
orbi.auth.otpInitiate(body)
orbi.auth.verifySensitiveAction(body)
orbi.auth.passkeyRegisterStart(body)
orbi.auth.passkeyRegisterFinish(body)
orbi.auth.passkeyLoginStart(body)
orbi.auth.passkeyLoginFinish(body)
orbi.auth.pinEnroll(body)
orbi.auth.pinUpdate(body)
orbi.auth.pinLogin(body)
```

### Admin Transactions

```ts
orbi.admin.transactions.list(query)
orbi.admin.transactions.summary(query)
orbi.admin.transactions.ledger(transactionId)
orbi.admin.transactions.lock(transactionId, { reason })
orbi.admin.transactions.audit(transactionId, { passed, notes })
orbi.admin.transactions.approve(transactionId, { reason })
orbi.admin.transactions.approveAudited({ reason })
orbi.admin.transactions.reverse(transactionId, { reason })
```

### Users, Staff, Permissions

```ts
orbi.admin.users.search(query)
orbi.admin.users.registerManaged(body)
orbi.admin.users.updateStatus(userId, { status, reason })
orbi.admin.users.updateProfile(userId, body)
orbi.admin.users.permissionsPreview({ role, status })

orbi.admin.staff.list()
orbi.admin.staff.create(body)
orbi.admin.staff.update(staffId, body)
orbi.admin.staff.resetPassword(staffId, { password })
orbi.admin.staff.activity(staffId)
```

### KYC, Documents, Devices

```ts
orbi.admin.kyc.requests(query)
orbi.admin.kyc.review({ requestId, decision, reason })

orbi.admin.documents.list(query)
orbi.admin.documents.verify(documentId, { status, rejection_reason })

orbi.admin.devices.list(query)
orbi.admin.devices.updateStatus(deviceId, { is_trusted, status })
```

### Audit, Risk, Activity

```ts
orbi.admin.audit.trail({
  limit,
  eventType,
  actorId,
  transactionId,
  action,
})

orbi.admin.audit.riskAlerts({
  days,
  status,
})
```

The backend now records platform control UI access through admin activity accounting middleware. Activity rows include actor, role, route, method, status, target, trace, device/app identity, IP, and user agent. Explicit sensitive action audits are also emitted for KYC, document review, device trust, staff messages, support tickets, service access, transaction review, reconciliation, and configuration changes.

### Support and Messaging

```ts
orbi.admin.support.tickets(query)
orbi.admin.support.createTicket(body)
orbi.admin.support.updateTicket(ticketId, body)
orbi.admin.support.staffMessages()
orbi.admin.support.sendStaffMessage(body)
orbi.admin.support.flagStaffMessage(messageId)

orbi.admin.messaging.templates(query)
orbi.admin.messaging.previewTemplate(body)
orbi.admin.messaging.previewAudience(body)
orbi.admin.messaging.sendTemplate(body)
orbi.admin.messaging.sendSystemSms(body)
```

### Admin Configuration Studio

```ts
orbi.admin.config.ledger()
orbi.admin.config.saveLedger(body)
orbi.admin.config.commissions()
orbi.admin.config.saveCommissions(body)
orbi.admin.config.fxRates()
orbi.admin.config.saveFxRates(rates)
orbi.admin.config.bootstrapPreview(payload)
orbi.admin.config.bootstrapCommit(payload)
```

Bootstrap preview and commit use:

```http
POST /api/admin/config/bootstrap
```

Payload:

```ts
{
  mode: 'preview' | 'commit',
  fx?: {
    rates?: Record<string, number>,
    fee?: Record<string, unknown>,
  },
  providers?: Array<Record<string, unknown>>,
}
```

The UI must always call `bootstrapPreview` before `bootstrapCommit`.

### Providers, Routing, Fees, Institutional Accounts

```ts
orbi.admin.providers.partners()
orbi.admin.providers.createPartner(body)
orbi.admin.providers.updatePartner(providerId, body)
orbi.admin.providers.deletePartner(providerId)

orbi.admin.providers.routingRules()
orbi.admin.providers.createRoutingRule(body)
orbi.admin.providers.updateRoutingRule(ruleId, body)
orbi.admin.providers.deleteRoutingRule(ruleId)

orbi.admin.providers.platformFees(query)
orbi.admin.providers.createPlatformFee(body)
orbi.admin.providers.updatePlatformFee(feeId, body)

orbi.admin.providers.institutionalAccounts(query)
orbi.admin.providers.createInstitutionalAccount(body)
orbi.admin.providers.updateInstitutionalAccount(accountId, body)
```

### Reconciliation and KMS

```ts
orbi.admin.reconciliation.run({ reason })
orbi.admin.reconciliation.reports(query)

orbi.admin.kms.health()
orbi.admin.kms.diagnose({ masterKey })
orbi.admin.kms.rewrap({ confirm: 'REWRAP_KEYS', newMasterKey })
```

KMS rewrap is a dangerous action and must require a special confirmation dialog.

### Monitor and Infrastructure Operations

```ts
orbi.monitor.operationalHealth()
orbi.monitor.operationalMetrics()
orbi.monitor.prometheusMetrics()
orbi.monitor.snapshotMetrics()
orbi.monitor.ledgerHealth()
orbi.monitor.walletForensics(walletId)
```

Use these from an internal admin BFF, not a public browser bundle, unless the monitor key is never exposed to ordinary users.

### Core Finance

```ts
orbi.finance.dashboard()
orbi.finance.userDashboard()
orbi.finance.wallets()
orbi.finance.createWallet(body)
orbi.finance.deleteWallet(walletId)
orbi.finance.lockWallet(walletId, body)
orbi.finance.unlockWallet(walletId, body)
orbi.finance.linkedWallets()
orbi.finance.sovereignWallets()
orbi.finance.previewTransaction(body)
orbi.finance.settleTransaction(body, idempotencyKey)
orbi.finance.transactions(query)
orbi.finance.receipt(transactionId)
orbi.finance.fxQuote({ from, to, amount })
```

### Merchant, Agent, Bills, Orbi Pay

```ts
orbi.commerce.merchantCategories()
orbi.commerce.merchants(query)
orbi.commerce.createMerchantAccount(body)
orbi.commerce.myMerchantAccount()
orbi.commerce.merchantAccount(id)
orbi.commerce.updateMerchantSettlement(id, body)
orbi.commerce.merchantTransactions(query)
orbi.commerce.merchantWallets()
orbi.commerce.registerMerchantCustomer(body)
orbi.commerce.merchantCustomers(query)
orbi.commerce.merchantPaymentPreview(body)
orbi.commerce.merchantPaymentSettle(body, idempotencyKey)
orbi.commerce.orbiPayPreview(body)
orbi.commerce.orbiPaySettle(body, idempotencyKey)
orbi.commerce.billProviders()
orbi.commerce.billPreview(body)
orbi.commerce.billSettle(body, idempotencyKey)

orbi.commerce.agentTransactions(query)
orbi.commerce.agentWallets()
orbi.commerce.agentLookup(query)
orbi.commerce.registerAgentCustomer(body)
orbi.commerce.agentCustomers(query)
orbi.commerce.agentCommissions(query)
orbi.commerce.agentCashDepositPreview(body)
orbi.commerce.agentCashDepositSettle(body, idempotencyKey)
orbi.commerce.agentCashWithdrawPreview(body)
orbi.commerce.agentCashWithdrawSettle(body, idempotencyKey)
```

### External Funds and Gateway

```ts
orbi.externalFunds.preview(body)
orbi.externalFunds.createDepositIntent(body, idempotencyKey)
orbi.externalFunds.settle(body, idempotencyKey)
orbi.externalFunds.movements(query)
orbi.externalFunds.movement(id)

orbi.gateway.providers()
orbi.gateway.initiatePayment(body)
orbi.gateway.settlePayment(orderId, body)
orbi.gateway.refundPayment(orderId, body)
orbi.gateway.orders(query)
orbi.gateway.order(orderId)
orbi.gateway.settlementStatus(settlementId)
orbi.gateway.confirmSettlement(settlementId, body)
orbi.gateway.disputeSettlement(settlementId, body)
orbi.gateway.settlements(query)
orbi.gateway.schedulerHealth()
```

### Wealth, Goals, Shared Pots, Shared Budgets

```ts
orbi.wealth.summary()
orbi.wealth.goals()
orbi.wealth.createGoal(body)
orbi.wealth.updateGoal(goalId, body)
orbi.wealth.deleteGoal(goalId)
orbi.wealth.allocateGoal(goalId, body)
orbi.wealth.withdrawGoal(goalId, body)

orbi.wealth.billReserves()
orbi.wealth.createBillReserve(body)
orbi.wealth.updateBillReserve(id, body)
orbi.wealth.deleteBillReserve(id)

orbi.wealth.sharedPots()
orbi.wealth.createSharedPot(body)
orbi.wealth.updateSharedPot(id, body)
orbi.wealth.sharedPotMembers(id)
orbi.wealth.sharedPotInvitations(id)
orbi.wealth.mySharedPotInvitations()
orbi.wealth.inviteSharedPot(id, body)
orbi.wealth.respondSharedPotInvitation(id, body)
orbi.wealth.contributeSharedPot(id, body)
orbi.wealth.withdrawSharedPot(id, body)

orbi.wealth.sharedBudgets()
orbi.wealth.createSharedBudget(body)
orbi.wealth.updateSharedBudget(id, body)
orbi.wealth.sharedBudgetMembers(id)
orbi.wealth.sharedBudgetTransactions(id)
orbi.wealth.sharedBudgetInvitations(id)
orbi.wealth.mySharedBudgetInvitations()
orbi.wealth.inviteSharedBudget(id, body)
orbi.wealth.respondSharedBudgetInvitation(id, body)
orbi.wealth.sharedBudgetApprovals(id)
orbi.wealth.respondSharedBudgetApproval(id, body)
orbi.wealth.sharedBudgetSpendPreview(id, body)
orbi.wealth.sharedBudgetSpendSettle(id, body, idempotencyKey)

orbi.wealth.allocationRules()
orbi.wealth.createAllocationRule(body)
orbi.wealth.updateAllocationRule(id, body)
```

## Frontend Architecture Recommendation

Use the SDK in a clean data layer:

```txt
src/lib/orbi-admin-sdk.ts
src/lib/orbi-client.ts
src/features/auth/api.ts
src/features/admin-transactions/api.ts
src/features/config-studio/api.ts
src/features/providers/api.ts
src/features/audit/api.ts
src/features/support/api.ts
src/features/monitor/api.ts
```

With TanStack Query:

```ts
const transactionsQuery = useQuery({
  queryKey: ['admin', 'transactions', filters],
  queryFn: () => orbi.admin.transactions.list(filters),
});
```

For dangerous actions:

```ts
const reverseMutation = useMutation({
  mutationFn: ({ id, reason }: { id: string; reason: string }) =>
    orbi.admin.transactions.reverse(id, { reason }),
});
```

Always wrap dangerous mutations with:

- operator confirmation
- typed reason
- target summary
- trace ID display
- backend response display
- activity/audit link after success

## Error Handling

The SDK throws `OrbiApiError` with:

```ts
{
  status: number;
  code?: string;
  message: string;
  payload?: unknown;
}
```

The admin UI should map common backend codes:

- `ACCESS_DENIED`: role or permission missing
- `AUTH_REQUIRED`: session expired or missing
- `DB_OFFLINE`: backend persistence unavailable
- `MISSING_FEE_CONFIG`: configure fee model before transaction
- `FX_RATES_UNAVAILABLE`: configure active FX rates
- `FX_CONVERSION_FEE_UNAVAILABLE`: configure active FX conversion fee
- `PROVIDER_UNAVAILABLE`: selected provider cannot process now
- `ROUTING_RULE_MISSING`: provider route coverage missing
- `LOCKED_WALLET`: wallet is locked or unavailable
- `INSUFFICIENT_FUNDS`: ledger-backed balance is not enough
- `SOURCE_TARGET_WALLET_MATCH`: source and target wallet are same
- `STALE_QUOTE`: quote must be refreshed
- `CONFIRMATION_REQUIRED`: explicit confirmation value missing

## Activity Accounting

The backend now records admin/platform control UI access. Every route mounted under admin surfaces emits activity with:

- actor
- role
- registry type
- route and method
- status and success
- resource and target ID
- trace/correlation IDs
- app ID and app origin
- device ID
- IP and user agent
- redacted query/params
- request body keys only

Explicit domain events are also emitted for sensitive workflows. The frontend should display these through:

```ts
orbi.admin.audit.trail(query)
orbi.admin.staff.activity(staffId)
orbi.admin.audit.riskAlerts(query)
```
