# Database Schema Reset Guide

This guide explains how to reset your Supabase database schema to a clean, well-structured state using the provided SQL script.

## ⚠️ WARNING
**This operation will DELETE ALL DATA in your `public` schema.**
Ensure you have backed up any critical data before proceeding.

## Prerequisites
- Access to your Supabase Project Dashboard.
- The `database/schema_reset.sql` file provided in this repository.

## Instructions

1.  **Open Supabase Dashboard**: Go to your project's dashboard at [app.supabase.com](https://app.supabase.com).
2.  **Go to SQL Editor**: Click on the "SQL Editor" icon in the left sidebar.
3.  **New Query**: Click "New query".
4.  **Copy Script**: Open `database/schema_reset.sql` in your code editor and copy its entire content.
5.  **Paste & Run**: Paste the content into the Supabase SQL Editor and click "Run" (bottom right).

## What This Script Does
1.  **Drops ALL Existing Tables**: Removes all tables listed in your request (`users`, `wallets`, `transactions`, `goals`, `categories`, `tasks`, `staff`, `audit_trail`, `regulatory_config`, etc.) to ensure a completely clean slate.
2.  **Recreates Tables**: Creates new tables based on the `sql.txt` design and current app requirements:
    -   **Core Identity**: `users`, `staff` (with `role`, `registry_type`, `app_origin`).
    -   **Wealth Domain**: `wallets`, `platform_vaults`, `transactions`, `financial_ledger`.
    -   **Strategy Domain**: `goals`, `tasks`.
    -   **Utility**: `categories`, `user_messages`, `staff_messages`, `system_messages`.
    -   **Infrastructure**: `financial_partners`, `digital_merchants`, `regulatory_config`, `transfer_tax_rules`, `infra_*` tables.
    -   **Audit & Security**: `audit_trail`, `user_activity`, `provider_anomalies`.
3.  **Enables RLS**: Activates Row Level Security on all tables.
4.  **Adds Policies**: Creates standard RLS policies so users can only access their own data.
5.  **Sets up Triggers**: Adds triggers to automatically update the `updated_at` timestamp.
6.  **Creates Indexes**: Adds performance indexes for common queries.

## Post-Reset Steps
After running the script:
1.  **Restart Backend**: Restart your backend server to ensure it reconnects cleanly.
2.  **Sign Up**: Create a new user account via your app. The `authService.ts` has been updated to populate the new `role` and `registry_type` columns.
    -   **Note**: If you do not run this script, signups will fail because the code now expects these columns to exist.
