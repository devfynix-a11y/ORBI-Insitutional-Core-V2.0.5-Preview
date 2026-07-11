-- Allow PaySafe release requests to pause while waiting for receiver acceptance.
-- transition_paysafe_escrow_v1 writes this state before ACCEPT finalizes funds.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'transactions_status_check'
          AND conrelid = 'public.transactions'::regclass
    ) THEN
        ALTER TABLE public.transactions DROP CONSTRAINT transactions_status_check;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'transactions_status_check_v2'
          AND conrelid = 'public.transactions'::regclass
    ) THEN
        ALTER TABLE public.transactions DROP CONSTRAINT transactions_status_check_v2;
    END IF;
END $$;

ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_status_check
    CHECK (status IN (
        'created',
        'pending',
        'authorized',
        'processing',
        'settled',
        'completed',
        'failed',
        'cancelled',
        'held_for_review',
        'awaiting_receiver_acceptance',
        'reversed',
        'refunded'
    ));

ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_status_check_v2
    CHECK (status IN (
        'created',
        'pending',
        'authorized',
        'processing',
        'settled',
        'completed',
        'failed',
        'cancelled',
        'held_for_review',
        'awaiting_receiver_acceptance',
        'reversed',
        'refunded'
    ));
