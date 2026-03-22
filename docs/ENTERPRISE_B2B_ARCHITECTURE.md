# ORBI Enterprise B2B & Corporate Treasury Architecture
**Classification**: INSTITUTIONAL / ENTERPRISE CORE  
**Version**: 2.0.0 (Enterprise Hardened)  
**Last Updated**: 2026-03-14

---

## 1. Executive Summary
The ORBI platform has been upgraded from a primarily B2C (Business-to-Consumer) architecture to a full **Global Enterprise B2B (Business-to-Business)** system. This upgrade introduces strict Multi-Tenancy, Corporate Treasury Goals, Departmental Cost Centers (Budgets), and Hard Budget Enforcement.

This document details the data structures, connections, and operational flows for the Enterprise features.

---

## 2. Multi-Tenancy Model (Organizations)

To support B2B clients, the system now groups users under **Organizations** (Tenants). 

### 2.1 The `organizations` Table
This is the root entity for any corporate client.
*   **`id`**: UUID (Primary Key)
*   **`name`**: Legal name of the enterprise.
*   **`registration_number` / `tax_id`**: Corporate compliance identifiers.
*   **`base_currency`**: The primary accounting currency for the organization (e.g., 'USD', 'TZS').
*   **`status`**: 'ACTIVE', 'SUSPENDED', etc.

### 2.2 User-Organization Linkage
The `users` table has been upgraded with two critical fields:
*   **`organization_id`**: Foreign key linking the employee/user to their corporate tenant.
*   **`org_role`**: Defines the user's permissions within the organization.
    *   `ADMIN`: Full control over the organization's settings and users.
    *   `FINANCE`: Can manage Corporate Goals, Budgets, and view all departmental spending.
    *   `EMPLOYEE`: Can only view budgets assigned to them and spend within their limits.

### 2.3 Row Level Security (RLS) Isolation
Cross-tenant data leakage is cryptographically prevented at the database level using PostgreSQL RLS.
*   **Policy**: `Users view own organization` ensures a user can only query the `organizations` table for their own `organization_id`.
*   **Policy**: `Users view corporate budgets/goals` ensures employees can only see corporate financial data belonging to their specific tenant.

---

## 3. Corporate Treasury (Enterprise Goals)

Previously, `goals` were personal savings pots. They have been upgraded to support **Corporate Treasury Management**.

### 3.1 Corporate Goal Attributes
*   **`is_corporate`**: Boolean flag. If `TRUE`, this goal belongs to the organization, not an individual.
*   **`organization_id`**: Links the treasury reserve to the company.
*   **`currency`**: Allows enterprises to hold reserves in multiple currencies (e.g., a USD CapEx fund, a TZS Payroll fund).

### 3.2 Operational Flow: Auto-Sweeping & Reserves
1.  **Revenue Collection**: Corporate revenue flows into the organization's primary `OPERATING` vault.
2.  **Auto-Sweeping**: If `auto_allocation_enabled` is TRUE on a Corporate Goal, the end-of-day reconciliation engine sweeps excess liquidity from the operating vault into the specific Treasury Goal (e.g., sweeping 15% of daily revenue into a "Q3 Tax Reserve").
3.  **Multi-Sig Treasury**: Large withdrawals from enterprise vaults require multiple approvals (e.g., CFO + CEO) before the ledger releases the funds. The `treasury_approvals` table tracks the approval state.
4.  **Maker-Checker Withdrawals**: Moving funds *out* of a Corporate Goal requires multi-signature approval via the `approval_requests` table (e.g., an `EMPLOYEE` requests funds, a `FINANCE` admin approves).

---

## 4. Departmental Cost Centers (Enterprise Budgets)

The `categories` table has been fundamentally transformed into an **Enterprise Budgeting Engine**.

### 4.1 Budget Attributes
*   **`is_corporate`**: Marks the category as a departmental budget (e.g., "Q2 Marketing Spend").
*   **`organization_id`**: Links the budget to the tenant.
*   **`period`**: Defines the budget reset cycle (`MONTHLY`, `QUARTERLY`, `ANNUAL`).
*   **`hard_limit`**: Boolean. This is the most critical enterprise feature.
    *   `FALSE` (Soft Limit): If spending exceeds the budget, the transaction succeeds, but an alert is generated.
    *   `TRUE` (Hard Limit): If spending exceeds the budget, the database/API physically **BLOCKS** the transaction with an `INSUFFICIENT_BUDGET` error.

