# Project Structure & File Management

This document provides a breakdown of the ORBI Sovereign Backend project structure to assist with manual management and maintenance.

## Directory Overview

### `/ledger/`
Core financial services and ledger management.
*   `transactionService.ts`: Central service for managing ledger entries, balance verification, and reconciliation.
*   `PolicyEngine.ts`: Financial rule enforcement and limit management.

### `/backend/`
The heart of the application, containing the core business logic, financial engines, and infrastructure services.

*   `/backend/enterprise/`: Enterprise B2B capabilities, including Treasury management, Wealth services, and Enterprise-level types.
*   `/backend/ledger/`: Core financial engines. Handles transactions, FX, reconciliation, regulatory compliance, and transaction state machines.
*   `/backend/payments/`: Integrations with external payment providers (Airtel, Mpesa, MerchantFabric).
*   `/backend/security/`: Critical security components. Includes Risk/Compliance engines, encryption, WAF, JWT, KMS, and anomaly tracking.
*   `/backend/infrastructure/`: Low-level infrastructure services. Handles Redis, EventBus, Cache, **Health monitoring (MonitoringService)**, and Socket management.
*   `/backend/features/`: Specific feature implementations like Asset Lifecycle, **Messaging (MessagingService)**, and Provisioning.
*   `/backend/src/`: Additional backend modules, including specialized services for auth, fraud, passkeys, and sessions.

### `/iam/`
Identity and Access Management.
*   Handles authentication, biometric services, device attestation, KYC (Know Your Customer), and document verification.

### `/wealth/`
Wealth and asset management services.
*   Manages bank services, merchant accounts, revenue services, and wallet resolution.

### `/strategy/`
Business strategy and planning logic.
*   Handles service definitions for categories, goals, and tasks.

### `/services/`
Shared utility services used across the application.
*   Includes SMS providers, financial logic utilities, and Supabase client configurations.

### `/core/`
Shared definitions.
*   Contains global TypeScript types and utility functions used throughout the project.

### `/database/`
Database management.
*   Contains SQL schema definitions and reset scripts.

### `/docs/`
Project documentation.
*   Contains all architectural guides, integration manuals, and deployment instructions.

## Key Files at Root
*   `server.ts`: The main entry point for the backend server.
*   `metadata.json`: Application metadata (name, description, permissions).
*   `package.json`: Dependency and script management.
*   `tsconfig.json`: TypeScript configuration.
*   `.env.example`: Template for environment variables.
