# ORBI: The Sovereign Financial Operating System

**Version**: 30.0 (Titanium)  
**Status**: Production Hardened  
**Mission**: To build the trust layer for the African digital economy.
**Last Updated**: 2026-03-19

---

## 1. Philosophy

ORBI is not just a wallet; it is a **Sovereign Financial Node**. We believe that money should be:
1.  **Atomic**: Transactions either happen fully or not at all. No limbo states.
2.  **Intelligent**: Security should be proactive (Neural Sentinel), not reactive.
3.  **Sovereign**: Users own their data and their vaults.

## 2. The Architecture

### 2.1 The Atomic Ledger
Unlike traditional banks that use batch processing, ORBI uses a **Real-Time Atomic Ledger**. Every transaction is a multi-leg commit that instantly settles:
*   The Principal Amount
*   Government Taxes (VAT/Levies)
*   Platform Fees
*   Yield Generation

### 2.2 Transaction Integrity Protocol (TIP)
To ensure absolute user confidence and system security, all money movement follows the **TIP (Preview -> Confirm -> Lock -> Settle)** protocol. This is enforced via two distinct API endpoints:

1.  **Preview (`POST /v1/transactions/preview`)**: 
    *   **Purpose**: A high-fidelity simulation that calculates all fees, taxes, and verifies the recipient's identity before a single cent is moved.
    *   **Behavior**: This endpoint **always** returns the full fee breakdown and the user's `available_balance`, even if the user has insufficient funds. This allows the frontend to display exactly how much the user is short (e.g., "You are short 500 TZS") instead of a generic error.
    *   **Output**: Returns `fees`, `tax`, `total_amount`, and `available_balance`.

2.  **Confirm & Settle (`POST /v1/transactions/settle`)**: 
    *   **Purpose**: The user confirms the "Total Cost" breakdown. This endpoint executes the actual money movement.
    *   **Behavior**: It performs a final atomic check. If `total_amount > available_balance`, it throws a strict `400 Bad Request` with error code `INSUFFICIENT_FUNDS`.
    *   **Process**: Funds are atomically moved to a secure internal escrow (PaySafe), preventing double-spending, before being finalized to the recipient. Stuck transactions are auto-reversed by the background reaper.

### 2.3 Neural Sentinel AI
Our security layer is an active AI participant. It evaluates 200+ risk vectors in <50ms for every request. It doesn't just block fraud; it learns from it.

### 2.3 Zero-Trust Identity
We assume every connection is a potential threat until proven otherwise. This **Dynamic Identity Quarantine (DIQ)** model ensures that the integrity of the sovereign cluster is never compromised.

### 2.4 Distributed Resilience
The system is designed to survive regional infrastructure failures. By utilizing **Circuit Breakers** and **Autonomous Failover**, a Sovereign Node can continue processing internal transactions even if external banking gateways are offline.

---

## 3. Business Model

ORBI operates on a transparent, automated revenue model:
*   **Transaction Fees**: A small percentage of peer-to-peer transfers.
*   **Merchant Processing**: Tools for businesses to accept payments.
*   **Yield Generation**: Safe, automated yield on idle vault balances.

## 4. Identity & Compliance

ORBI adheres to global banking standards:
*   **KYC/AML**: Multi-tiered identity verification (Level 0-3).
*   **Sanctions Screening**: Real-time checks against global watchlists.
*   **Audit Trails**: Immutable logs for every action.

---

## 5. For Developers

We have built ORBI to be the platform *we* wanted to use.

### 5.1 Core Development Principles
1.  **Stateless Clients**: The App should be a "dumb" window into the Sovereign Node. All logic, validation, and security happen on the backend.
2.  **Idempotency First**: Every mutation request from the App **MUST** include a unique `x-idempotency-key`. This prevents double-charging in poor network conditions.
3.  **Secure by Design**: Never store sensitive data (balances, keys) in the App's persistent storage.

### 5.2 Key Integration Resources
*   **Master Manual**: `INTEGRATION_MANUAL.md` - Full API specification.
*   **Mobile Guide**: `MOBILE_SDK_GUIDE.md` - Flutter/Native integration.
*   **Deployment**: `DEPLOYMENT_GUIDE.md` - Production setup and servicing.
*   **Quick Start**: `INTEGRATION_GUIDE.md` - 5-minute onboarding.

