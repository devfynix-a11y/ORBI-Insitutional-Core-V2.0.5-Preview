# ORBI Mobile Feature Architecture Standard

Date: 2026-04-08

This document defines the target architecture standard for new feature development and refactors in the ORBI mobile app.

## Goal

Use a feature-first modular structure with pragmatic clean layering:

- feature UI stays inside the feature
- business rules do not live in widgets
- API and backend parsing do not live in screens
- shared infrastructure stays in `lib/core`

This is the default development standard for ORBI mobile.

## Core Rule

Every feature should be organized by responsibility, not by file type across the whole app.

Use:

- `presentation`
- `state`
- `data`
- `domain` when the feature has real business logic or reusable use cases

## Standard Feature Shape

Target structure:

```text
lib/
  core/
    config/
    network/
    theme/
    utils/
    widgets/
  features/
    <feature>/
      presentation/
        screens/
        widgets/
        mappers/
      state/
      domain/
        entities/
        repositories/
        usecases/
      data/
        models/
        services/
        repositories/
```

## Layer Responsibilities

### `presentation`

Contains:

- screens
- feature widgets
- UI-only mapping
- local display helpers

Must not contain:

- direct Dio calls
- raw backend query orchestration
- large business calculations
- provider or payment decision logic

### `state`

Contains:

- controllers
- view models
- screen orchestration
- loading and action state

Responsibilities:

- call use cases or repositories
- hold screen state
- transform domain results into presentation state

### `domain`

Use this only for medium/complex features.

Contains:

- entities
- repository contracts
- use cases
- business rules

Examples for ORBI:

- provider selection rules
- funding-source eligibility
- goal funding pace logic
- withdrawal safety rules
- budget status logic

### `data`

Contains:

- API services
- request/response models
- mappers
- repository implementations

Responsibilities:

- talk to backend
- parse JSON
- normalize unstable backend field names
- convert DTOs to domain or feature models

### `core`

Contains only cross-app shared infrastructure:

- API client
- auth/session access
- localization helpers
- money formatting
- shared widgets
- theme

Must not become a dumping ground for feature workflows.

## Architecture Levels For ORBI

Use one of these three levels depending on complexity.

### Level 1: Simple Feature

Use:

- `presentation`
- `state`
- `data`

Examples:

- notifications
- settings
- profile

### Level 2: Medium Feature

Use:

- `presentation`
- `state`
- `data`
- optional `domain`

Examples:

- goals
- dashboard
- services

### Level 3: Complex Money Feature

Use full layering:

- `presentation`
- `state`
- `domain`
- `data`

Examples:

- payment
- wallet
- transfers
- auth

## Target Structure For ORBI

### `payment`

```text
lib/features/payment/
  presentation/
    screens/
      payment_screen.dart
    widgets/
      bill_category_tile.dart
      bill_provider_tile.dart
      bill_pay_sheet.dart
      merchant_pay_sheet.dart
      payment_scan_widgets.dart
    mappers/
      payment_ui_mapper.dart
  state/
    payment_controller.dart
    bill_pay_controller.dart
    merchant_pay_controller.dart
  domain/
    entities/
      bill_provider.dart
      bill_category.dart
      payment_intent.dart
      payment_preview.dart
    repositories/
      payment_repository.dart
    usecases/
      load_bill_catalog.dart
      preview_bill_payment.dart
      settle_bill_payment.dart
      load_routing_catalog.dart
  data/
    models/
      bill_provider_dto.dart
      payment_preview_dto.dart
    services/
      gateway_payment_service.dart
      receipt_scan_service.dart
      scan_pay_service.dart
      payment_routing_catalog_service.dart
      service_actor_payment_service.dart
    repositories/
      payment_repository_impl.dart
```

Notes:

- split the large `payment_screen.dart` over time
- move bill provider loading, preview, and settle orchestration out of screen state
- keep scan matching in domain/data boundaries, not inline in UI

### `wallet`

```text
lib/features/wallet/
  presentation/
    screens/
      wallet_screen.dart
      deposit_funds_screen.dart
      shared_budgets_screen.dart
      shared_pots_screen.dart
      bill_reserves_screen.dart
    widgets/
      wallet_summary_card.dart
      provider_choice_card.dart
      deposit_composer.dart
      shared_budget_card.dart
      shared_pot_card.dart
    mappers/
      wallet_ui_mapper.dart
  state/
    wallet_controller.dart
    deposit_controller.dart
    shared_budget_controller.dart
    shared_pot_controller.dart
    bill_reserve_controller.dart
  domain/
    entities/
      wallet_account.dart
      deposit_provider.dart
      deposit_movement.dart
      shared_budget.dart
      shared_pot.dart
      bill_reserve.dart
    repositories/
      wallet_repository.dart
    usecases/
      load_wallets.dart
      load_deposit_providers.dart
      submit_deposit.dart
      load_shared_budgets.dart
      load_shared_pots.dart
      load_bill_reserves.dart
  data/
    models/
      wallet_dto.dart
      deposit_provider_dto.dart
      shared_budget_dto.dart
      shared_pot_dto.dart
      bill_reserve_dto.dart
    services/
      wallet_service.dart
      deposit_service.dart
      wealth_service.dart
    repositories/
      wallet_repository_impl.dart
```

