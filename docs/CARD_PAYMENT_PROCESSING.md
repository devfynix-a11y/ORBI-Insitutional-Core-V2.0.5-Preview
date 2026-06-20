# Card Payment Processing System (V2.0)

## Overview

The **Card Payment Processor** is a PCI-DSS compliant payment card processing system that provides secure tokenization, authorization, settlement, and fraud prevention for the ORBI platform. This system handles end-to-end card payment workflows with enterprise-grade security and double-entry ledger accounting.

**Key Features:**

- ✅ Secure card tokenization and storage
- ✅ PCI-DSS compliance with AES encryption
- ✅ 3D-Secure ready authorization
- ✅ Fraud risk assessment and prevention
- ✅ Double-entry ledger settlement
- ✅ Comprehensive audit logging
- ✅ Card brand detection (VISA, MASTERCARD, AMEX, DISCOVERY)
- ✅ Refund processing
- ✅ Multi-wallet support

---

## System Architecture

### Processing Flow

```
Card Input
    ↓
Validation (Luhn Check)
    ↓
Brand Detection (BIN)
    ↓
Encryption (AES - PCI-DSS)
    ↓
Tokenization & Storage
    ↓
Authorization Request
    ↓
Fraud Assessment (Risk Engine)
    ↓
Transaction Recording
    ↓
Settlement (Double-Entry Ledger)
    ↓
Audit Logging
```

### Data Security

- **Card Storage:** AES encryption using `DataVault.encrypt()`
- **Sensitive Fields:** Card number and CVV encrypted before storage
- **Fingerprinting:** SHA-256 hashing for fraud detection
- **Audit Trail:** All financial operations logged via `Audit.log()`
- **Compliance:** PCI-DSS Level 3 standards

---

## API Reference

### Core Interfaces

#### `CardTokenRequest`

Request payload for tokenizing a new card.

```typescript
interface CardTokenRequest {
  cardNumber: string;           // Full card number (validated with Luhn)
  expiryMonth: number;          // 1-12
  expiryYear: number;           // 4-digit year
  cvv: string;                  // 3-4 digit security code
  cardholderName: string;       // Cardholder's full name
  billingAddress?: {            // Optional billing address
    street: string;
    city: string;
    state: string;
    postalCode: string;
    country: string;
  };
}
```

#### `CardToken`

Stored card token representation.

```typescript
interface CardToken {
  id: string;                    // Unique token ID (ct_*)
  userId: string;               // Owner user ID
  maskedCardNumber: string;      // Format: ****-****-****-XXXX
  tokenizedCardNumber: string;   // AES encrypted card number
  expiryMonth: number;
  expiryYear: number;
  cardholderName: string;
  cardBrand: 'VISA' | 'MASTERCARD' | 'AMEX' | 'DISCOVERY';
  cardType: 'CREDIT' | 'DEBIT';
  last4Digits: string;           // Last 4 digits for display
  fingerprint: string;           // SHA-256 hash for fraud detection
  isDefault: boolean;            // Use as default payment method
  status: 'ACTIVE' | 'INACTIVE' | 'EXPIRED';
  createdAt: string;             // ISO 8601 timestamp
  expiresAt: string;             // Card expiry date
  metadata?: any;                // Custom metadata
}
```

#### `CardPaymentRequest`

Request payload for card payment authorization.

```typescript
interface CardPaymentRequest {
  cardTokenId: string;           // Reference to stored card token
  amount: number;                // Transaction amount in cents
  currency: string;              // ISO 4217 code (e.g., "USD")
  description: string;           // Transaction description
  sourceWalletId: string;        // Source wallet for debit
  targetWalletId: string;        // Target wallet for credit
  merchantId?: string;           // Optional merchant identifier
  categoryId?: string;           // Optional transaction category
  cvv?: string;                  // Optional CVV for additional auth
  billingZipCode?: string;       // Optional for AVS verification
  metadata?: any;                // Custom metadata
}
```

#### `CardTransaction`

Recorded card transaction.

