# Orbi Sovereign: Enterprise B2B Frontend Integration Guide
**Version**: 30.0 (Titanium)  
**Last Updated**: 2026-03-14

This document outlines the frontend integration strategy, API hooks, and UI component architecture for the newly introduced **Enterprise B2B, Corporate Treasury, and Budget Enforcement** features.

---

## 1. Overview

The Enterprise module transforms Orbi from a consumer wallet into a corporate financial operating system. Frontend developers must build interfaces that support:
1. **Multi-Tenant Organizations**: Users can belong to an organization with specific roles (`ADMIN`, `FINANCE`, `EMPLOYEE`).
2. **Corporate Treasury**: Automated liquidity sweeping from operating vaults to treasury goals.
3. **Maker-Checker Workflows**: Dual-approval requirements for treasury withdrawals.
4. **Hard Budgets**: Real-time alerts and transaction blocking based on corporate category limits.

---

## 2. API Integration (React Hooks)

We recommend wrapping the new REST endpoints in custom React hooks (e.g., using `SWR` or `React Query`) to handle loading states, caching, and error handling.

### 2.1. Organization Management (Autonomous Onboarding)

Orbi supports **Multi-Tenant Autonomy**. Organizations can self-serve their onboarding and team management without Orbi Staff intervention.

**`useCreateOrganization`**
Creates a new corporate tenant.
*Security Note:* The backend automatically assigns the user who calls this endpoint as the `ADMIN` of the newly created organization.

```typescript
export const useCreateOrganization = () => {
  const [loading, setLoading] = useState(false);
  
  const createOrg = async (payload: { name: string; registration_number: string; tax_id: string; country: string }) => {
    setLoading(true);
    try {
      const res = await fetch('/v1/enterprise/organizations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify(payload)
      });
      return await res.json();
    } finally {
      setLoading(false);
    }
  };
  return { createOrg, loading };
};
```

**`useLinkUser` (Autonomous Team Management)**
Assigns a user to an organization with a specific role (`ADMIN`, `FINANCE`, `EMPLOYEE`).
*Security Note:* The backend enforces that only a user with the `ADMIN` role for the specific organization can successfully call this endpoint. This allows Org Admins to autonomously invite Makers and Checkers.

```typescript
// POST /v1/enterprise/users/link
// Body: { userId: string, organizationId: string, role: string }
```

**`useInviteUserByEmail` (Seamless Team Invitations)**
Allows an `ADMIN` to invite a user to their organization using only the user's Orbi email address.
*Security Note:* The backend enforces that only an `ADMIN` of the specific organization can call this endpoint. The invited user will instantly receive a real-time push notification and an email.

```typescript
export const useInviteUserByEmail = () => {
  const [loading, setLoading] = useState(false);
  
  const inviteUser = async (email: string, organizationId: string, role: string) => {
    setLoading(true);
    try {
      const res = await fetch('/v1/enterprise/users/invite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ email, organizationId, role })
      });
      return await res.json();
    } finally {
      setLoading(false);
    }
  };
  return { inviteUser, loading };
};
```

### 2.2. Corporate Treasury (Maker-Checker)

**`useRequestWithdrawal`**
Initiates a withdrawal from a treasury goal to an operating vault. This creates a transaction in `held_for_review` status.
*Notification:* All `ADMIN` and `FINANCE` users in the organization instantly receive a real-time push notification requesting their approval.
```typescript
// POST /v1/enterprise/treasury/withdraw/request
// Body: { goalId: string, amount: number, destinationWalletId: string, reason: string }
```

**`useApproveWithdrawal`**
Allows an `ADMIN` or `FINANCE` user to approve a pending withdrawal. *Note: The API enforces that a user cannot approve their own request.*
*Notification:* Once fully approved, the Maker (the employee who requested the funds) instantly receives a real-time push notification that the funds have been transferred.
```typescript
// POST /v1/enterprise/treasury/withdraw/approve
// Body: { txId: string }
```

### 2.3. Budget Enforcement & Alerts

**Real-Time Push Notifications**
The Orbi backend automatically dispatches real-time push notifications over the WebSocket (`/nexus-stream`) to all `FINANCE` and `ADMIN` users when budget thresholds are crossed:
*   **80% Warning:** Spending has reached 80% of the budget target.
*   **100% Exceeded (Warning):** A transaction exceeded a soft budget limit.
*   **100% Exceeded (Blocked):** A transaction was blocked because it exceeded a hard budget limit.

**`useBudgetAlerts`**
Fetches real-time budget alerts for the organization.
```typescript
export const useBudgetAlerts = (orgId: string) => {
  const { data, error, mutate } = useSWR(`/v1/enterprise/budgets/alerts?orgId=${orgId}`, fetcher, {
    refreshInterval: 10000 // Poll every 10s for real-time alerts
  });
  
  return {
    alerts: data?.data || [],
    isLoading: !error && !data,
    isError: error,
    refresh: mutate
  };
};
```

---

## 3. UI Component Architecture

The Enterprise UI should feel **Professional, Precise, and Information-Dense** (referencing the *Technical Dashboard / Data Grid* design recipe).

### 3.1. The Budget Alerts Feed
A critical component for Finance teams to monitor spending limits.

**Design Pattern:**
*   Use a visible grid structure.
*   Color-code alerts: `EXCEEDED_BLOCKED` (Red/Destructive), `EXCEEDED_WARNING` (Orange/Warning), `WARNING_80_PERCENT` (Yellow/Caution).

