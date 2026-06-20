# ORBI App Backend Feature Roadmap

This roadmap reflects features already present or hinted at in the stable backend and the next app integrations that will deliver the most value.

## Ready To Integrate Next

- Transaction source selection
  The backend already supports `sourceWalletId`, `targetWalletId`, and `categoryId`, so the app can offer explicit wallet or goal-funded transaction routing.
- Goal editing
  The app and stable backend now support goal updates. Next step is exposing richer goal fields like funding strategy and auto-allocation preferences in the UI.
- Strategic tasks
  Backend routes exist for listing, creating, updating, and deleting tasks. The app can surface these as planning actions linked to goals.
- Enterprise organization flows
  Organization details, invites, user linking, treasury approvals, autosweep, and budget alerts already exist server-side and can be brought into the enterprise app area.

## Needs Expanded App UX

- Auto allocation rules
  Backend goal models include `fundingStrategy`, `autoAllocationEnabled`, `linkedIncomePercentage`, and `monthlyTarget`. The app should add setup and management screens for these.
- Goal and wallet selection during transactions
  Current transfer UX should be extended so users can deliberately choose operating wallet, goal-backed funding, or budget/category-linked transfers.
- Goal detail editing
  After the basic edit flow, add editing for color, icon, deadline clearing, and contribution rules.

## Advanced Enterprise Opportunities

- Treasury operating policies
  Build screens for threshold controls, autosweep visibility, and treasury approval queues.
- Budget alert center
  Surface real-time enterprise budget alerts with drill-down into affected departments and categories.
- Enterprise analytics
  Add views for approval throughput, policy exceptions, liquidity posture, and allocation efficiency.
- Role-aware controls
  Match enterprise dashboards and actions to backend roles and approvals.

## Suggested Delivery Order

1. Goal edit and task surfaces
2. Transaction wallet and goal selection
3. Auto-allocation configuration
4. Enterprise treasury and approvals
5. Enterprise analytics and advanced controls
