# ORBI Sovereign Node: Quick Start Guide (v31.0)
**Version**: 31.0.0-stable  
**Last Updated**: 2026-03-22

**Welcome to ORBI.** This guide will get you connected to the Sovereign Backend in under 5 minutes.

---

## 1. The Basics

*   **Base URL**: `https://orbi-financial-technologies-c0re-v2026.onrender.com`
*   **Auth Type**: Bearer Token (JWT)
*   **Content-Type**: `application/json`
*   **Mandatory Headers**: `x-orbi-app-id`, `x-orbi-app-origin`, `x-orbi-apk-hash` (for Android)

## 2. Your First Request (Health Check)

Verify the node is online and the Neural Sentinel is active.

```bash
curl -X GET https://orbi-financial-technologies-c0re-v2026.onrender.com/health
```
**Response**:
```json
{
  "status": "active",
  "node": "DPS-PRIMARY-RELAY",
  "ledger": "VERIFIED"
}
```

---

## 3. Core Workflow

### Step 1: Create an Identity
Send a POST request to `/v1/auth/signup`.
*   **Tip**: Omit `customer_id` to let the system generate a unique `OBIX-XXXX-XXXX` (where XX is the current year) for you.
*   **Tip**: Provide `full_name` and `phone` to pass initial KYC checks.

### Step 2: Login & Get Token
Send a POST request to `/v1/auth/login`.
*   **Save the Token**: The `access_token` in the response is your key to the kingdom. Include it in the `Authorization` header for all subsequent requests.

### Step 2.1: Set Preferences (Language & Notifs)
Customize your experience via `PATCH /v1/user/profile`.
*   **Payload**: `{ "language": "sw", "notif_marketing": true }`
*   **Effect**: Changes the language for AI chat and system alerts, and toggles notification categories.

### Step 2.5: Secure with Biometrics (Optional)
Send a POST request to `/v1/auth/passkey/register/start`.
*   **Single Device Policy**: If you switch devices, you'll need to verify an OTP sent to your phone.
*   **Login**: Use `/v1/auth/passkey/login/start` for passwordless access.

### Step 2.6: Identity Verification (KYC)
To unlock full features, verify your identity:
1.  **Scan ID**: `POST /v1/user/kyc/scan` with raw image binary to extract details via AI.
2.  **Upload Docs**: `POST /v1/user/kyc/upload` with raw image binary to get a secure storage URL.
3.  **Submit**: `POST /v1/user/kyc` with extracted details and document URLs.

### Step 3: Check Your Vault
Send a GET request to `/v1/wallets`.
*   You will see your **Genesis Vault** (created automatically) and its current balance.

### Step 4: Preview Transaction (Pre-Flight)
Before sending money, call `POST /v1/transactions/preview`.
*   **Why?**: This verifies the recipient's name and shows you the exact fee breakdown before you commit.

### Step 5: Send Money (Enterprise Payment Processor)
Send a POST request to `/v1/transactions/settle`.

*   **Endpoint**: `POST /v1/transactions/settle`
*   **Headers**:
    *   `Authorization`: `Bearer <TOKEN>`
    *   `x-idempotency-key`: `<UUID>` (Required for network safety)
*   **Smart Resolution**: You can identify recipients by:
    *   `recipient_customer_id`: The unique Orbi ID (e.g., `OB25-8839-1029`)
    *   `recipientId`: The internal User UUID (if known)
    *   **Note**: The system automatically resolves the target wallet.
*   **Cross-Currency Support**: If the recipient's wallet uses a different currency than the source, the system automatically performs a conversion using the **FX Engine**.
    *   **FX Fee**: A platform fee (0.5%) is applied to the converted amount.
    *   **Transparency**: The `breakdown` in the response will include `fx_fee`, `exchange_rate`, and `converted_amount`.
*   **Source Defaulting**: If `sourceWalletId` is omitted, funds are drawn from your **OPERATING** vault.
*   **Sub-Wallets**: To pay from a specific container (e.g., a Goal), set `walletType: "GOAL"` and provide the goal's UUID in `sourceWalletId`.

#### Payload Example
```json
{
  "amount": 5000,
  "currency": "TZS",
  "type": "INTERNAL_TRANSFER",
  "recipient_customer_id": "OB25-8839-1029", 
  "description": "Lunch payment",
  "walletType": "internal_vault",
  "metadata": {
    "category": "Food",
    "notes": "Team lunch"
  }
}
```

### Step 5: Messaging (Admin Only)
Send a POST request to `/v1/messaging/email`.
*   **Requires**: `ADMIN` or `SUPER_ADMIN` role.
*   **Payload**: `{ "to": "user@example.com", "subject": "Hello", "text": "Welcome to Orbi" }`
*   **Note**: All messaging is handled via the internal **ORBI Gateway**.

