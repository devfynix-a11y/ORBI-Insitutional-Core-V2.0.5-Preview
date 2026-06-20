# ORBI Mobile Financial Product UI Plan

## Product Direction

ORBI should feel like a serious financial product: clear, secure, calm, and intelligent. The app should not look like a generic wallet with scattered cards. It should behave like a trusted financial command center for consumers, agents, merchants, and future business users.

## Design Rules

- Use ORBI blue as the visible brand anchor, with deep charcoal surfaces in dark mode and soft white/light-wash surfaces in light mode.
- Use shared card primitives instead of per-screen custom paint so the full app evolves consistently.
- Use tabular figures for all balances and financial values to prevent layout jitter.
- Keep primary cards visually branded; secondary cards should be quieter but still clearly separated from the page background.
- Prefer consumer language in English and Swahili. Avoid technical error strings, backend paths, stack traces, and raw exception details.
- Keep touch targets at least 44px where possible, especially quick actions, nav items, and financial controls.

## Dashboard Architecture

- Bento layout: dashboard modules are arranged as responsive financial blocks rather than a long banking list.
- Focus view: simple, direct balance and actions for everyday users.
- Insight view: richer financial context for power users, including wealth composition, trend sparkline, and financial velocity.
- Security pulse: visible session safety status using green, amber, and danger states as the 3-minute lock approaches.
- Wealth ring: show internal funds, linked wallets, planned funds, and ready cash as one financial orbit.
- Sparkline: give the user a quick sense of financial trajectory without forcing them into reports.

## Security UX

- Maintain the 3-minute inactivity lock.
- Keep the soft warning before lock so users can extend the session intentionally.
- Preserve profile metadata on lock, but clear sensitive active session state.
- Use Android `FLAG_SECURE` for financial screen privacy.
- Keep security feedback understandable: "Secure", "Extend", "Locking", not technical policy names.

## Next Product Layers

- Device orbit: a dedicated security history view showing login devices, session expiry, and trusted-device status.
- Adaptive shortcuts: reorder common actions based on behavior and time context when backend signals are available.
- Rive navigation: replace deterministic animated icon fallback with `.riv` state machines once final ORBI icon animations are exported.
- Smart search: future natural-language financial search once backend analytics endpoints are stable.
- Rich transaction intelligence: clearer user-facing explanations for failed previews, route blocks, and provider outages.

## Implementation Status

- Added shared enterprise card styling primitives.
- Added reusable responsive Bento grid/card primitives.
- Added glassmorphic blur treatment to shared Bento and section card surfaces.
- Added reusable sparkline and wealth ring widgets.
- Added persisted Focus/Insight dashboard mode.
- Added dashboard security pulse, timeout pulsing, and insight strip.
- Added Roboto Mono/tabular money rendering.
- Added haptic feedback to shared quick action tiles and Bento cards.
- Added Android screenshot/screen-recording protection.
- Verified with `flutter analyze` and Android debug APK build.
