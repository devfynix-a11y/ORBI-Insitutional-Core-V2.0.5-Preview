# ORBI Mobile UI Modernization Plan

## Product Direction
ORBI Mobile should feel like a compact financial operating system: fast to scan, clear to act on, and calm under pressure. The redesign will reduce long report-style cards and replace them with focused mobile surfaces that answer three questions quickly: what do I have, what can I do, and what needs attention?

## Design Principles
- One primary hero per page, kept compact enough that the first actionable controls remain visible without heavy scrolling.
- Replace stacked summary sections with horizontal rails, chips, and dense status modules.
- Keep every existing function. Redesign presentation and flow clarity before changing behavior.
- Every transaction flow must show source wallet, target, fees, limits, provider state, and clear recoverable errors.
- Shared wallets and shared pots must be role-aware, balance-aware, and explicit about who can contribute, withdraw, invite, approve, or close.
- Use progressive disclosure: overview first, details in sheets or expandable panels.

## Visual System
- Base: deep financial navy, warm ivory surfaces, and subtle glass cards.
- Primary accent: emerald/teal for money movement and success.
- Secondary accent: champagne/gold for savings, vaults, and protected value.
- Risk colors: amber for review/limits, red for blocked actions, blue for informational states.
- Shape language: rounded but disciplined, with compact elevation and fewer full-width decorative cards.

## App Architecture
- Dashboard becomes a command center: balance, session/security, primary actions, and compact treasury metrics.
- Wallet becomes a money map: main operating wallet, linked providers, shared pots, budgets, and reserves as short rails.
- Transfers and withdrawals use compact professional confirmation sheets with source wallet visible.
- Payments use provider-first cards, short categories, and clear preview/confirmation states.
- Transactions use lifecycle chips, issue-focused filters, and compact ledger rows.
- Advanced/enterprise areas should feel like control panels, not article pages.

## Page Rollout
- Phase 1: Dashboard and shell rhythm.
- Phase 2: Wallet, shared wallets, shared pots, budgets, and linked wallet surfaces.
- Phase 3: Send, withdraw, deposit, and payment preview/confirmation flows.
- Phase 4: Transactions, goals, services, enterprise, profile, settings, and notifications.
- Phase 5: Responsive polish, accessibility, loading states, empty states, and release build verification.

## Shared Wallet And Pot Audit Checklist
- Confirm source and target wallet resolution is visible and cannot silently choose the wrong wallet.
- Show self-transfer prevention with a clear user message.
- Show shared pot member roles, contribution rules, withdrawal rules, target progress, and lock/approval state.
- Keep provider errors human-readable and separate from validation errors.
- Ensure loading states stay in the main UI, not only inside buttons.
- Preserve all backend-driven configuration and avoid hardcoded provider secrets or production URLs.

## Continuing Rule
Use this plan as the standing direction for future ORBI Mobile UI work. Continue page by page without re-asking for permission unless a change risks removing functionality, changing transaction behavior, or exposing secrets.