```typescript
interface CardTransaction {
  id: string;                    // Unique transaction ID (ctxn_*)
  cardTokenId: string;           // Reference to card token
  userId: string;                // Transaction user
  merchantId?: string;
  amount: number;                // Transaction amount
  currency: string;
  status: 'PENDING' | 'AUTHORIZED' | 'SETTLED' | 'FAILED' | 'DECLINED' | 'REVERSED';
  authorizationCode?: string;    // Auth approval code
  rrn?: string;                  // Retrieval Reference Number
  stanNumber?: string;           // System Trace Audit Number
  responseCode?: string;         // Payment processor response code
  responseMessage?: string;
  riskScore?: number;            // Fraud risk score (0-100)
  fraudFlags?: string[];         // Associated fraud signals
  createdAt: string;
  updatedAt: string;
  settledAt?: string;           // Settlement completion time
  metadata?: any;
}
```

---

## Methods

### `tokenizeCard(userId: string, cardRequest: CardTokenRequest): Promise<CardToken>`

Securely tokenizes a payment card for future use.

**Parameters:**

- `userId` - User ID owning the card
- `cardRequest` - Card details in `CardTokenRequest` format

**Process:**

1. Validates card number using Luhn algorithm
2. Detects card brand from BIN patterns
3. Generates card fingerprint (SHA-256)
4. Encrypts sensitive data (card number, CVV)
5. Stores card token in database
6. Creates audit log entry

**Returns:** `CardToken` object with tokenized card data

**Throws:**

- `"Invalid card number (Luhn check failed)"` - If card fails validation
- `"Card tokenization failed: ${error}"` - If database insert fails

**Example:**

```typescript
const token = await cardProcessor.tokenizeCard(userId, {
  cardNumber: "4532015112830366",
  expiryMonth: 12,
  expiryYear: 2026,
  cvv: "123",
  cardholderName: "John Doe",
  billingAddress: {
    street: "123 Main St",
    city: "San Francisco",
    state: "CA",
    postalCode: "94102",
    country: "US"
  }
});
```

---

### `authorizeCardPayment(userId: string, paymentRequest: CardPaymentRequest): Promise<CardTransaction>`

Authorizes a card payment with risk assessment.

**Parameters:**

- `userId` - User initiating payment
- `paymentRequest` - Payment details in `CardPaymentRequest` format

**Process:**

1. Retrieves stored card token
2. Verifies card hasn't expired
3. Performs fraud risk assessment (RiskEngine)
4. Blocks if risk score > 85
5. Simulates/calls payment processor authorization
6. Records transaction with authorization codes
7. Generates STAN and RRN numbers
8. Creates audit log

**Returns:** `CardTransaction` object with authorization status

**Throws:**

- `"Card token not found or inactive"`
- `"Card has expired"`
- `"Database connection required"`

**Transaction Status:**

- `AUTHORIZED` - Authorization successful
- `DECLINED` - Authorization failed
- `BLOCKED_BY_FRAUD_ENGINE` - Fraud risk too high

**Example:**

```typescript
const transaction = await cardProcessor.authorizeCardPayment(userId, {
  cardTokenId: token.id,
  amount: 50000,        // $500.00
  currency: "USD",
  description: "Purchase - Electronics",
  sourceWalletId: merchant.walletId,
  targetWalletId: user.walletId,
  merchantId: "merchant_123",
  metadata: { orderId: "order_456" }
});
```

---

### `settleCardPayment(cardTransactionId: string, userId: string, sourceWalletId: string, targetWalletId: string): Promise<SettlementResult>`

Settles an authorized card payment using double-entry ledger accounting.

**Parameters:**

- `cardTransactionId` - Transaction ID to settle
- `userId` - User owning the transaction
- `sourceWalletId` - Source wallet ID (debit account)
- `targetWalletId` - Target wallet ID (credit account)

**Settlement Process:**

1. **Retrieve Transaction** - Fetches authorized card transaction
2. **Validate Wallets** - Verifies both wallets exist and are accessible
3. **Calculate Amounts:**
   - Transaction Amount: Full payment amount
   - Platform Fee: 1% automatically deducted
   - Total: Transaction + Fee
4. **Double-Entry Ledger Creation:**
   - **Leg 1 (DEBIT):** Debit from source wallet
   - **Leg 2 (CREDIT):** Credit to target wallet
   - **Leg 3 (CREDIT):** Platform fee to system fee wallet
