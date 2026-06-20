# Financial Core Engine (Core Banking Architecture)

**Classification**: INSTITUTIONAL / CORE ARCHITECTURE  
**Version**: 2.0.0  
**Last Updated**: 2026-03-11

---

## 1. Executive Summary
The **Financial Core Engine** elevates ORBI from a simple wallet application to a full-fledged **Banking-as-a-Service (BaaS) / Fintech Platform**. By introducing a true **Multi-Tenant Architecture**, the system can now natively host and isolate different types of financial entities on the same infrastructure.

This is the exact architecture used by modern Core Banking Systems to manage accounts, balances, transactions, clearing, and settlement across multiple distinct businesses.

---

## 2. Multi-Tenant Architecture

### 2.1 The `tenants` Entity
A Tenant is any distinct entity operating on the platform.
- **`individual`**: A standard retail user.
- **`merchant`**: A business accepting payments.
- **`marketplace`**: A platform hosting multiple sub-merchants.
- **`partner`**: A B2B partner integrating via API.
- **`system`**: Internal ORBI operational accounts (e.g., fee collection, treasury).

### 2.2 Tenant Users (`tenant_users`)
Users are no longer strictly tied to personal wallets. A single user (via `auth.users`) can belong to multiple tenants with different roles:
- **`owner`**: Full control, can generate API keys.
- **`admin`**: Can manage operations and staff.
- **`staff`**: Can view transactions and perform daily operations.
- **`viewer`**: Read-only access.

### 2.3 Wallet Ownership Isolation
Wallets are now strictly bound to a `tenant_id`.
- **`owner_type`**: Defines if the wallet belongs to a `user`, `merchant`, or `system`.
- **`tenant_id`**: Ensures strict data isolation. A marketplace cannot see a merchant's wallet unless explicitly authorized.

### 2.4 Transaction Isolation
Every transaction in the `transactions` table is now tagged with a `tenant_id`. This guarantees that when a tenant queries their ledger, they only see their own financial movements, enforced at the database level via Row Level Security (RLS).

### 2.5 API Keys & Integration (`api_keys`)
Tenants (like Merchants and Partners) can generate API keys to integrate their external systems with the ORBI Financial Core.
- **`public_key`**: Used for client-side integrations (e.g., checkout forms).
- **`secret_key`**: Used for server-to-server API calls.

---

## 3. API Endpoints

All endpoints are protected and require a valid user session.

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/v1/core/tenants` | Create a new Tenant (Individual, Merchant, Marketplace, Partner). |
| `GET` | `/v1/core/tenants/my` | List all Tenants the current user has access to. |
| `POST` | `/v1/core/tenants/:id/api-keys` | Generate new API keys for a specific tenant. |
| `GET` | `/v1/core/tenants/:id/api-keys` | List all API keys for a specific tenant. |
| `DELETE` | `/v1/core/tenants/:id/api-keys/:keyId` | Revoke a specific API key. |
| `GET` | `/v1/core/tenants/:id/wallets` | List all wallets belonging to a specific tenant. |

---

## 4. Programmatic Access (External API)
Tenants can use their `secret_key` to access the ORBI platform programmatically without a user session. This is ideal for server-to-server integrations.

### 4.1 Authentication Header
All programmatic requests must include the `x-api-key` header:
```http
GET /v1/external/wallets
x-api-key: sk_live_...
```

### 4.2 External API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/v1/external/wallets` | Fetch all wallets belonging to the tenant associated with the API key. |

---

## 5. Security & Row Level Security (RLS)

The Financial Core Engine relies heavily on PostgreSQL RLS to ensure absolute data isolation:
1. **Tenant Visibility**: A user can only `SELECT` from `tenants` if their `user_id` exists in `tenant_users` for that tenant.
2. **API Key Security**: Only users with the `owner` or `admin` role in `tenant_users` can view or generate API keys.
3. **Ledger Isolation**: Transactions are strictly filtered by `tenant_id`.

---

## 7. Next-Generation Security Architecture (Titanium Hardened V26)

The ORBI Financial Core implements a 9-layer security pipeline designed to protect institutional assets and user data, achieving a true Zero-Trust model.

### Layer 1: Passkeys Authentication (WebAuthn)
**File**: `/backend/src/modules/passkey/passkey.service.ts`  
Replaces legacy passwords and OTPs with FIDO2-compliant Passkeys. Uses public-key cryptography to eliminate phishing and credential stuffing.

### Layer 2: Device Fingerprinting
**File**: `/backend/src/services/fingerprint.service.ts`  
Generates a unique SHA-256 hash based on hardware, OS, browser, and IP characteristics. Detects when a user logs in from an unrecognized or high-risk device.

### Layer 3: Behavioral Biometrics
**File**: `/backend/src/services/behavior.service.ts`  
Analyzes user interaction patterns (typing speed, swipe velocity, touch pressure). Calculates an anomaly score to detect bots or unauthorized human users even if they have the correct credentials.

