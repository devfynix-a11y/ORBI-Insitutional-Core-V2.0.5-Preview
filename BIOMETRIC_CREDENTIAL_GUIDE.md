# Biometric Credential Authentication Guide

## Overview
This app now supports **session-independent biometric authentication** using hashed credential storage. Users can log in with their fingerprint/face even if their session token has expired, as long as biometric is enabled and valid credentials are stored locally.

## Architecture

### 1. **Credential Hashing** (`lib/core/security/password_hasher.dart`)
- **Hash Function**: SHA256 with email salt
- **Formula**: `hash = SHA256(email:password)`
- **Benefits**:
  - Same password hashed under different emails produces different hashes
  - Rainbow table attacks become ineffective
  - Reversible decryption not needed (client-side hashing only)

```dart
// Hash a password
final hash = PasswordHasher.hashPassword("user@example.com", "password123");

// Verify a password
final isValid = PasswordHasher.verifyPassword("user@example.com", "password123", storedHash);
```

### 2. **Secure Storage** (`lib/core/storage/secure_storage_service.dart`)
Credentials stored in `FlutterSecureStorage` (encrypted on-device).

**Methods**:
- `saveBiometricCredentials(email, passwordHash)` - Store hashed credentials
- `getBiometricCredentials()` - Retrieve stored credentials (returns `{email, passwordHash}`)
- `clearBiometricCredentials()` - Delete stored credentials

### 3. **Authentication Controller** (`lib/features/auth/state/auth_controller.dart`)

#### **Password Login (Regular Flow)**
1. User enters email + password
2. Backend validates and returns session token
3. If biometric is **enabled**, store hashed credentials locally:
   ```dart
   final hash = PasswordHasher.hashPassword(email, password);
   await _storage.saveBiometricCredentials(email, hash);
   ```

#### **Biometric Login (Three Cases)**

**Case 1: Session Token Exists** ✅ (Most Common)
- Biometric succeeds → Use stored session token → Auto-login
- Fast path, no password needed

**Case 2: No Session Token, Credentials Exist** 🔐
- Biometric succeeds
- Detects no session token
- Shows password verification UI (email pre-filled)
- User enters password → Verified against stored hash locally
- If valid → Call backend login with plaintext password to get fresh token
- Hash is then rotated (re-hashed) for security

**Case 3: No Session, No Credentials** ❌
- Biometric succeeds but credentials weren't stored (user never enabled biometric)
- Fall back to password login

### 4. **Login Screen Flow** (`lib/features/auth/presentation/login_screen.dart`)

#### **Initial State**
- If biometric enabled: Show fingerprint button as primary option
- Otherwise: Show email/password form

#### **After Biometric Success (No Session)**
1. Screen detects "Please enter password" error
2. Sets `_awaitingPasswordVerification = true`
3. Pre-fills email field with stored email
4. Changes UI to show green checkmark: "Biometric verified!"
5. User enters password in pre-filled form
6. Button changes to "Verify & Login"

#### **Password Verification**
- Calls `auth.verifyAndLoginWithStoredPassword(email, password)`
- Password verified locally against stored hash (no backend call yet)
- If valid, calls backend login to get fresh session token
- Rotates hash for security (stores new hash from this login)
- Navigates to app shell

### 5. **Security Features**

✅ **3-Strike Lockout**
- 3 failed biometric attempts → temporarily disables biometric
- User must use password to re-unlock
- Counter resets on successful login

✅ **Credential Rotation**
- Hash is updated after every successful password login
- Even if old hash is compromised, it becomes invalid next login
- Prevents replay attacks

✅ **Encrypted Storage**
- All credentials stored in `FlutterSecureStorage`
- Encrypted at rest on device
- Not accessible without device unlock

✅ **No Plaintext Passwords**
- Passwords never transmitted over insecure channels
- Only hashes stored locally
- Backend receives plaintext password only via HTTPS

---

## Complete Biometric Login Flow Diagram

```
User taps Biometric Button
    ↓
BiometricAuthService.authenticate()
    ↓
Device biometric prompt appears
    ├─ User cancels → Biometric failed, error message
    ├─ Biometric fails 3 times → Temporarily disable, show lock message
    └─ Biometric succeeds! ✓
        ↓
        Check: Session token exists?
        ├─ YES → Use stored token, auto-login ✅ FAST PATH
        └─ NO (New device/cleared session)
            ↓
            Check: Stored credentials exist?
            ├─ YES → Show password verification UI
            │   ↓
            │   User enters password
            │   ↓
            │   PasswordHasher.verifyPassword(email, password, storedHash)
            │   ├─ Valid → Login to backend with plaintext password
            │   │   ↓
            │   │   Rotate hash: save new hash from this login
            │   │   ↓
            │   │   Auto-login to app ✅
            │   └─ Invalid → Show error, return to login form
            └─ NO → Fall back to password form
```