5. **Financial Transaction Record:**
   - Creates transaction record in financial ledger
   - Stores card metadata (RRN, STAN, auth code)
   - Sets idempotency key for duplicate prevention
6. **Atomic Ledger Commit:**
   - Inserts all three ledger entries
   - Updates wallet balances
   - Marks card transaction as SETTLED
   - Updates financial transaction status
7. **Audit Logging** - Records complete settlement activity

**Returns:** Settlement completion object

```typescript
{
  success: true;
  cardTxId: string;            // Original card transaction ID
  financialTxId: string;       // New financial transaction ID
  status: "SETTLED";
  amount: number;              // Amount transferred
  fee: number;                 // Platform fee charged
  totalSettled: number;        // Total amount (amount + fee)
  targetWalletNewBalance: number;
  settledAt: string;           // ISO timestamp
}
```

**Throws:**

- `"Card transaction not found"`
- `"Only authorized transactions can be settled"`
- `"Target wallet not found or unauthorized"`
- `"Failed to create financial transaction: ${error}"`
- `"Failed to create ledger entry: ${error}"`

**Example:**

```typescript
const settlement = await cardProcessor.settleCardPayment(
  transaction.id,
  userId,
  merchantWalletId,
  userWalletId
);

console.log(`Settled: ${settlement.amount} + ${settlement.fee} fee`);
console.log(`New balance: ${settlement.targetWalletNewBalance}`);
```

---

### `refundCardPayment(cardTransactionId: string, userId: string, reason?: string): Promise<RefundResult>`

Processes a full or partial refund for a settled or authorized transaction.

**Parameters:**

- `cardTransactionId` - Transaction to refund
- `userId` - User requesting refund
- `reason` - Optional refund reason

**Process:**

1. Retrieves original transaction
2. Validates transaction is SETTLED or AUTHORIZED
3. Creates negative amount record (refund)
4. Marks as SETTLED immediately
5. Logs refund activity

**Returns:**

```typescript
{
  success: true;
  refundId: string;           // New refund transaction ID
  originalAmount: number;
}
```

**Throws:**

- `"Original transaction not found"`
- `"Only settled or authorized transactions can be refunded"`

**Example:**

```typescript
const refund = await cardProcessor.refundCardPayment(
  transaction.id,
  userId,
  "Customer requested refund"
);
```

---

### `listCardTokens(userId: string): Promise<CardToken[]>`

Lists all active card tokens for a user.

**Parameters:**

- `userId` - User ID

**Returns:** Array of `CardToken` objects (ACTIVE status only)

**Example:**

```typescript
const cards = await cardProcessor.listCardTokens(userId);
cards.forEach(card => {
  console.log(`${card.cardBrand}: ${card.maskedCardNumber}`);
});
```

---

### `deleteCardToken(tokenId: string, userId: string): Promise<void>`

Soft-deletes a card token by marking it as INACTIVE.

**Parameters:**

- `tokenId` - Token ID to delete
- `userId` - Token owner

**Process:**

- Sets card status to INACTIVE (soft delete)
- Logs security event
- Does not remove from database

**Throws:**

- `"Failed to delete card token: ${error}"`

**Example:**

```typescript
await cardProcessor.deleteCardToken(token.id, userId);
```

---

## Integration Guide (Dynamic Registry)

### Architecture

The Card Payment Processor is **registered dynamically** in the Admin UI provider registry - just like `mpesaProvider`, `stripeProvider`, and other payment providers. **No manual provider modules are needed.**

### Setup Steps

#### Step 1: Initialize Card Provider During App Startup

In your main Express app initialization (e.g., `app.ts` or `main.ts`):

```typescript
import express from 'express';
import { initializeCardProvider } from './payments/cardProviderIntegration.js';
import gatewayRoutes from './payments/gatewayRoutes.js';

const app = express();

// Initialize all payment providers (happens once at startup)
initializeCardProvider();

// All payments now route through the dynamic gateway
app.use('/v1/gateway', gatewayRoutes);

app.listen(3000);
```

#### Step 2: Database Tables

The system requires these pre-existing tables (created by migrations):