### Layer 4: Deterministic Risk Scoring Engine
**File**: `/backend/src/services/risk.service.ts`  
Calculates a real-time **Risk Score (0-100)** for every request based on:
- **Velocity**: Too many transactions in a short window.
- **Location**: IP address mismatch or impossible travel speed (e.g., login from NY, then London 5 minutes later).
- **Amount**: Unusually large transaction volumes compared to historical data.

### Layer 5: AI Fraud Detection Engine
**File**: `/backend/src/modules/fraud/ai-fraud.service.ts`  
An ML inference pipeline (Isolation Forest / Gradient Boosting) that evaluates complex, non-linear features (login time, device age, behavioral patterns) to calculate an AI-driven risk score.

### Layer 6: Account Takeover (ATO) Detection
**File**: `/backend/src/services/fraud.service.ts`  
Correlates signals from Layers 2, 3, and 4 to detect Account Takeovers. Automatically freezes accounts or triggers step-up authentication if an ATO is suspected.

### Layer 7: Zero-Trust API Architecture
**File**: `/server.ts` & `/backend/src/middleware/session-monitor.middleware.ts`  
Every API request is authenticated, throttled by the WAF, and evaluated by the Risk Engine before reaching core business logic. No internal network trust is assumed.

### Layer 8: Hardware Security Modules (HSM) & Secure Enclave
**Files**: `/backend/src/modules/security/hsm.service.ts` & `/backend/src/modules/transaction/signing.service.ts`  
- **HSM**: Simulates secure hardware for generating RS256 JWT session tokens.
- **Secure Enclave**: Verifies cryptographic signatures generated by a mobile device's Secure Enclave (Apple) or Titan M chip (Android) before processing high-value transactions. Also verifies device integrity via Attestation Tokens (Play Integrity/DeviceCheck).

### Layer 9: Continuous Session Monitoring
**File**: `/backend/src/middleware/session-monitor.middleware.ts`  
Continuously monitors active sessions for drastic IP changes or device fingerprint alterations mid-session, invalidating compromised sessions in real-time.

---

## 8. Content Sanitization & WAF
**File**: `/backend/security/sanitizer.ts`  
Protects against XSS (Cross-Site Scripting) by deeply sanitizing all incoming JSON payloads. It strips malicious HTML/JS tags before they reach the database or business logic.

- **Input Analysis**: Malicious patterns detected by WAF.
- **Velocity Signals**: Request frequency from a specific IP.
- **Device Trust**: Verification of the client application origin.
- **AI Anomalies**: Behavioral insights from Sentinel AI.

**Enforcement Rules**:
- **0-60**: Allow request.
- **60-80**: Challenge (Requires Step-up verification/OTP).
- **80-100**: Hard Block.

### 8.1 Transaction Guard / Policy Engine
**File**: `/backend/ledger/PolicyEngine.ts`  
A financial control layer that enforces institutional rules before ledger execution:
- **Transaction Limits**: Maximum amount per single operation.
- **Daily Limits**: Cumulative spending/transfer limits per 24-hour window.
- **Velocity Guard**: Prevents rapid-fire transactions (e.g., max 50/hour).
- **Account Freeze**: Automatically places security holds on accounts violating policies.

### 7.4 Security Pipeline Flow
`Request` → `WAF` → `Sanitizer` → `Risk Engine` → `Auth` → `Policy Engine` → `Ledger`

---

## 8. Future Capabilities Unlocked
By implementing this architecture, ORBI is now capable of:
- **White-labeling**: Partners can launch their own branded wallets on our infrastructure.
- **Complex Marketplaces**: Platforms can onboard their own merchants, and ORBI handles the split-routing and settlement.
- **TrustBridge Escrow**: Marketplaces can use the conditional escrow system to protect buyers and sellers, holding funds in `PaySafe` until delivery is confirmed.
- **B2B SaaS**: Companies can use ORBI to manage their internal departmental budgets (Cost Centers as Tenants).

---

## 6. Settlement Engine
The Settlement Engine is responsible for moving funds from the ORBI platform to the tenant's external financial accounts (Bank, Mobile Money, etc.).

### 6.1 Settlement Lifecycle
1. **Transaction Completion**: A customer pays a tenant. The transaction is marked as `settlement_status = 'PENDING'`.
2. **Net Position Calculation**: The engine sums all pending credits and debits for the tenant.
3. **Payout Creation**: A `settlement_payouts` record is created, deducting platform fees.
4. **External Transfer**: The engine triggers an external transfer to the tenant's configured destination.
5. **Reconciliation**: Once the external transfer is confirmed, the payout is marked as `COMPLETED` and the linked transactions are marked as `SETTLED`.

### 6.2 Settlement API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/v1/core/tenants/:id/settlement/config` | Get bank/mobile money payout details. |
| `PATCH` | `/v1/core/tenants/:id/settlement/config` | Update payout destination and schedule. |
| `GET` | `/v1/core/tenants/:id/settlement/pending` | Get total amount waiting to be settled. |
| `POST` | `/v1/core/tenants/:id/settlement/payout` | Manually trigger a payout. |
| `GET` | `/v1/core/tenants/:id/settlement/history` | List all previous payout events. |