---

## 6. Database & Security Architecture

### 6.1 The SQL Format: PostgreSQL
ORBI is built on **PostgreSQL**, the world's most advanced open-source relational database. We use it for its:
*   **ACID Compliance**: Ensuring our "Atomic Ledger" philosophy is mathematically guaranteed.
*   **JSONB Support**: Allowing flexible metadata storage for complex transaction legs.
*   **Extensions**: Utilizing `pgcrypto` for encryption and `uuid-ossp` for unique identifiers.

### 6.2 The Service: Supabase
We leverage **Supabase** as our database engine, providing:
*   **Managed Infrastructure**: Automated backups, scaling, and high availability.
*   **Realtime Subscriptions**: Pushing ledger updates to clients via WebSockets.
*   **Integrated Auth**: Seamlessly linking database users to JWT authentication.

### 6.3 Security Configuration: The "Zero-Trust" Table Model
Every table in ORBI follows a strict security configuration. We do not rely on application-level logic alone; security is enforced at the database kernel level using **Row Level Security (RLS)**.

#### Example: The `transactions` Table
To ensure a table is "well configured," it must meet the following criteria (as seen in our `transactions` table):

1.  **RLS Enabled**: `ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;`
    *   *Effect*: By default, no one (not even logged-in users) can see or touch data. Access is "deny by default."

2.  **Granular Policies**:
    *   **View Policy**: `CREATE POLICY "Users view own transactions" ON public.transactions FOR SELECT USING (auth.uid() = user_id);`
        *   *Logic*: A user can *only* see rows where the `user_id` column matches their authenticated ID.
    *   **Insert Policy**: `CREATE POLICY "Users create transactions" ON public.transactions FOR INSERT WITH CHECK (auth.uid() = user_id);`
        *   *Logic*: A user can *only* insert a row if they are assigning it to themselves. They cannot create a transaction for someone else.

3.  **Performance Indexes**:
    *   `CREATE INDEX idx_tx_user_date ON public.transactions(user_id, date);`
    *   *Purpose*: Ensures that security checks (filtering by `user_id`) remain fast even with millions of records.

This configuration ensures that even if an attacker bypasses the API layer, the database itself will reject unauthorized access.

---

## 7. Generic REST Integration

ORBI supports a **Dynamic Provider Engine** that allows you to onboard new financial partners (Banks, Mobile Money, Crypto Gateways) without writing new code. This is handled via the `GenericRestProvider` service.

### 7.1 The Concept
Instead of hardcoding API calls in TypeScript, you define the API contract in the database using JSON. The `financial_partners` table has a `mapping_config` column that stores this logic.

### 7.2 Configuration Format (`mapping_config`)

You can configure a partner in two modes: **Single Endpoint** (Simple) or **Multi-Endpoint** (Advanced).

#### A. Single Endpoint Mode
Best for simple webhooks or notification services.

```json
{
  "endpoint": "https://api.partner.com/v1/notify",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{partner.connection_secret}}",
    "Content-Type": "application/json"
  },
  "payload_template": {
    "amount": "{{amount}}",
    "currency": "KES",
    "reference": "{{reference}}",
    "customer": {
      "phone": "{{phone}}"
    }
  }
}
```

#### B. Multi-Endpoint Mode
Required for full payment providers (STK Push, Disbursements, Status Checks).

```json
{
  "stk_push": {
    "url": "https://api.partner.com/v2/collect",
    "method": "POST",
    "headers": {
      "X-API-Key": "{{partner.connection_secret}}"
    },
    "payload_template": {
      "action": "debit",
      "amount": "{{amount}}",
      "msisdn": "{{phone}}",
      "callback_url": "https://api.orbi.io/callbacks/generic"
    },
    "response_mapping": {
      "id_field": "data.transaction_id",
      "status_field": "data.status"
    }
  },
  "disbursement": {
    "url": "https://api.partner.com/v2/payout",
    "method": "POST",
    "headers": { ... },
    "payload_template": { ... }
  }
}
```

