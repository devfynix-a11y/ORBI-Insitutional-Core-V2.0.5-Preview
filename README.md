# orbi_mobileapp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

Enterprise additions in this branch:

- Crash reporting: Firebase Crashlytics is integrated (non-debug builds). Make sure to add the native Firebase config files (GoogleService-Info.plist and google-services.json) to the iOS and Android projects respectively for crash reporting to work.
- CI: A GitHub Actions workflow has been added at `.github/workflows/flutter-ci.yml` to run `flutter analyze` and `flutter test` on push and PRs to main/master.
- Docs: See `docs/CI-CD.md` for recommended next steps (release signing, obfuscation, e2e testing).

------------SECURE BIOMETRIC AUTH FLOW
User taps Fingerprint
  ↓ (Biometric succeeds)
  ├─ Has session token? → Auto-login ✅
  └─ No session? 
      ├─ Has stored hash? → Show password form (pre-filled email)
      │   └─ User enters password
      │       ├─ Valid? → Call backend, rotate hash, login ✅
      │       └─ Invalid? → Show error, retry
      └─ No credentials? → Fall back to regular login form