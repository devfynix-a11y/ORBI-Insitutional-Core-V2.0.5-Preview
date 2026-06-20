# ORBI Platform: Operational Architecture & Ecosystem Guide

**Version**: 30.0 (Titanium)  
**Last Updated**: 2026-03-14
**Classification**: STAKEHOLDER / INVESTOR / PARTNER INTERNAL  
**Status**: Authoritative

---

## 1. Executive Summary
ORBI is a high-fidelity, sovereign financial operating system. This document outlines the core operational mechanics of the platform, specifically focusing on how we manage internal financial structures (Budgets/Goals), external integrations (Linked Wallets/Partners), and provide forensic transparency for investors and auditors.

---

## 2. Internal Financial Structures

### 2.1 Budgets: Hard Enforcement & Risk Mitigation
Budgets in ORBI are not merely "trackers"; they are active enforcement nodes within the **BankingEngine**.

*   **Multi-Tenancy**: Supports personal budgets for retail users and departmental cost-centers for enterprise tenants.
*   **Enforcement Modes**:
    *   **Soft Limit**: Generates `EXCEEDED_WARNING` alerts but allows the transaction to complete.
    *   **Hard Limit**: The ledger physically blocks the transaction with an `INSUFFICIENT_BUDGET` error if the period limit (Monthly/Quarterly/Annual) is reached.
*   **Intelligent Thresholds**: Automated triggers at **80%** (Warning) and **100%** (Critical) of budget targets, dispatched via WebSockets and secure messaging.

### 2.2 Goals: Savings & Treasury Management
Goals act as specialized financial containers (Vaults) with unique logic.

*   **Personal Savings**: Retail users utilize goals for milestone-based savings with target amounts and deadlines.
*   **Corporate Treasury**: Enterprise goals support **Auto-Sweep** logic. The system monitors operating vaults and automatically "sweeps" excess liquidity into treasury goals once a pre-defined threshold is met, optimizing capital allocation.
*   **Atomic Allocation**: Moving funds into a goal is a multi-leg ledger operation, ensuring zero-loss consistency.
*   **Multi-Sig Treasury**: Large withdrawals from corporate goals require multi-sig approval via the **Treasury Approval Workflow**.

---

## 3. External Ecosystem Integration

### 3.1 External Linked Wallets (Shadow Accounts)
ORBI treats external accounts (M-Pesa, Bank Accounts, etc.) as **Shadow Wallets** within the system.

*   **Management Tier**: Marked as `linked` to distinguish them from native `sovereign` vaults.
*   **State Synchronization**: While Sovereign vaults are authoritative, Linked wallets use a **Cached State** model, synchronized via real-time webhooks or periodic partner API polling.
*   **Ingress/Egress Flows**: 
    *   **Ingress**: Triggers external debit protocols (e.g., STK Push) and holds the internal transaction in `authorized` state until partner confirmation.
    *   **Egress**: Triggers automated disbursement requests to partner gateways.

### 3.2 Orbi TrustBridge (Conditional Escrow)
The **TrustBridge** is Orbi's answer to the trust gap in African P2P social commerce (e.g., WhatsApp/Instagram sales).

*   **Conditional Release**: Funds are locked in the sender's `PaySafe` vault and only released to the seller when the buyer confirms receipt or a logistics partner API confirms delivery.
*   **Dispute Management**: In case of a dispute, the transaction is frozen for manual forensic review. Orbi's AI analyzes transaction metadata and provided evidence to propose a fair resolution.
*   **The Difference**: Unlike NALA or Tembo, Orbi protects the *exchange of value*, making it the trust layer for the digital economy.

### 3.3 Financial Partner Registry
The platform features a **Dynamic Provider Engine** that allows onboarding new banks or telcos without code changes.

*   **Mapping Config**: Partners are defined via JSON contracts specifying endpoints, headers, and payload templates.
*   **Signature Verification**: All incoming webhooks are validated using the `connection_secret` stored in the encrypted **DataVault**.
*   **Resilience**: Circuit breakers monitor partner health and automatically degrade or reroute traffic if a provider goes offline.

---

## 4. Platform Activity & Forensic Transparency

### 4.1 For Investors & Stakeholders
ORBI provides absolute transparency into platform health and financial integrity.

*   **Atomic Ledger**: Every transaction is recorded as a series of immutable "legs" in the `financial_ledger`. We do not use "balance updates"; we use "transactional derivation."
*   **Audit Trail**: A blockchain-inspired, append-only log records every system event, state change, and administrative action with cryptographic hashes for non-repudiation.
*   **System Metrics**: Real-time throughput, liquidity ratios, and success rates are available via the `sys/metrics` API.

### 4.2 For Auditors (Reconciliation Engine)
The **Reconciliation Engine** is the platform's "Internal Auditor."

*   **Continuous Verification**: It cross-references internal ledger states against external partner statements (M-Pesa/Bank logs).
*   **Discrepancy Alerts**: Any mismatch triggers an immediate `RECON_ALARM` to the IT and Audit teams.
*   **Forensic Ledger**: Detailed "forensic legs" allow auditors to trace a single transaction through every internal vault and external gateway.

### 4.3 Security: Neural Sentinel AI
The **Sentinel Engine** monitors all platform activity in real-time.

*   **Risk Scoring**: Every request is scored (0-100) based on 200+ behavioral and geographic vectors.
*   **Autonomous Defense**: High-risk operations are automatically blocked or challenged with MFA, protecting the platform's liquidity and user assets from sophisticated fraud.

---

**ORBI Financial Technologies Ltd.**  
*The Sovereign Standard for African Wealth.*