### 7.3 Templating Engine
The engine supports dynamic variable injection using `{{ variable_name }}` syntax.

**Available Context Variables:**
*   `{{amount}}`: Transaction amount
*   `{{phone}}`: Customer phone number
*   `{{reference}}`: Internal transaction reference
*   `{{partner.connection_secret}}`: The secure API key stored in the partner record
*   `{{partner.client_id}}`: The partner's client ID

### 7.4 Response Mapping
To ensure the system understands the partner's response, use `response_mapping`:

*   `id_field`: JSON path to the partner's transaction ID (e.g., `data.id` or `transactionId`).
*   `status_field`: JSON path to the status (e.g., `status` or `data.state`).

---


---

## 8. Fee Management

ORBI implements a robust, automated fee collection system to ensure compliance and platform sustainability.

### 8.1 Fee Collector Wallets
All platform fees (e.g., Government Tax, Service Fees) are routed to dedicated internal wallets defined in the `fee_collector_wallets` table. This provides a clear audit trail and simplifies reconciliation.

### 8.2 Admin Fee API
Authorized staff can access fee transaction data via the Admin API:
*   **`GET /api/admin/fees`**: Retrieves all ledger entries associated with fee collector wallets. Supports optional filtering by `feeType` (e.g., `GOV_TAX`, `SERVICE_FEE`).
*   **`GET /api/admin/balances`**: Aggregates total system-wide balances for specific wallet types (e.g., 'DilPesa', 'PaySafe').
*   **`GET /api/admin/metrics/daily-movements`**: Retrieves daily net asset movements (CREDIT - DEBIT) grouped by category. Requires `startDate` and `endDate` query parameters (ISO format).

---

## 9. Messaging & Notifications Configuration

ORBI uses a dual-provider architecture for notifications: the custom ORBI Gateway for SMS and Brevo for Email.

### 9.1 ORBI Gateway Setup (SMS)
The ORBI Gateway handles automated SMS messages (OTP, transaction confirmations, security alerts) using predefined templates. It supports language preferences (English `en` and Swahili `sw`).

> **Note:** For a complete list of all message templates and their required variables, please refer to the [ORBI Gateway Message Templates](./GATEWAY_TEMPLATES.md) documentation.

**Environment Variables:**
```env
ORBI_API_KEY=your_orbi_gateway_api_key_here
ORBI_GATEWAY_URL=https://your-orbi-gateway-url.com
```

**Usage:**
```typescript
import { orbiGatewayService } from './backend/infrastructure/orbiGatewayService.js';

// Send a template message
await orbiGatewayService.sendTemplate(
    'Transfer_Received', 
    '+255700000000', 
    { amount: '50,000', currency: 'TZS', sender: 'John Doe' },
    { language: 'sw', messageType: 'transactional' }
);
```

### 9.2 Brevo Setup (Email)
ORBI uses the Brevo API to send automated emails (OTP, confirmations, etc.).

1.  **Create an Account**: Sign up for a Brevo account at brevo.com.
2.  **Generate API Key**: Go to your Brevo account settings -> SMTP & API -> API Keys and generate a new v3 API key.

**Environment Variables:**
```env
SMTP_FROM_NAME="Orbi Support"
SMTP_FROM_EMAIL="support@orbi.io"
```

**Usage:**
```typescript
import { emailService } from './backend/infrastructure/emailService.js';

await emailService.sendEmail({
    to: 'user@example.com',
    subject: 'Verification Code',
    text: 'Your code is 123456'
});
```

---

## 10. User Preferences & AI Messaging

ORBI provides a highly personalized experience through its AI-powered messaging system, which respects user-defined preferences for language and notification categories.

### 10.1 Language Preferences
Users can choose their preferred language (currently supporting English `en` and Swahili `sw`). This setting is used by:
*   **Orbi AI Agent**: The chat interface automatically responds in the user's preferred language.
*   **System Alerts**: Transaction notifications, security alerts, and welcome messages are translated based on this setting.