### 4.2 Budget Enforcement Engine & Alerts
When a transaction is processed via `post_transaction_v2`, the engine evaluates the associated `category_id`.

1.  **Aggregation**: The engine sums all transactions for the user/organization within the current `period`.
2.  **Threshold Checks**:
    *   If Spend > 80% of Budget: A `WARNING_80_PERCENT` alert is inserted into the `budget_alerts` table.
    *   If Spend > 100% of Budget (Soft Limit): An `EXCEEDED` alert is inserted.
    *   If Spend > 100% of Budget (Hard Limit): The transaction is rolled back.
3.  **Alert Routing**: The `budget_alerts` table triggers real-time WebSocket notifications to the `FINANCE` admins of that organization.

---

## 5. API Integration Guide for B2B

When building the frontend (Web/Mobile) for Enterprise clients, follow these patterns:
 
+### Organization Management
+```javascript
+// Fetch organizations for the user
+const { data } = await api.get('/v1/enterprise/organizations');
+
+// Create a new organization
+const response = await api.post('/v1/enterprise/organizations', {
+    name: "Acme Corp",
+    registration_number: "REG-123",
+    tax_id: "TAX-456",
+    country: "Tanzania"
+});
+```
+
### Fetching Corporate Budgets
```javascript
// Fetch all budgets for the user's organization
const { data, error } = await supabase
  .from('categories')
  .select('*')
  .eq('is_corporate', true);
// RLS automatically filters this to the user's organization_id
```

### Handling Hard Limit Rejections
When submitting a transaction, be prepared to handle budget rejections:
```javascript
const response = await api.post('/transactions', payload);
if (response.error && response.code === 'BUDGET_HARD_LIMIT_EXCEEDED') {
    // Show UI: "This transaction exceeds your departmental budget for this quarter. Please request a budget increase from Finance."
}
```

### Treasury Operations
```javascript
// Request a treasury withdrawal
const request = await api.post('/v1/enterprise/treasury/withdraw/request', {
    goalId: "uuid-of-treasury-goal",
    amount: 1000000,
    destinationWalletId: "uuid-of-operating-wallet",
    reason: "Payroll Q1"
});

// Approve a pending withdrawal (Admin/Finance only)
const approval = await api.post('/v1/enterprise/treasury/withdraw/approve', {
    txId: "uuid-of-withdrawal-request"
});

// Configure Auto-Sweep
await api.post('/v1/enterprise/treasury/autosweep', {
    goalId: "uuid-of-treasury-goal",
    enabled: true,
    threshold: 5000000
});
```

### Provisioning a New Organization
When onboarding a new B2B client:
1. Insert into `organizations` (Name, Tax ID, Base Currency).
2. Insert the first user into `users` with `organization_id` = new_org_id and `org_role` = 'ADMIN'.
3. The ADMIN can then invite other users using their Orbi email address (`POST /v1/enterprise/users/invite`). The invited user will instantly receive a real-time push notification and inherit the `organization_id` with an `EMPLOYEE` or `FINANCE` role. Alternatively, use `POST /v1/enterprise/users/link` to link an existing user.

---

## 6. Real-Time Enterprise Notifications (WebSockets)

The Enterprise module is fully integrated with the Orbi `MessagingService` and `SocketRegistry` to provide real-time push notifications over the `/nexus-stream` WebSocket connection.

### 6.1 Treasury Request Notifications
*   **Trigger:** An `EMPLOYEE` requests funds from a Corporate Treasury Goal.
*   **Recipients:** All `ADMIN` and `FINANCE` users in the organization.
*   **Payload:** "Pending Treasury Withdrawal: A new treasury withdrawal request for $X requires your approval."

### 6.2 Treasury Approval Notifications
*   **Trigger:** An `ADMIN` or `FINANCE` user fully approves a pending withdrawal.
*   **Recipients:** The `EMPLOYEE` (Maker) who requested the funds.
*   **Payload:** "Treasury Withdrawal Approved: Your treasury withdrawal request for $X has been fully approved and the funds have been transferred to your operating wallet."

### 6.3 Budget Alert Notifications
*   **Trigger:** A transaction crosses an 80% or 100% budget threshold.
*   **Recipients:** All `ADMIN` and `FINANCE` users in the organization.
*   **Payload:** Varies based on the alert type (e.g., "Budget Exceeded (Blocked): A transaction of $X for [Category] was blocked because it exceeded the hard limit.").

---
**ORBI Financial Technologies Ltd.**  
*Enterprise Architecture Division*
