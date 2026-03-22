# Multi-Tenant Merchant Architecture

**Classification**: INSTITUTIONAL / CORE ARCHITECTURE  
**Version**: 1.0.0  
**Last Updated**: 2026-03-11

---

## 1. Executive Summary
The **Multi-Tenant Merchant Architecture** allows any user on the platform to own and operate one or more merchant businesses. Instead of treating "Merchant" as a simple user role, the system treats a Merchant as a distinct entity linked to an owner. This enables advanced features like Marketplaces, Payment Gateways, and Business Accounts.

---

## 2. Core Entities

### 2.1 Merchants (`merchants` table)
The core entity representing a business.
- **`id`**: Unique UUID.
- **`business_name`**: The name of the business.
- **`owner_user_id`**: Links back to the `users` table. A single user can own multiple merchants.
- **`status`**: `pending`, `active`, `suspended`, `closed`.

### 2.2 Merchant Wallets (`merchant_wallets` table)
Each merchant has its own dedicated wallet(s) separate from the user's personal `wallets`.
- **`merchant_id`**: Links to the `merchants` table.
- **`balance`**: The current balance of the merchant.
- **`currency`**: Default is `TZS`.

### 2.3 Merchant Settlements (`merchant_settlements` table)
Configuration for how and when the merchant receives payouts.
- **`merchant_id`**: Links to the `merchants` table.
- **`bank_name`**: The destination bank.
- **`bank_account`**: The destination account number.
- **`settlement_schedule`**: `daily`, `weekly`, or `manual`.

### 2.4 Merchant Fees (`merchant_fees` table)
Custom fee configurations for each merchant.
- **`merchant_id`**: Links to the `merchants` table.
- **`transaction_fee_percent`**: Percentage fee per transaction (e.g., `0.01` for 1%).
- **`fixed_fee`**: A fixed flat fee per transaction.

---

## 3. API Endpoints

All endpoints are protected and require a valid user session.

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/v1/merchants/accounts` | Create a new Merchant Account. |
| `GET` | `/v1/merchants/accounts/my` | List all Merchant Accounts owned by the current user. |
| `GET` | `/v1/merchants/accounts/:id` | Get detailed information about a specific Merchant Account. |
| `PATCH` | `/v1/merchants/accounts/:id/settlement` | Update the settlement configuration (bank details, schedule). |

---

## 4. Transaction Flow (Future Implementation)

When a customer pays a merchant:
1. **Customer Wallet** -> `DEBIT`
2. **Payment Processor** -> Handles routing and fee calculation.
3. **Merchant Wallet** -> `CREDIT` (Pending or Available balance).
4. **Settlement Engine** -> Sweeps funds to the Merchant's Bank Account based on the `settlement_schedule`.
