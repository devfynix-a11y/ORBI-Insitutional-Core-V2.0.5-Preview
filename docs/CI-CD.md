# CI / CD and Release Notes

This repository now includes a basic GitHub Actions CI workflow (.github/workflows/flutter-ci.yml) that:

- Runs on push and pull requests to main/master
- Sets up Flutter and Java (for Android toolchain)
- Runs `flutter pub get`, `flutter analyze`, and `flutter test --coverage`
- Uploads coverage artifacts as an optional artifact
It also includes a manual release workflow at `.github/workflows/flutter-release.yml` that can build Android and iOS release artifacts using workflow dispatch inputs.
Next recommended steps for enterprise readiness:

1. Crash reporting
   - Firebase Crashlytics is enabled for non-debug builds. Ensure Firebase config files (GoogleService-Info.plist / google-services.json) are present in the native projects for CI and release builds.
   - Android: the Gradle Crashlytics plugin and runtime dependency have been added to `android/build.gradle.kts` and `android/app/build.gradle.kts`. Ensure `google-services.json` is present in `android/app` and that `key.properties`/signing are configured in CI if you use upload-symbols or mapping file uploads.
   - iOS: `GoogleService-Info.plist` is expected in `ios/Runner`. After building an iOS release, upload dSYMs to Crashlytics (or configure App Store Connect symbol upload). See Firebase docs for automating dSYM uploads.

2. Release signing and obfuscation
   - Document and automate Android keystore and iOS signing credentials in your CI secrets.
   - Use `--obfuscate` and `--split-debug-info` for release builds to reduce reverse engineering risk.
   - A manual GitHub Actions release workflow is available at `.github/workflows/flutter-release.yml`. It supports optional Android and iOS release builds with `workflow_dispatch` inputs for local-only signing values.
   - Android releases require `android/key.properties` or passed keystore inputs. iOS releases require macOS runners and a valid Apple signing environment.
   - To enable automatic symbol upload to Crashlytics, provide the necessary service account credentials and follow Firebase Crashlytics docs to upload mapping and dSYM files.

   Example release workflow inputs:

   ```yaml
   enable_android: true
   enable_ios: false
   android_keystore_base64: ${{< base64 encoded keystore >}}
   android_keystore_password: <keystore password>
   android_key_alias: <key alias>
   android_key_password: <key password>
   firebase_token: <firebase token>
   firebase_android_app_id: <android firebase app id>
   firebase_ios_app_id: <ios firebase app id>
   ```

3. Test matrix and e2e
   - Add integration/e2e tests (integration_test or driver) and run them on emulators or device farms (Firebase Test Lab / Bitrise / Codemagic).
   - A GitHub Actions integration-test workflow that starts an Android emulator and runs `flutter test integration_test` has been added at `.github/workflows/integration-test.yml`.

4. Deployment
   - Add release workflows that build artifacts and publish to internal distribution (TestFlight, Play Internal) with manual approvals for production releases.

5. Compliance and security
   - Add automated SAST/secret scanning and supply a documented mobile security checklist (OWASP Mobile Top 10, PCI considerations).

If you'd like, I can add further CI steps (release build, obfuscation, artifact publishing, or a device lab run).
