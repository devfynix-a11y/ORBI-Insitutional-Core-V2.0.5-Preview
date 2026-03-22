-- ENTERPRISE FINTECH SCHEMA (V2)
-- Run this in your Supabase SQL Editor to provision the Enterprise Ledger

-- 0. Passkeys Table
CREATE TABLE IF NOT EXISTS passkeys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    credential_id TEXT UNIQUE NOT NULL,
    public_key TEXT NOT NULL,
    counter BIGINT DEFAULT 0,
    transports JSONB DEFAULT '[]'::jsonb,
    device_type TEXT,
    backed_up BOOLEAN DEFAULT FALSE,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_passkeys_user_id ON passkeys(user_id);

-- 1. Idempotency Protection
CREATE TABLE IF NOT EXISTS ent_idempotency_keys (
    key UUID PRIMARY KEY,
    client_id UUID NOT NULL,
    request_path VARCHAR(255) NOT NULL,
    response_status INT,
    response_body JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours'
);
CREATE INDEX IF NOT EXISTS idx_ent_idemp_expires ON ent_idempotency_keys(expires_at);

-- 2. Transaction State Machine & Metadata
DO $$ BEGIN
    CREATE TYPE ent_tx_state AS ENUM ('INITIATED', 'AUTHORIZED', 'PROCESSING', 'HELD_FOR_REVIEW', 'SETTLED', 'FAILED', 'REVERSED', 'EXPIRED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS ent_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key UUID UNIQUE REFERENCES ent_idempotency_keys(key),
    reference_id VARCHAR(100) UNIQUE NOT NULL,
    state ent_tx_state NOT NULL DEFAULT 'INITIATED',
    amount DECIMAL(19,4) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. State Audit History (For Compliance)
CREATE TABLE IF NOT EXISTS ent_transaction_state_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID REFERENCES ent_transactions(id),
    previous_state ent_tx_state,
    new_state ent_tx_state NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Immutable Double-Entry Journal
DO $$ BEGIN
    CREATE TYPE ent_entry_direction AS ENUM ('CREDIT', 'DEBIT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS ent_ledger_journal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID REFERENCES ent_transactions(id) NOT NULL,
    wallet_id UUID REFERENCES wallets(id) NOT NULL,
    direction ent_entry_direction NOT NULL,
    amount DECIMAL(19,4) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure immutability via Trigger
CREATE OR REPLACE FUNCTION prevent_ent_journal_updates() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Enterprise Ledger journal entries are immutable. Use compensating transactions to reverse.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_ent_immutability ON ent_ledger_journal;
CREATE TRIGGER enforce_ent_immutability
BEFORE UPDATE OR DELETE ON ent_ledger_journal
FOR EACH ROW EXECUTE FUNCTION prevent_ent_journal_updates();

-- 5. System Vaults (Dynamic Registry)
CREATE TABLE IF NOT EXISTS ent_system_vaults (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vault_purpose VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'OPERATING', 'TAX', 'REVENUE', 'SETTLEMENT'
    wallet_id UUID UNIQUE NOT NULL REFERENCES wallets(id),
    is_active BOOLEAN DEFAULT TRUE
);

-- 6. ATOMIC COMMIT RPC (The Core Ledger Engine)
-- This function guarantees ACID compliance for the double-entry ledger.
CREATE OR REPLACE FUNCTION enterprise_commit_transaction(
    p_idempotency_key UUID,
    p_reference_id VARCHAR,
    p_amount DECIMAL,
    p_currency VARCHAR,
    p_source_wallet_id UUID,
    p_target_wallet_id UUID,
    p_metadata JSONB
) RETURNS JSONB AS $$
DECLARE
    v_tx_id UUID;
    v_source_balance DECIMAL;
BEGIN
    -- 1. Lock and Check Source Balance
    SELECT balance INTO v_source_balance FROM wallets WHERE id = p_source_wallet_id FOR UPDATE;
    IF v_source_balance IS NULL THEN
        RAISE EXCEPTION 'SOURCE_WALLET_NOT_FOUND';
    END IF;
    IF v_source_balance < p_amount THEN
        RAISE EXCEPTION 'INSUFFICIENT_FUNDS';
    END IF;

    -- 2. Lock Target Wallet (to prevent deadlocks, ensure consistent ordering in app layer, but here we just lock)
    PERFORM id FROM wallets WHERE id = p_target_wallet_id FOR UPDATE;

    -- 3. Create Transaction Record
    INSERT INTO ent_transactions (idempotency_key, reference_id, state, amount, currency, metadata)
    VALUES (p_idempotency_key, p_reference_id, 'SETTLED', p_amount, p_currency, p_metadata)
    RETURNING id INTO v_tx_id;

    -- 4. Create Immutable Journal Entries (Double-Entry)
    INSERT INTO ent_ledger_journal (transaction_id, wallet_id, direction, amount, currency)
    VALUES (v_tx_id, p_source_wallet_id, 'DEBIT', p_amount, p_currency);

    INSERT INTO ent_ledger_journal (transaction_id, wallet_id, direction, amount, currency)
    VALUES (v_tx_id, p_target_wallet_id, 'CREDIT', p_amount, p_currency);

    -- 5. Mutate Wallet Balances
    UPDATE wallets SET balance = balance - p_amount WHERE id = p_source_wallet_id;
    UPDATE wallets SET balance = balance + p_amount WHERE id = p_target_wallet_id;

    -- 6. Record State Transition
    INSERT INTO ent_transaction_state_history (transaction_id, previous_state, new_state, reason)
    VALUES (v_tx_id, 'PROCESSING', 'SETTLED', 'Atomic commit successful via RPC');

    -- Return Success Payload
    RETURN jsonb_build_object(
        'success', true, 
        'transaction_id', v_tx_id,
        'timestamp', NOW()
    );
EXCEPTION WHEN OTHERS THEN
    -- Return Error Payload (Rollback happens automatically)
    RETURN jsonb_build_object(
        'success', false, 
        'error', SQLERRM,
        'state', SQLSTATE
    );
END;
$$ LANGUAGE plpgsql;
