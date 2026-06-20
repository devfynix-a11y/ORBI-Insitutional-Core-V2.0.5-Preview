# Firebase FCM Integration Setup Guide

## Overview
This guide will help you complete the Firebase Cloud Messaging (FCM) integration for push notifications in your ORBI Mobile App.

## What Has Been Implemented
✅ Added Firebase dependencies to `pubspec.yaml`
✅ Created `FirebaseService` for FCM token management
✅ Updated signup flow to include FCM token
✅ Modified auth layers to pass FCM token to backend
✅ Added Firebase initialization in `main.dart`
✅ Updated Android Gradle configuration

## Firebase Project Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or select existing project
3. Enable Google Analytics if desired
4. Complete project creation

### 2. Add Android App
1. In Firebase Console, click "Add app" → Android
2. Package name: `com.orbi.mobile`
3. Download `google-services.json`
4. Place it at `android/app/google-services.json`

### 3. Enable Cloud Messaging
1. In Firebase Console, go to "Cloud Messaging"
2. Follow setup instructions for FCM

### 4. Add iOS App
1. Add iOS app in Firebase Console
2. Bundle ID: `com.orbi.mobile`
3. Download `GoogleService-Info.plist`
3. Place it in `ios/Runner/` directory

## Configuration Files

### Android Configuration
The following files have been updated:
- `android/build.gradle.kts` - Added Google Services classpath
- `android/app/build.gradle.kts` - Added Google Services plugin
- `android/app/google-services.json` - Current app config for `com.orbi.mobile`

### iOS Configuration (recommended)
- Ensure `ios/Runner/Info.plist` remains your normal iOS app plist (CFBundle*, orientations, etc). Do not replace it with Firebase config.
- Place `GoogleService-Info.plist` at `ios/Runner/GoogleService-Info.plist`.
- Ensure the Firebase iOS app is registered with bundle ID `com.orbi.mobile`.
- Leave `FirebaseAppDelegateProxyEnabled` at its default behavior unless you have a specific reason to disable it. If you set it to `false`, you must do additional native iOS integration (manual APNs token forwarding) for Messaging.

## Testing the Integration

### 1. Build and Run
```bash
flutter clean
flutter pub get
flutter run
```

### 2. Verify FCM Token Generation
Check console logs for:
```
🔥 [FCM] Token: <your_fcm_token>
```

### 3. Test Signup with FCM Token
1. Go to signup screen
2. Fill registration form
3. Check that FCM token is included in signup payload
4. Verify backend receives and stores the token

## Push Notification Handling

### Background Messages
Background messages are handled automatically by the `FirebaseService`.

### Foreground Messages
Currently, foreground messages are logged. To show local notifications, add `flutter_local_notifications` dependency and implement notification display.

### Message Actions
When users tap notifications, you can navigate to specific screens based on message data.

## Troubleshooting

### Build Issues
If you encounter Gradle build issues:
1. Clean project: `flutter clean`
2. Delete `.gradle` folder in android directory
3. Rebuild: `flutter pub get && flutter build apk`

### FCM Token Issues
- Ensure `google-services.json` is correctly placed
- Ensure `GoogleService-Info.plist` is correctly placed
- Ensure both Firebase apps use `com.orbi.mobile`
- Check Firebase project configuration
- Verify internet connection for token generation

### Permission Issues
- iOS: Ensure notification permissions are requested
- Android: FCM works automatically on most devices

## Next Steps

1. **Test End-to-End**: Complete signup flow and verify FCM token storage
2. **Backend Integration**: Ensure your backend can send push notifications using stored tokens
3. **Local Notifications**: Add `flutter_local_notifications` for foreground message display
4. **Notification Actions**: Implement deep linking for notification taps
5. **Analytics**: Track notification engagement with Firebase Analytics

## Security Notes
- FCM tokens are device-specific and may change
- Store tokens securely on your backend
- Implement token refresh handling for continued delivery