---

## Implementation Checklist

- ✅ `PasswordHasher` utility created
- ✅ `SecureStorageService` updated with credential methods
- ✅ `AuthController.login()` saves hashed credentials on success
- ✅ `AuthController.biometricLogin()` handles all three cases
- ✅ `AuthController.verifyAndLoginWithStoredPassword()` added for password verification
- ✅ `AuthController.getStoredBiometricEmail()` for pre-filling form
- ✅ `LoginScreen` updated with password verification UI
- ✅ `LoginScreen` detects verification mode and shows appropriate UX

---

## Testing Guide

### Test Case 1: Normal Biometric + Session Token
1. Log in with password (session saved)
2. Enable biometric in settings
3. Log out
4. Tap biometric button → Should auto-login immediately ✅

### Test Case 2: New Device (No Session Token)
1. On Device A: Log in + enable biometric (credentials hashed and stored)
2. Extract storage database
3. On Device B: Restore storage
4. Tap biometric button → Should show "Biometric verified!" + password prompt
5. Enter password → Should verify locally and login ✅

### Test Case 3: Three Failures (Lockout)
1. Enable biometric, tap the button
2. Fail 3 times with wrong fingerprints
3. Should see "Biometric temporarily locked" message
4. Use password to login instead ✅
5. Lock resets automatically (counter cleared)
6. Can use biometric again next time

### Test Case 4: Disable Biometric
1. Enable biometric (credentials stored)
2. Go to settings and disable biometric
3. Stored credentials should be cleared immediately
4. Log out → Credentials gone from device ✅

---

## Security Considerations

### ⚠️ **Database Compromise**
- If device is compromised and `FlutterSecureStorage` is accessed directly:
  - Attacker gets email + password hash
  - Cannot use hash to login (verified locally against stored credentials)
  - Hash is not the plaintext password
  - Cannot use hash to authenticate to backend
  - **Mitigation**: Hash is rotated on every login; old hash becomes invalid

### ⚠️ **Hash Reversal**
- SHA256 is one-way; cannot decrypt to get password
- **But**: Attacker could brute-force common passwords
- **Mitigation**: Email salt makes this harder; strong passwords help

### ⚠️ **Better Alternatives (Future)**
- Use PBKDF2 or argon2 instead of SHA256 for stronger hashing
- Add salt from backend for better security
- Implement biometric challenge-response with backend
- Store refresh tokens instead of password hashes

---

## User Flow Summary

### First Time (Regular Login)
1. User enters email + password
2. Server validates, returns session token
3. If user enabled biometric:
   - App hashes password locally
   - Stores: `(email, hash)` in encrypted storage
4. User can now use biometric next time

### Subsequent Logins (Biometric Available)
1. User taps fingerprint button
2. **If session exists**: Auto-login (fast path) ✅
3. **If session missing**: Shows password verification step
   - Email pre-filled
   - User enters password
   - Verified against stored hash locally
   - Backend login called for fresh token
   - Hash rotated for next time

### Security Reset
- Disable biometric in settings → Credentials cleared
- 3 failed biometric attempts → 15-min temporary lock
- Logout without biometric enabled → Credentials stay (for next login)

---

## API Changes

### New Methods in AuthController
```dart
// Verify password against stored hash and login
Future<bool> verifyAndLoginWithStoredPassword(String email, String password)

// Get pre-filled email from stored credentials
Future<String?> getStoredBiometricEmail()
```

### Enhanced Methods
```dart
// Now saves hashed credentials after successful login
Future<bool> login(String email, String password)

// Now handles case where no session token exists
Future<bool> biometricLogin()

// Now clears credentials if biometric disabled
Future<void> logout()
```

---

## Debugging

**Enable verbose logging**:
- All auth flows print detailed debug logs with ✅/❌/⚠️ prefixes
- Check console for full authentication details

**Check stored credentials**:
```dart
final creds = await SecureStorageService().getBiometricCredentials();
print('Stored credentials: $creds'); // Should show {email, passwordHash}
```

**Check biometric status**:
```dart
final enabled = await SecureStorageService().isBiometricEnabled();
final failed = await SecureStorageService().getBiometricFailedAttempts();
print('Biometric enabled: $enabled, Failed attempts: $failed');
```