### Step 6: Admin Partner Registry API
Manage external payment providers dynamically without code changes.
*   **Requires**: `ADMIN`, `SUPER_ADMIN`, or `IT` role.
*   **Base Endpoint**: `/api/admin/partners`
*   **Alerts**: The system automatically sends alerts via the **ORBI Gateway** to the `ADMIN_ALERT_EMAIL` and `ADMIN_ALERT_PHONE` (configured in environment) when a reconciliation discrepancy is detected between internal vaults and external partners.

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/admin/partners` | List all registered financial partners. |
| `POST` | `/api/admin/partners` | Register a new partner. |
| `PUT` | `/api/admin/partners/:id` | Update an existing partner's configuration. |
| `DELETE` | `/api/admin/partners/:id` | Remove a partner from the registry. |

*   **Configuration**: The `mapping_config` field in the request body should be a JSON object defining the API contract (e.g., `stk_push`, `disbursement`, `balance` endpoints).

### Building the Admin UI for Partner Connection
To build a UI for managing these connections:
1.  **Dashboard**: Create a table listing partners from `GET /api/admin/partners`.
2.  **Add/Edit Form**: Create a form with fields for `name`, `client_id`, `client_secret` (encrypted by `DataVault` on backend), and a JSON editor for `mapping_config`.
3.  **Real-time Monitoring**:
    *   **Alerts**: Connect to the `/nexus-stream` WebSocket and listen for `ALERT` type messages to display real-time notifications for reconciliation discrepancies.
    *   **Activity Logs**: Listen for `AUDIT_LOG` type messages on the same WebSocket to display a real-time feed of all backend activity.
4.  **Connection Status**: Use the `GET /health` endpoint or a dedicated recon endpoint to show the current sync status of each partner.
5.  **Investigation**: Ensure your Admin UI has a section to display recent reconciliation audit logs (`item_reconciliation_audit` table) to help admins investigate discrepancies.

### Step 7: Connect Financial Partners (Webhooks)
To receive payments from M-Pesa or Airtel, you must register them in the database and configure the webhook URL.
*   **SQL**: Insert into `financial_partners` table.
*   **URL**: `https://<APP_URL>/v1/webhooks/<PARTNER_UUID>`
*   **Details**: See **Section 9** of the `INTEGRATION_MANUAL.md`.

### Step 8: TrustBridge Escrow (Secure Payments)
Protect your peer-to-peer payments using conditional escrow.
1.  **Create Escrow**: `POST /v1/escrow/create` with `amount`, `recipient_customer_id`, and `conditions`.
2.  **Release Funds**: `POST /v1/escrow/{ref}/release` once the service/item is received.
3.  **Dispute**: `POST /v1/escrow/{ref}/dispute` if there's an issue. AI will analyze evidence.

### Step 9: Enterprise Treasury (Multi-Sig)
For organizations, manage large movements with multi-signature security.
1.  **Request Withdrawal**: `POST /v1/enterprise/treasury/withdraw/request`.
2.  **Approve**: Other authorized admins call `POST /v1/enterprise/treasury/withdraw/approve`.
3.  **Monitor**: `GET /v1/enterprise/treasury/approvals` to see pending actions.

---

## 4. Key Concepts

### 🛡️ Sentinel AI
The security engine watches everything.
*   **Don't spam requests**: You'll get blocked (429/403).
*   **Don't switch IPs rapidly**: You'll get flagged.

### ⚡ Nexus Stream (WebSockets)
Don't poll for balance updates. Connect to `/nexus-stream` and listen for `SETTLEMENT_CONFIRMED` events.

### 🆔 Zero-Trust Identity
Your account starts as `pending`. You can transact, but high-value operations may require further KYC verification (Identity Quarantine).

---

## 5. AI Assistant & Insights

### Step 1: Chatbot Integration
The Orbi AI Assistant provides personalized support for payments, savings, and corporate services.
*   **Endpoint**: `POST /api/v1/chat`
*   **Headers**: `Authorization: Bearer <TOKEN>`, `Content-Type: multipart/form-data`
*   **Payload**: 
    *   `message`: (string) Your query.
    *   `document`: (optional, file) Image or document to analyze for platform issues.
*   **Automatic Greeting**: Send `{ "message": "init" }` on chat UI mount to trigger a personalized welcome greeting that includes time-of-day, user name, and recent activity or account status.
*   **Document Analysis**: If a document is uploaded, the AI will analyze it specifically for issues related to the Orbi Platform using the internal knowledge base.

### Step 2: Financial Insights Widget
Proactively display personalized financial advice based on user behavior.
*   **Endpoint**: `GET /api/v1/insights`
*   **Headers**: `Authorization: Bearer <TOKEN>`
*   **Response Structure**:
```json
{
  "spendingAlerts": ["string", ...],
  "budgetSuggestions": ["string", ...],
  "financialAdvice": ["string", ...]
}
```

### Step 3: Receipt-to-Payment (AI Scanning)
Streamline payments by scanning receipts to automatically extract transaction details.
*   **Endpoint**: `POST /api/v1/receipt/scan`
*   **Headers**: `Authorization: Bearer <TOKEN>`, `Content-Type: multipart/form-data`
*   **Payload**: `receipt` (image file)
*   **Response Structure**:
```json
{
  "merchant": "string",
  "amount": "number",
  "currency": "string",
  "date": "string"
}
```
*   **Workflow**:
    1.  Upload receipt image via `multipart/form-data`.
    2.  Backend extracts data using `gemini-3.1-flash-image-preview`.
    3.  Frontend displays extracted data for user confirmation.
    4.  Frontend calls `/v1/transactions/settle` with confirmed data.

---

**Need Help?**
Refer to the **Master Integration Manual** (`INTEGRATION_MANUAL.md`) for deep technical details.
