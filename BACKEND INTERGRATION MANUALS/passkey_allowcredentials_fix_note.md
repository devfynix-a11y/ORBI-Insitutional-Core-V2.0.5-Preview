# ORBI Passkey Login Fix (Backend)

## Issue
Android passkey login does not show any credential in the selector. This happens when the `allowCredentials[].id` values returned by `/auth/passkey/login/start` do not exactly match the credential ID that was created during registration.

## Required Change
Return the **exact credential ID bytes** that were stored at registration, encoded as **base64url without padding** (RFC 4648 URL-safe). Do **not**:
- Double-encode the ID
- Convert it to base64 (standard +/ and / with padding)
- Wrap it in JSON or change its casing

## Expected Shape (WebAuthn)
`allowCredentials` must be an array of objects:
- `id`: base64url(credentialIdBytes)
- `type`: "public-key"

## Example
If registration returned:
`id = UeIp7rjpwK19NDrYmzqlQvrDStrQhF78c6IQbC2iD00`

Then login/start must include **exactly**:
```
"allowCredentials":[
  { "id":"UeIp7rjpwK19NDrYmzqlQvrDStrQhF78c6IQbC2iD00", "type":"public-key" }
]
```

## Notes
- The Android client compares `allowCredentials[].id` to the stored credential IDs. If any mismatch exists, the passkey UI shows “No available sign in.”
- Keep the original bytes as returned by WebAuthn registration. Only base64url-encode them for transport.
- Existing credentials stored with the old encoding will still fail. Re-register passkeys or run a one-time migration to normalize stored IDs.

## Captured Mismatch Example (from logs)
Registration ID (expected to be returned as-is):
`W_N0jHJY9NYyf4tGe2kOvYl5BGpV7ZZW2b6hl_lqqAo`

Backend allowCredentials ID (incorrect — double-encoded):
`V19OMGpISlk5Tll5ZjR0R2Uya092WWw1QkdwVjdaWlcyYjZobF9scXFBbw`

Fix: return the stored credential_id exactly as saved (already base64url without padding).