- `card_tokens` - Tokenized card storage
- `card_transactions` - Payment transaction records
- `transactions` - Financial transaction records
- `financial_ledger` - Accounting ledger entries
- `wallets` - User wallet accounts with `wallet_type` field
- `financial_partners` - Provider registry (Admin UI managed)

#### Step 3: Environment Variables

```bash
# Card Processor Configuration (from Admin UI or env)
CARD_PROCESSOR_KEY=card_processor_key
CARD_PROCESSOR_SECRET=card_processor_secret
CARD_WEBHOOK_SECRET=webhook_secret_from_admin

# System Configuration
SYSTEM_FEE_WALLET_ID=system_fees
ENVIRONMENT=sandbox  # or production
```

#### Step 4: Admin UI Provider Registration

**NO CODE CHANGES NEEDED** for provider configuration. All settings managed via Admin UI:

```
Admin Portal → Financial Partners → Add Provider
  - Name: "Card Processor"
  - Type: "PAYMENT_PROCESSOR"
  - API Key: (encrypted in DataVault)
  - Fee Structure: { percentageFee: 2.5, fixedFee: 0.30, settlementFee: 1.0 }
  - Supported Currencies: USD, EUR, GBP, TZS
  - Status: ACTIVE
```

The provider is automatically registered in `gatewayRouter` and available at runtime.

---

## Implementation Steps

### Phase 1: Database & Environment Setup

#### Step 1.1: Create Database Migrations

Run the SQL migrations for card payment tables (already included in codebase).

#### Step 1.2: Environment Configuration

```bash
# Card Processor (from Admin UI)
CARD_PROCESSOR_KEY=your_processor_key
CARD_WEBHOOK_SECRET=your_webhook_secret

# General Configuration
SYSTEM_FEE_WALLET_ID=system_fees
ENVIRONMENT=sandbox
ENCRYPTION_KEY=your_32_char_key
```

### Phase 2: Provider Registration

#### Step 2.1: Initialize during app startup

```typescript
// app.ts or main.ts
import { initializeCardProvider } from './payments/cardProviderIntegration.js';
import { gatewayRouter } from './payments/paymentGateway.js';

// Add to your Express app initialization:
initializeCardProvider();

console.info('Card provider registered in gateway router');
console.info('Available providers:', gatewayRouter.listProviders());
```

#### Step 2.2: No endpoint code needed

The payment gateway already has generic endpoints for all providers:

```
POST /v1/gateway/payment/initiate       - Any provider
POST /v1/gateway/payment/settle         - Any provider
POST /v1/gateway/payment/refund         - Any provider
GET  /v1/gateway/providers              - List all providers
```

All routing is automatic through `providerId`:

```json
// Request to any provider
POST /v1/gateway/payment/initiate
{
  "providerId": "CARD",    // Automatically routed to CardProvider
  "paymentMethodId": "ct_xxxxx",
  "amount": 50000,
  ...
}
```

### Phase 3: Admin UI Configuration

#### Step 3.1: Register Card Processor

1. Login to Admin Portal as ADMIN
2. Navigate to **Financial Partners** → **Add Provider**
3. Configure:
   - Name: `Card Processor`
   - Type: `PAYMENT_PROCESSOR`
   - API Key: (encrypted automatically)
   - Fee Structure: `{ percentageFee: 2.5, fixedFee: 0.30, settlementFee: 1.0 }`
   - Webhook Secret: Generate and save securely
   - Status: `ACTIVE`
4. Save - provider is immediately available

#### Step 3.2: No code redeployment needed

The provider is dynamically loaded from the registry. Configuration changes take effect immediately.

---

### Workflow Example: Complete Payment Flow

