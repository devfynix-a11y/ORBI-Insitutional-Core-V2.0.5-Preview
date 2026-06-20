# Localization Audit

This app already uses Flutter localization with `lib/l10n/*.arb` and `AppSettingsController`.

The goal is to move all user-facing UI text into localization keys so the saved user language fully drives the experience.

## Current Foundation

- `MaterialApp.locale` is already connected to user settings.
- English and Swahili are already configured.
- Auth onboarding, language selection, signup, and much of login are localized.

## Next Priority Screens

1. `lib/features/auth/presentation/login_screen.dart`
   Remaining hardcoded copy is small and should be fully cleaned up first.

2. `lib/features/shell/app_shell.dart`
   High-visibility navigation and session feedback should follow app language.

3. `lib/features/dashboard/presentation/dashboard_screen.dart`
   Large user-facing surface with many labels, cards, dialogs, and snackbars.

4. `lib/features/wallet/presentation/wallet_screen.dart`
   Core financial experience with many visible labels and actions.

5. `lib/features/transfers/presentation/send_money_screen.dart`
   Very large surface with many helper texts, errors, confirmation labels, and receipt strings.

6. `lib/features/transactions/presentation/transactions_screen.dart`
   Includes visible UI plus PDF/print strings that should be localized.

7. `lib/features/notifications/presentation/notifications_screen.dart`
   Customer-facing feed and detail labels should be localized consistently.

8. `lib/features/payment/presentation/payment_screen.dart`
   Shorter screen, but currently contains visible hardcoded action labels.

## Secondary Cleanup

- `lib/core/widgets/*`
  Shared widgets with visible labels should accept localized text from callers or use `AppLocalizations` when appropriate.

- `lib/features/settings/presentation/widgets/*`
  Some helper and settings widget copy still needs review.

- `lib/features/profile/*`
  Verify visible strings and action labels are driven by localization.

## Rollout Pattern

For each screen:

1. Find hardcoded user-facing text.
2. Add keys to `app_en.arb` and `app_sw.arb`.
3. Replace literals with `AppLocalizations.of(context)!`.
4. Run `flutter gen-l10n`.
5. Run `dart analyze` on the touched files.

## Notes

- Do not localize backend identifiers, route names, analytics keys, or debug logs unless they are shown to users.
- Prefer concise, customer-friendly language over technical/internal terminology.
- For ORBI, prioritize wording around trust, control, salary, offers, merchants, growth, and wealth management.