### 10.2 Notification Categories
To prevent notification fatigue, ORBI allows users to toggle alerts for specific categories:
*   **Security (`notif_security`)**: Critical alerts like new device logins or password changes. (Default: ON)
*   **Financial (`notif_financial`)**: Real-time transaction receipts and payment confirmations. (Default: ON)
*   **Budget (`notif_budget`)**: Alerts when spending reaches pre-defined limits. (Default: ON)
*   **Marketing (`notif_marketing`)**: Promotional offers and platform updates. (Default: OFF)

### 10.3 AI-Powered Contextual Alerts
The **MessagingService** uses Gemini AI to generate human-readable, friendly alerts. These alerts are:
1.  **Context-Aware**: They explain *why* an alert was triggered (e.g., "You spent more than usual on groceries today").
2.  **Preference-Respecting**: The system checks the user's notification toggles before dispatching any message via In-App, SMS, or Email.

---

## 11. Budgets & Goals

ORBI integrates financial planning directly into the ledger.

### 11.1 Budgets: Hard Enforcement
Unlike other apps that just send alerts, ORBI can physically block transactions that exceed a budget.
*   **Soft Limit**: Sends a warning notification at 80% and 100% usage.
*   **Hard Limit**: The ledger rejects the transaction if the budget is exceeded, ensuring strict fiscal discipline for departments or individuals.

### 11.2 Goals: Treasury Auto-Sweep
Goals are not just piggy banks; they are automated treasury nodes.
*   **Auto-Sweep**: Organizations can set a threshold for their operating vaults. Any funds exceeding this threshold are automatically "swept" into a designated goal (e.g., "Tax Reserve" or "Expansion Fund").
*   **Multi-Sig Treasury**: Large withdrawals from enterprise vaults require multiple approvals (e.g., CFO + CEO) before the ledger releases the funds.
*   **Atomic Allocation**: Moving money to a goal is a multi-leg ledger transaction, ensuring the money is always accounted for.

---

### 12. Orbi TrustBridge (Secure Escrow)
The **TrustBridge** allows users to send payments that are held in a secure escrow (`PaySafe`) until specific conditions are met (e.g., item received).

*   **Locking**: Funds are moved to PaySafe and marked as `authorized`.
*   **Releasing**: The sender confirms receipt, and funds move to the recipient.
*   **Disputing**: If the item isn't as described, the user can dispute the escrow, freezing the funds for review.
*   **AI Dispute Resolution**: Neural Sentinel AI analyzes dispute evidence (chat logs, photos, tracking IDs) to provide a resolution recommendation to human auditors.

---

## 12. Operational Guides
For detailed information on platform mechanics, external integrations, and investor transparency, refer to:
*   **[ORBI Operational Architecture & Ecosystem Guide](./ORBI_OPERATION.md)**

---

## 13. Infrastructure & Background Processing (Firebase Broker)

ORBI utilizes a distributed **Firebase Broker** system to handle heavy asynchronous tasks and ensure high availability across cloud environments (e.g., Render).

### 13.1 Distributed Task Processing
Heavy operations are offloaded from the main API thread to specialized worker nodes via Firestore:
*   **AI Report Generation**: Background forensic analysis for KYC and disputes.
*   **Tax & Fee Settlements**: Complex multi-leg calculations for large batches.
*   **Notification Fanout**: Mass delivery of alerts across SMS, Email, and Push.
*   **Treasury Auto-Sweep**: Automated liquidity management for enterprise goals.

### 13.2 Node Heartbeat & Monitoring
To ensure the integrity of the distributed cluster, every node maintains a dual-layer heartbeat:
1.  **Presence Heartbeat**: Nodes update their `lastSeen` status in Firestore every 60 seconds. The `isRecent()` security rule ensures only healthy nodes can claim tasks.
2.  **System Heartbeat (Keep-Alive)**: Nodes ping the main application's `/health` endpoint every minute to prevent "sleeping" on serverless platforms like Render.

### 13.3 Health Telemetry
The main application provides real-time visibility into the broker's status:
*   **`GET /api/broker/health`**: Returns the operational status of the background processing cluster, including node IDs, initialization state, and latency.
*   **Stale Detection**: If a broker node fails to report for more than 2 minutes, the system marks it as `STALE` and triggers an infrastructure alert.

---

**ORBI Financial Technologies Ltd.**  
*Building the Future of Money.*
