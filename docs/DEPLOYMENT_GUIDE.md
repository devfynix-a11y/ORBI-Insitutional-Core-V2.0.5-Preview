# Production Deployment Guide (Render)

This guide details the steps to deploy the ORBI Sovereign Node to a production-ready environment on Render.

## 1. Prerequisites

*   **Render Account**: [Sign up here](https://render.com/).
*   **GitHub Repository**: Ensure this codebase is pushed to a private GitHub repository.
*   **Supabase Project**: A production Supabase project for the database.
*   **Redis Instance**: A managed Redis instance (e.g., Upstash or Render Redis).

## 2. Service Configuration

### 2.1 Web Service
Create a new **Web Service** on Render connected to your GitHub repository.

*   **Name**: `orbi-sovereign-node`
*   **Environment**: `Node`
*   **Build Command**: `npm install && npm run build`
*   **Start Command**: `npm start`
*   **Plan**: `Standard` or higher (recommended for production).

### 2.2 Environment Variables
Configure the following environment variables in the Render dashboard:

| Variable | Value | Description |
| :--- | :--- | :--- |
| `NODE_ENV` | `production` | Optimizes Express for performance. |
| `BACKEND_URL` | `https://orbi-financial-technologies-c0re-v2026.onrender.com` | The public URL of your Render service. |
| `APP_ID` | `OBI_INSTITUTIONAL_CORE_V25` | Internal App ID. |
| `SUPABASE_URL` | `https://your-project.supabase.co` | Your Supabase API URL. |
| `SUPABASE_ANON_KEY` | `your-anon-key` | Your Supabase Anon Key. |
| `KMS_MASTER_SALT` | `random-secure-string` | A long, random string for encryption. |
| `REDIS_CLUSTER_NODES` | `redis://user:pass@host:port` | Connection string for your Redis instance. |
| `API_KEY` | `your-gemini-api-key` | API Key for Google Gemini (Sentinel AI). |
| `ORBI_API_KEY` | `your-orbi-gateway-api-key` | API Key for ORBI SMS Gateway. |
| `ORBI_GATEWAY_URL` | `https://your-orbi-gateway-url.com` | Base URL for ORBI SMS Gateway. |
| `ORBI_ANDROID_APP_HASH` | `Base64 SHA-256 Hash` | **CRITICAL**: Official Android App signing certificate hash (Base64). |
| `ORBI_ANDROID_SMS_HASH` | `11-char string` | **CRITICAL**: Android SMS Retriever hash for auto-OTP reading. |
| `RP_ID` | `Canonical RP ID` | **CRITICAL**: Canonical Relying Party ID for Passkey operations. |
| `ORBI_WEB_ORIGIN` | `Canonical Origin` | **CRITICAL**: Canonical origin for web clients (e.g., `https://orbi.com`). |

## 3. Database Migration

1.  Connect to your production Supabase project.
2.  Open the SQL Editor.
3.  Run the contents of `database/schema_reset.sql` to initialize the schema.

## 4. Verification

After deployment, verify the service is healthy:

```bash
curl https://orbi-financial-technologies-c0re-v2026.onrender.com/health
```

You should receive:
```json
{
  "status": "active",
  "node": "DPS-PRIMARY-RELAY",
  "ledger": "VERIFIED"
}
```

## 5. Client Configuration

Update your client applications (Mobile/Web) to point to the new production URL:

*   **Flutter**: Update `_renderUrl` in `app_config.dart`.
*   **Web**: Update `BACKEND_URL` in your frontend configuration.

## 6. Servicing & Operations

### 6.1 Database Maintenance
*   **Backups**: Enable Point-in-Time Recovery (PITR) in the Supabase dashboard.
*   **Schema Updates**: Always test migrations on a staging project before applying to production.
*   **Indexing**: Monitor query performance and add indexes to columns used in `WHERE` clauses of frequently called endpoints.

### 6.2 User Support (Admin Panel)
*   **KYC Review**: Use the `POST /v1/admin/kyc/review` endpoint to process pending identity verifications.
*   **Account Freezing**: In case of reported fraud, use `PATCH /v1/admin/users/{id}/status` to set status to `frozen`. This immediately revokes all active sessions.
*   **Transaction Audits**: Use `GET /v1/admin/transactions/{id}/ledger` to view the full atomic breakdown of any disputed transaction.

## 7. Monitoring & Observability

### 7.1 Health Checks
The `/health` endpoint provides a real-time status of the system's core components:
*   **Node**: Current active relay.
*   **Ledger**: Verification status of the atomic engine.
*   **Sentinel**: Status of the AI security layer.

### 7.2 Logging
*   **Render Logs**: Monitor the "Logs" tab in the Render dashboard for application-level errors.
*   **Audit Logs**: All sensitive operations are recorded in the `audit_logs` table in Supabase. Use this for forensic investigations.

## 8. Sentinel AI Maintenance
*   **API Key**: Ensure the `API_KEY` (Gemini) remains valid. If the key expires, the Sentinel AI will default to a "Safe Mode" (blocking all high-risk operations).
*   **Risk Thresholds**: Adjust risk thresholds in the `security_rules` table to tune the sensitivity of the fraud detection engine.

---

**ORBI Infrastructure Team**
