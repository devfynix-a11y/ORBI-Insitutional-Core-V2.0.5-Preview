# Orbi Sovereign: Organization Dashboard & Treasury UI Guide

This document expands on the Enterprise B2B integration by detailing the specific UI components, data fetching strategies, and layouts required for the **Organization Dashboard** and **Treasury Management** views.

---

## 1. Organization Dashboard Overview

The Organization Dashboard is the central hub for `ADMIN` and `FINANCE` users. It provides a high-level view of corporate liquidity, active treasury goals, and team members. 

*Note: Because Orbi supports **Multi-Tenant Autonomy**, `ADMIN` users can autonomously invite new members and assign roles directly from this dashboard without contacting Orbi Support.*

### 1.1. Data Fetching Hook

**`useOrganizationDetails`**
Fetches the organization profile, member list, and active corporate goals.

```typescript
import useSWR from 'swr';

export const useOrganizationDetails = (orgId: string) => {
  const { data, error, mutate } = useSWR(`/v1/enterprise/organizations/${orgId}`, fetcher);
  
  return {
    organization: data?.data,
    members: data?.data?.members || [],
    goals: data?.data?.goals || [],
    isLoading: !error && !data,
    isError: error,
    refresh: mutate
  };
};
```

### 1.2. Dashboard Layout Structure

**Design Pattern:** Split Layout / Bento Grid
*   **Top Row:** Key Metrics (Total Liquidity, Active Goals, Pending Approvals).
*   **Left Column (60%):** Treasury Goals & Auto-Sweep Status.
*   **Right Column (40%):** Recent Budget Alerts & Team Members.

```tsx
import React from 'react';

export const OrganizationDashboard = ({ orgId }) => {
  const { organization, members, goals, isLoading } = useOrganizationDetails(orgId);

  if (isLoading) return <div className="animate-pulse">Loading...</div>;

  return (
    <div className="max-w-7xl mx-auto p-6 space-y-6">
      <header className="flex justify-between items-end border-b border-gray-200 pb-4">
        <div>
          <h1 className="text-3xl font-semibold text-gray-900 tracking-tight">{organization.name}</h1>
          <p className="text-sm text-gray-500 mt-1">Corporate Treasury & Operations</p>
        </div>
        {/* Action Buttons */}
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Main Content Area */}
        <div className="md:col-span-2 space-y-6">
          <TreasuryGoalsList goals={goals} />
          <MakerCheckerQueue orgId={orgId} />
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          <BudgetAlertsFeed orgId={orgId} />
          <TeamMembersList members={members} />
        </div>
      </div>
    </div>
  );
};
```

---

## 2. Maker-Checker Approval Queue

The Maker-Checker queue displays transactions that are `held_for_review`.

### 2.1. Data Fetching Hook

**`usePendingApprovals`**
```typescript
export const usePendingApprovals = (orgId: string) => {
  const { data, error, mutate } = useSWR(`/v1/enterprise/treasury/approvals?orgId=${orgId}`, fetcher);
  
  return {
    pendingTxs: data?.data || [],
    isLoading: !error && !data,
    refresh: mutate
  };
};
```

### 2.2. Component Implementation

*Refer to `frontend-enterprise-guide.md` for the base table skeleton.*

**Key Interaction:**
When an admin clicks "Approve", call the `POST /v1/enterprise/treasury/withdraw/approve` endpoint. If successful, call `refresh()` on both the `usePendingApprovals` and `useOrganizationDetails` hooks to update the UI.

---

## 3. Auto-Sweep Configuration Modal

This component allows admins to configure the automated liquidity sweep from operating vaults to specific treasury goals.

### 3.1. API Hook

**`useConfigureAutoSweep`**
```typescript
export const useConfigureAutoSweep = () => {
  const [isUpdating, setIsUpdating] = useState(false);

  const configureSweep = async (goalId: string, enabled: boolean, threshold: number) => {
    setIsUpdating(true);
    try {
      const res = await fetch('/v1/enterprise/treasury/autosweep', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ goalId, enabled, threshold })
      });
      return await res.json();
    } finally {
      setIsUpdating(false);
    }
  };

  return { configureSweep, isUpdating };
};
```

### 3.2. UI Component

**Design Pattern:** Clean Utility / Minimal Form

```tsx
import React, { useState } from 'react';

export const AutoSweepConfigModal = ({ goal, onClose, onConfigured }) => {
  const { configureSweep, isUpdating } = useConfigureAutoSweep();
  const [enabled, setEnabled] = useState(goal.metadata?.auto_sweep || false);
  const [threshold, setThreshold] = useState(goal.metadata?.sweep_threshold || 0);

  const handleSave = async () => {
    const res = await configureSweep(goal.id, enabled, Number(threshold));
    if (res.success) {
      onConfigured();
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">Configure Auto-Sweep</h2>
        <p className="text-sm text-gray-500 mb-6">
          Automatically transfer excess operating liquidity into <strong>{goal.name}</strong>.
        </p>

        <div className="space-y-4">
          <label className="flex items-center space-x-3">
            <input 
              type="checkbox" 
              checked={enabled} 
              onChange={(e) => setEnabled(e.target.checked)}
              className="w-5 h-5 text-black border-gray-300 rounded focus:ring-black"
            />
            <span className="text-sm font-medium text-gray-900">Enable Auto-Sweep</span>
          </label>

          {enabled && (
            <div>
              <label className="block text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">
                Operating Vault Threshold ({goal.currency})
              </label>
              <input 
                type="number" 
                value={threshold}
                onChange={(e) => setThreshold(e.target.value)}
                className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-black focus:border-transparent"
                placeholder="e.g. 50000"
              />
              <p className="text-xs text-gray-400 mt-2">
                Balances above this amount will be automatically swept into this goal daily.
              </p>
            </div>
          )}
        </div>

        <div className="mt-8 flex justify-end space-x-3">
          <button onClick={onClose} className="px-4 py-2 text-sm font-medium text-gray-600 hover:text-gray-900">
            Cancel
          </button>
          <button 
            onClick={handleSave} 
            disabled={isUpdating}
            className="px-4 py-2 bg-black text-white text-sm font-medium rounded-lg hover:bg-gray-900 disabled:opacity-50"
          >
            {isUpdating ? 'Saving...' : 'Save Configuration'}
          </button>
        </div>
      </div>
    </div>
  );
};
```

---

## 4. Team Members List

A simple utility component to display users linked to the organization.

```tsx
export const TeamMembersList = ({ members }) => {
  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-200 bg-gray-50">
        <h3 className="text-sm font-semibold text-gray-900 uppercase tracking-wider">Team Directory</h3>
      </div>
      <ul className="divide-y divide-gray-100">
        {members.map(member => (
          <li key={member.id} className="p-4 flex items-center justify-between hover:bg-gray-50">
            <div>
              <p className="text-sm font-medium text-gray-900">{member.full_name}</p>
              <p className="text-xs text-gray-500">{member.email}</p>
            </div>
            <span className={`px-2 py-1 text-[10px] font-bold uppercase tracking-wider rounded-full ${
              member.org_role === 'ADMIN' ? 'bg-purple-100 text-purple-700' :
              member.org_role === 'FINANCE' ? 'bg-blue-100 text-blue-700' :
              'bg-gray-100 text-gray-700'
            }`}>
              {member.org_role}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
};
```
