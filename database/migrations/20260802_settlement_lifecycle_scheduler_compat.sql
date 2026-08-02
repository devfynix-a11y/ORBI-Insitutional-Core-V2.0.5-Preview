-- Settlement lifecycle scheduler compatibility.
--
-- Some runtime schedulers still read legacy phase/user fields while the
-- authoritative lifecycle schema uses stage/status/net_amount/attempt_count.
-- Keep this migration until every scheduler query has moved to the canonical
-- lifecycle columns.

ALTER TABLE public.settlement_lifecycle
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS amount NUMERIC NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS current_phase TEXT NOT NULL DEFAULT 'EXTERNAL_PENDING',
  ADD COLUMN IF NOT EXISTS retry_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS phase_started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS phase_completed_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS auto_settle_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS auto_settle_executed_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS external_settlement_id TEXT,
  ADD COLUMN IF NOT EXISTS reconciliation_id TEXT,
  ADD COLUMN IF NOT EXISTS reconciliation_result JSONB,
  ADD COLUMN IF NOT EXISTS financial_tx_id UUID,
  ADD COLUMN IF NOT EXISTS wallet_id UUID REFERENCES public.wallets(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS order_id TEXT;

UPDATE public.settlement_lifecycle sl
SET
  user_id = COALESCE(
    sl.user_id,
    (SELECT t.user_id FROM public.transactions t WHERE t.id = sl.transaction_id LIMIT 1),
    (SELECT efm.user_id FROM public.external_fund_movements efm WHERE efm.id = sl.external_movement_id LIMIT 1)
  ),
  amount = CASE
    WHEN sl.amount IS NULL OR sl.amount = 0 THEN COALESCE(NULLIF(sl.net_amount, 0), sl.gross_amount, 0)
    ELSE sl.amount
  END,
  retry_count = COALESCE(NULLIF(sl.retry_count, 0), sl.attempt_count, 0),
  phase_started_at = COALESCE(
    sl.phase_started_at,
    sl.processing_at,
    sl.queued_at,
    sl.initiated_at,
    sl.created_at,
    NOW()
  ),
  phase_completed_at = COALESCE(sl.phase_completed_at, sl.settled_at, sl.reconciled_at, sl.failed_at, sl.reversed_at),
  auto_settle_at = COALESCE(sl.auto_settle_at, sl.provider_confirmed_at, sl.sent_to_provider_at),
  current_phase = COALESCE(NULLIF(sl.current_phase, ''), 'EXTERNAL_PENDING'),
  external_settlement_id = COALESCE(sl.external_settlement_id, sl.provider_reference),
  order_id = COALESCE(sl.order_id, sl.settlement_batch_id)
WHERE sl.user_id IS NULL
   OR sl.amount IS NULL
   OR sl.amount = 0
   OR sl.phase_started_at IS NULL
   OR sl.retry_count IS NULL
   OR sl.auto_settle_at IS NULL
   OR sl.external_settlement_id IS NULL
   OR sl.order_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_settlement_lifecycle_current_phase_auto
  ON public.settlement_lifecycle (current_phase, auto_settle_at)
  WHERE auto_settle_executed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_settlement_lifecycle_current_phase_retry
  ON public.settlement_lifecycle (current_phase, retry_count, updated_at);

CREATE INDEX IF NOT EXISTS idx_settlement_lifecycle_user_phase
  ON public.settlement_lifecycle (user_id, current_phase, phase_started_at DESC);