Notes:

- move raw wallet map parsing into data models
- centralize provider-to-UI conversion
- shared budget and shared pot should not directly parse backend maps inside screens

### `goals`

```text
lib/features/goals/
  presentation/
    screens/
      goals_screen.dart
    widgets/
      goal_card.dart
      budget_card.dart
      task_card.dart
      goals_summary_card.dart
      goals_shared_widgets.dart
    mappers/
      goals_ui_mapper.dart
  state/
    goals_controller.dart
  domain/
    entities/
      goal_item.dart
      budget_item.dart
      task_item.dart
      goal_summary.dart
    repositories/
      goals_repository.dart
    usecases/
      load_goals_dashboard.dart
      allocate_goal_funds.dart
      withdraw_goal_funds.dart
      load_budget_status.dart
  data/
    models/
      goal_dto.dart
      category_dto.dart
      task_dto.dart
    services/
      goals_service.dart
    repositories/
      goals_repository_impl.dart
```

Notes:

- card widgets should stay dumb and reusable
- runtime mapping from backend objects to UI card props should happen in `mappers` or controller/domain layers
- summary calculations should not live inline in widget trees

## Development Rules

### 1. No Raw Backend Maps In Widgets

Do not pass `Map<String, dynamic>` into feature widgets except at temporary migration boundaries.

Use:

- typed DTOs in `data`
- typed feature/domain models in `state` and `presentation`

### 2. No API Calls In Screens

Screens should trigger controller/state actions, not call services directly.

### 3. UI Mapping Is Explicit

If a backend payload does not match the card UI shape, create a mapper.

Examples:

- `GoalDto -> GoalCardViewData`
- `GatewayProviderDto -> DepositProviderViewData`
- `BillProviderCategoryDto -> BillCategoryViewData`

### 4. Shared Widgets Must Be Truly Shared

Only move something to `core/widgets` if it is used across multiple features.

If it is only shared inside one feature, keep it inside that feature.

Examples:

- `mini_analytics_widget.dart` belongs in `core/widgets`
- goals card shells belong in `features/goals/presentation/widgets`

### 5. Money Formatting Must Stay Centralized

All feature UIs must use shared formatting from:

- `lib/core/utils/money_format.dart`
- `lib/core/widgets/money_text.dart`

Do not reintroduce local money formatting rules in individual screens.

### 6. Feature State Owns Async Work

Loading, retries, submit progress, and error messages belong in controllers/state, not spread across many widgets.

### 7. Domain Is For Rules, Not For Boilerplate

Only introduce `domain/usecases` when the feature has reusable or important business rules.

Do not add empty clean-architecture layers just for appearance.

## Migration Order

Recommended refactor order:

1. `payment`
2. `wallet`
3. `goals`
4. `transfers`
5. `services`

Reason:

- `payment` and `wallet` currently carry the most orchestration and backend coupling
- `goals` has already started splitting into shared presentation pieces

## Definition Of Done For A Refactored Feature

A feature is considered architecture-compliant when:

- screen files are primarily layout and event wiring
- services are only used from `data` or `state`
- raw backend maps do not leak into cards/widgets
- money formatting uses shared helpers
- shared widgets are in the correct scope
- business rules are isolated from the widget tree

## Immediate Next Steps

### Payment

- extract bill catalog loading into a repository and controller
- split bill pay sheet and provider picker widgets out of `payment_screen.dart`
- move payment preview/settle orchestration into use cases or controller methods

### Wallet

- introduce typed models for deposit providers, shared budgets, shared pots, and bill reserves
- centralize wallet record parsing
- remove screen-level backend map interpretation

### Goals

- move card view-data mapping into a dedicated mapper
- extract summary calculations out of the screen build method
- keep `goal.dart`, `budget.dart`, and `task.dart` presentation-only

## Final Standard

For ORBI mobile, the professional architecture standard is:

Feature-first modular architecture with pragmatic clean layering.

That means:

- feature-local UI
- typed data boundaries
- controller-driven async orchestration
- domain rules only where complexity justifies them
- shared infrastructure only in `core`
