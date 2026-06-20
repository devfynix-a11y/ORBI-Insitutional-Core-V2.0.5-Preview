# ORBI Mobile Release Ledger

This ledger tracks signed Android release artifacts and the signing identity used to publish them.

## How To Use This File

- Add one new release entry for every APK or AAB shipped for testing or production.
- Use the APK SHA-256 to verify the exact artifact that was shared or installed.
- Use the certificate SHA-256 for backend trust, Firebase, Android App Links, and certificate allowlisting.
- Do not replace old entries. Append new ones so release history stays auditable.

## Fingerprint Rules

- The APK fingerprint changes whenever a new release artifact is built.
- The certificate fingerprint should stay the same across releases if we keep signing with the same keystore and key alias.
- The backend trust hash should only change if the signing certificate changes.

## Current Backend Trust Values

- Package name: `com.orbi.mobile`
- Certificate SHA-256: `89:EA:FE:BD:11:8B:28:C2:53:2F:32:4F:50:94:D4:AD:67:47:B8:2C:54:EF:95:72:39:3D:2D:31:1E:DD:83:0A`
- Certificate SHA-256 (base64): `ier+vRGLKMJTLzJPUJTUrWdHuCxU75VyOT0tMR7dgwo=`
- Certificate SHA-1: `FB:BE:74:12:64:26:5E:A6:A7:60:29:9D:B9:D0:BD:95:D0:3C:EB:1A`

## Release Entries

### 2026-04-25 - ORBI Mobile Release APK

- Artifact: `ORBI Financial V.1.0.0.apk`
- Path: `build/app/outputs/flutter-apk/ORBI Financial V.1.0.0.apk`
- Absolute path: `D:\FYNIX\ORBI\ORBI FINTECH MOBILE APP\orbi_mobileapp\build\app\outputs\flutter-apk\ORBI Financial V.1.0.0.apk`
- Size: `48,472,944 bytes`
- Build target: `android-arm64`
- App version: `1.0.0+1`
- APK SHA-256: `2A4A849407C1FE2EB777529E411C49CB3DF894834643D1BDDF2182C09CD453CD`
- APK SHA-1: `BF5B832538D59430AB5F40600ADE2129BF881AEE`
- Signing keystore: `android/obi-release-2026.keystore`
- Signing alias: `CEO Is Daniel Gibai`
- Signing verified: `Yes`
- Backend trust hash: `ier+vRGLKMJTLzJPUJTUrWdHuCxU75VyOT0tMR7dgwo=`
- Notes: First recorded signed release artifact for backend-linked testing. Original Flutter output `app-release.apk` was preserved and a named release copy was created.

## Template For Next Release

```md
### YYYY-MM-DD - Release Name

- Artifact: `app-release.apk`
- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Absolute path: `D:\path\to\artifact.apk`
- Size: `00,000,000 bytes`
- Build target: `android-arm64`
- APK SHA-256: `...`
- APK SHA-1: `...`
- Signing keystore: `android/obi-release-2026.keystore`
- Signing alias: `CEO Is Daniel Gibai`
- Backend trust hash: `ier+vRGLKMJTLzJPUJTUrWdHuCxU75VyOT0tMR7dgwo=`
- Notes: ...
```