**Component Skeleton:**
```tsx
import React from 'react';
import { AlertTriangle, ShieldAlert, Info } from 'lucide-react';

export const BudgetAlertsFeed = ({ alerts }) => {
  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-200 bg-gray-50">
        <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">Active Budget Alerts</h3>
      </div>
      <div className="divide-y divide-gray-100">
        {alerts.map(alert => (
          <div key={alert.id} className="p-4 hover:bg-gray-50 transition-colors flex items-start gap-4">
            {alert.alert_type === 'EXCEEDED_BLOCKED' && <ShieldAlert className="w-5 h-5 text-red-500 mt-0.5" />}
            {alert.alert_type === 'EXCEEDED_WARNING' && <AlertTriangle className="w-5 h-5 text-orange-500 mt-0.5" />}
            {alert.alert_type === 'WARNING_80_PERCENT' && <Info className="w-5 h-5 text-yellow-500 mt-0.5" />}
            
            <div className="flex-1">
              <p className="text-sm font-medium text-gray-900">
                {alert.categories?.name} Budget {alert.alert_type.replace(/_/g, ' ')}
              </p>
              <p className="text-xs text-gray-500 mt-1">
                Attempted: {alert.amount} {alert.categories?.currency} by {alert.users?.full_name}
              </p>
            </div>
            <span className="text-xs font-mono text-gray-400">
              {new Date(alert.created_at).toLocaleTimeString()}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};
```

### 3.2. Maker-Checker Approval Queue
A data grid displaying pending treasury withdrawals.

**Rules:**
1. Only show to `ADMIN` and `FINANCE` roles.
2. Disable the "Approve" button if `alert.user_id === currentUser.id` (prevent self-approval).
3. Show progress (e.g., "1/2 Approvals").

**Component Skeleton:**
```tsx
export const ApprovalQueue = ({ pendingTransactions, currentUser }) => {
  return (
    <table className="w-full text-left border-collapse">
      <thead>
        <tr className="border-b border-gray-200">
          <th className="p-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Request</th>
          <th className="p-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Amount</th>
          <th className="p-3 text-xs font-semibold text-gray-500 uppercase tracking-wider">Status</th>
          <th className="p-3 text-xs font-semibold text-gray-500 uppercase tracking-wider text-right">Action</th>
        </tr>
      </thead>
      <tbody className="divide-y divide-gray-100">
        {pendingTransactions.map(tx => {
          const isSelf = tx.user_id === currentUser.id;
          const hasApproved = tx.metadata.approved_by.includes(currentUser.id);
          
          return (
            <tr key={tx.id} className="hover:bg-gray-50">
              <td className="p-3 text-sm text-gray-900">{tx.metadata.reason}</td>
              <td className="p-3 text-sm font-mono">{tx.amount} USD</td>
              <td className="p-3 text-sm">
                <span className="px-2 py-1 bg-blue-50 text-blue-700 rounded-full text-xs">
                  {tx.metadata.approvals_received} / {tx.metadata.approvals_required} Approvals
                </span>
              </td>
              <td className="p-3 text-right">
                <button 
                  disabled={isSelf || hasApproved}
                  className="px-4 py-1.5 bg-black text-white text-xs font-medium rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
                  onClick={() => handleApprove(tx.id)}
                >
                  {hasApproved ? 'Approved' : 'Approve'}
                </button>
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
};
```

### 3.3. Treasury Auto-Sweep Configuration
A settings panel for configuring the `sweep_threshold` on corporate goals.

**UI Flow:**
1. User selects a Corporate Goal.
2. User toggles "Enable Auto-Sweep".
3. User inputs the "Operating Vault Threshold" (e.g., $50,000).
4. Frontend updates the goal's `metadata: { auto_sweep: true, sweep_threshold: 50000 }`.

---

## 4. State Management & Data Flow

### 4.1. Role-Based Access Control (RBAC)
The frontend must securely handle routing and component visibility based on the user's `org_role`.

*   **`ADMIN`**: Full access to Organization Settings, Treasury Configuration, and Approvals.
*   **`FINANCE`**: Access to Budget Alerts, Approvals, and Ledger Forensics. Cannot change Organization settings.
*   **`EMPLOYEE`**: Can view their own corporate cards/budgets. Cannot view Treasury or Organization settings.

**Implementation Tip:**
Create a `<RoleGuard allowedRoles={['ADMIN', 'FINANCE']}>` wrapper component to encapsulate sensitive UI elements.

### 4.2. Handling "BUDGET_EXCEEDED" Errors
When an employee attempts a transaction that violates a hard budget, the backend will return a `400 Bad Request` with the error `BUDGET_EXCEEDED: Transaction blocked...`.

**Frontend Requirement:**
Catch this specific error string in your transaction submission hook and display a prominent, non-dismissible modal explaining that the corporate limit has been reached, rather than a generic "Transaction Failed" toast.

---

## 5. Summary Checklist for Frontend Developers

- [ ] Implement `useCreateOrganization` and `useLinkUser` hooks.
- [ ] Build the **Organization Settings** view (Admin only).
- [ ] Build the **Treasury Dashboard** showing Operating Vault balance vs. Treasury Goals.
- [ ] Implement the **Maker-Checker Approval Queue** with self-approval prevention.
- [ ] Build the **Budget Alerts Feed** with real-time polling or WebSocket integration.
- [ ] Implement `<RoleGuard>` components to protect enterprise routes.
- [ ] Add specific error handling for `BUDGET_EXCEEDED` transaction failures.
