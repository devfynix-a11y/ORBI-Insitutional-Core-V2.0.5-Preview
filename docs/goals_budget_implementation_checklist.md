# Goals & Budget Implementation Checklist

This checklist maps the product review in `Goals&Badget implementation Review.md` to the current ORBI mobile app and the stable backend.

## Core Principle

- Every unit of money should have a purpose state.
- Budgets are soft spending controls.
- Goals are hard savings allocations and should not be silently spent.
- Ledger and transaction guard remain the source of truth.

## Status Summary

### Done In App

- Goals and Budget screen localized for English and Swahili.
- Goal create, edit, delete, and fund allocation flows.
- Budget create, edit, and delete flows.
- Goal auto-allocation settings:
  - `manual`
  - `percentage`
  - `fixed`
- Transfers now support:
  - source wallet selection
  - optional budget category tagging
- Tasks planning surfaced in the Goals area:
  - list tasks
  - create task
  - edit task
  - complete or reopen task
  - delete task

### Done In Stable Backend

- `GET /v1/goals`
- `POST /v1/goals`
- `PATCH /v1/goals/:id`
- `DELETE /v1/goals/:id`
- `POST /v1/goals/:id/allocate`
- `GET /v1/categories`
- `POST /v1/categories`
- `PATCH /v1/categories/:id`
- `DELETE /v1/categories/:id`
- `GET /v1/tasks`
- `POST /v1/tasks`
- `PATCH /v1/tasks/:id`
- `DELETE /v1/tasks/:id`
- Transaction preview and execution support `sourceWalletId` and `categoryId`
- Goal model already supports:
  - `fundingStrategy`
  - `autoAllocationEnabled`
  - `linkedIncomePercentage`
  - `monthlyTarget`

## Still Missing

### High Priority

- Explicit goal withdrawal or "break goal" consumer flow
  - no consumer `POST /goals/:id/withdraw` route exists yet
  - app should not pretend this exists until backend route is implemented
- Stronger goal lock UX in transactions
  - show when selected funds are goal-restricted
  - require explicit confirmation before any goal release flow
- Budget-first payment UX
  - current transfers can tag budgets, but the app does not yet clearly show budget-first routing decisions

### Medium Priority

- Money lifecycle visibility in UI
  - show where money is currently allocated
  - show whether funds are available, budgeted, saved, locked, or spent
- Goal forecast and completion prediction
- Budget overspend resolution UX
  - warn
  - block
  - or offer fallback options based on backend policy
- Better task-goal linkage in cards and dashboards

### Enterprise and Advanced

- Goal withdrawal with approval workflow for enterprise treasury
- Enterprise auto-sweep configuration UI
- Budget alerts center
- Conflict resolver suggestions:
  - move from goal
  - adjust budget
  - use main wallet

## Recommended Build Order

1. Finish tasks UX polish and planner overview integration
2. Add explicit consumer goal withdrawal backend route and app flow
3. Add locked-goal transaction guard UX in app
4. Add budget-first payment guidance and overspend handling
5. Surface lifecycle states in dashboard and transaction details
6. Expand enterprise treasury and approval controls

## Design Rules To Preserve

- Never spend goal money silently.
- Never bypass ledger semantics in UI assumptions.
- Always keep budget and goal purpose distinct.
- Always show users when money is restricted or requires confirmation.