```typescript
// Step 1: Tokenize card
const cardToken = await cardProcessor.tokenizeCard(userId, {
  cardNumber: "4532015112830366",
  expiryMonth: 12,
  expiryYear: 2026,
  cvv: "123",
  cardholderName: "John Doe"
});

console.log(`Card tokenized: ${cardToken.id}`);
console.log(`Masked: ${cardToken.maskedCardNumber}`);

// Step 2: Authorize payment
const transaction = await cardProcessor.authorizeCardPayment(userId, {
  cardTokenId: cardToken.id,
  amount: 50000,        // $500.00
  currency: "USD",
  description: "Purchase - Premium Subscription",
  sourceWalletId: merchantWalletId,
  targetWalletId: userWalletId,
  merchantId: "merchant_123"
});

if (transaction.status === "AUTHORIZED") {
  console.log(`✅ Authorization successful: ${transaction.authorizationCode}`);
  
  // Step 3: Settle payment (moves funds)
  const settlement = await cardProcessor.settleCardPayment(
    transaction.id,
    userId,
    merchantWalletId,
    userWalletId
  );
  
  console.log(`✅ Payment settled: ${settlement.amount} + ${settlement.fee} fee`);
  console.log(`New balance: ${settlement.targetWalletNewBalance}`);
} else {
  console.log(`❌ Authorization declined: ${transaction.responseMessage}`);
  console.log(`Risk score: ${transaction.riskScore}`);
  
  // Handle declined payment
  if (transaction.fraudFlags?.length > 0) {
    console.log(`Fraud flags: ${transaction.fraudFlags.join(", ")}`);
  }
}
```

---

### Error Handling

```typescript
try {
  const transaction = await cardProcessor.authorizeCardPayment(userId, paymentRequest);
  
  if (transaction.status === "DECLINED") {
    // Payment declined - inform user
    return { 
      success: false, 
      message: transaction.responseMessage,
      riskScore: transaction.riskScore
    };
  }
  
  // Proceed to settlement
  await cardProcessor.settleCardPayment(...);
  
} catch (error) {
  // Handle errors
  if (error.message.includes("Card has expired")) {
    // Prompt user to update card
  } else if (error.message.includes("Card token not found")) {
    // Card doesn't exist or was deleted
  } else {
    // Log and report unexpected error
    console.error("Payment processing error:", error);
  }
}
```

---

## Security & Compliance

### PCI-DSS Compliance

✅ **Data Protection:**

- Sensitive card data (number, CVV) encrypted with AES
- Card tokens used instead of raw card numbers in transactions
- No card data stored in plaintext

✅ **Audit Trail:**

- All financial operations logged with timestamp, user, and action
- Security events tracked separately (tokenization, deletion)
- Immutable audit records

✅ **Fingerprinting:**

- SHA-256 hashing for fraud detection
- Fingerprint doesn't require decryption
- Protects against duplicate card abuse

✅ **Access Control:**

- All operations require user ID verification
- Card tokens bound to specific users
- Admin functions separated via `getAdminSupabase()`

### Fraud Prevention

- **RiskEngine Integration:** Evaluates transaction risk before authorization
- **Risk Scoring:** 0-100 scale, blocks transactions > 85
- **Fraud Signals:** Detailed fraud flags returned in response
- **Statistical Analysis:** Historical fraud patterns monitored
- **Card Fingerprinting:** Detects same card across multiple accounts

### Card Validation

**Luhn Algorithm:** Validates card number mathematical integrity before processing

**BIN Detection:** Identifies card brand:

- VISA: `4xxx-xxxx-xxxx-xxxx`
- MASTERCARD: `51-55xx-xxxx-xxxx-xxxx`
- AMEX: `3[47]xx-xxx-xxxxxx`
- DISCOVERY: `6011-xxxx-xxxx-xxxx` or `65xx-xxxx-xxxx-xxxx`

**Expiry Validation:** Ensures card hasn't expired before authorization

---

## Database Schema

### card_tokens Table

```sql
CREATE TABLE card_tokens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  masked_card_number TEXT NOT NULL,
  tokenized_card_number TEXT NOT NULL,  -- AES encrypted
  expiry_month INTEGER,
  expiry_year INTEGER,
  cardholder_name TEXT,
  card_brand TEXT,
  card_type TEXT,
  last_four_digits TEXT,
  fingerprint TEXT UNIQUE,
  is_default BOOLEAN,
  status TEXT,
  encrypted_cvv TEXT,
  billing_address JSONB,
  created_at TIMESTAMP,
  expires_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### card_transactions Table

```sql
CREATE TABLE card_transactions (
  id TEXT PRIMARY KEY,
  card_token_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  merchant_id TEXT,
  amount DECIMAL,
  currency TEXT,
  status TEXT,
  authorization_code TEXT,
  rrn TEXT,
  stan_number TEXT,
  response_code TEXT,
  response_message TEXT,
  risk_score DECIMAL,
  fraud_flags JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  settled_at TIMESTAMP,
  metadata JSONB,
  FOREIGN KEY (card_token_id) REFERENCES card_tokens(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

---

## Monitoring & Logging

### Audit Events

| Event | Type | Details |
|-------|------|---------|
| `CARD_TOKENIZED` | FINANCIAL | Card brand, last 4 digits |
| `CARD_AUTHORIZATION` | FINANCIAL | Transaction ID, amount, risk score |
| `CARD_SETTLEMENT_COMPLETED` | FINANCIAL | Amount, fee, new balance, RRN |
| `CARD_SETTLEMENT_FAILED` | SECURITY | Error reason, transaction ID |
| `CARD_REFUND_PROCESSED` | FINANCIAL | Original and refund transaction IDs |
| `CARD_TOKEN_DELETED` | SECURITY | Token ID |
| `CARD_TOKENIZATION_FAILED` | SECURITY | Error reason |

### Metrics to Track

- Transaction authorization success rate
- Average risk score distribution
- Fraud detection rate and false positives
- Settlement time (target: < 1 second)
- Refund processing time
- System fee collection
- Card brand distribution

---

## Examples

### Example 1: Simple One-Time Payment

```typescript
// User wants to pay with new card
const cardToken = await cardProcessor.tokenizeCard(userId, cardDetails);

const transaction = await cardProcessor.authorizeCardPayment(userId, {
  cardTokenId: cardToken.id,
  amount: 29999,  // $299.99
  currency: "USD",
  description: "One-time purchase",
  sourceWalletId: merchantId,
  targetWalletId: userId
});

if (transaction.status === "AUTHORIZED") {
  const settlement = await cardProcessor.settleCardPayment(
    transaction.id,
    userId,
    merchantId,
    userId
  );
  console.log("Payment complete!");
}
```

### Example 2: Recurring Subscription Payment

```typescript
// Query user's stored card tokens
const savedCards = await cardProcessor.listCardTokens(userId);

if (savedCards.length === 0) {
  // Require tokenization first
  return;
}

// Use default or first card
const defaultCard = savedCards.find(c => c.isDefault) || savedCards[0];

// Process recurring payment
const transaction = await cardProcessor.authorizeCardPayment(userId, {
  cardTokenId: defaultCard.id,
  amount: 99999,  // $999.99 monthly
  currency: "USD",
  description: "Monthly subscription renewal",
  sourceWalletId: platformWalletId,
  targetWalletId: userWalletId,
  metadata: { subscriptionId: "sub_123", billingCycle: 1 }
});

// Auto-settle on morning
scheduleSettlement(transaction.id);
```

### Example 3: Refund Processing

```typescript
// User requests refund within 30 days
const originalTransaction = await getTransaction(transactionId);

if (Date.now() - originalTransaction.createdAt < 30 * 24 * 60 * 60 * 1000) {
  const refund = await cardProcessor.refundCardPayment(
    transactionId,
    userId,
    "Customer refund request - Order #12345"
  );
  
  console.log(`Refund processed: ${refund.refundId}`);
  notifyUser(`Refund of $${refund.originalAmount / 100} has been initiated`);
}
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Invalid card number" | Luhn check failed | Verify card number is entered correctly |
| "Card expired" | Card expiry date passed | Request user to update card |
| "Card token not found" | Token was deleted or belongs to different user | Tokenize card again or retrieve existing tokens |
| "Database connection required" | No Supabase connection | Check environment variables and database status |
| "Transaction blocked by fraud" | Risk score > 85 | Review fraud flags, update risk parameters |
| "Only authorized transactions" | Trying to settle PENDING or FAILED | Verify authorization succeeded first |
| "Settlement failed" | Wallet balance insufficient | Add funds to source wallet |

---

## Version History

**V2.0 (Current)**

- Full double-entry ledger support
- PCI-DSS compliance
- 3D-Secure ready
- Enhanced fraud prevention
- Comprehensive audit logging

---

## Support & Contact

For integration support or security issues:

- **Security Issues:** Report to <security@orbi.finance>
- **Integration Questions:** <integration-support@orbi.finance>
- **Bug Reports:** Create ticket in development system
