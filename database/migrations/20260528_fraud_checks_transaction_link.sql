-- Link fraud checks to authoritative transactions for risk heatmaps,
-- impossible-travel review, chargeback/reversal triage, and audit drill-downs.
-- Nullable by design: some fraud checks are account/device/session checks
-- that are not attached to a specific money movement.

ALTER TABLE public.fraud_checks
  ADD COLUMN IF NOT EXISTS transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fraud_checks_transaction_id
  ON public.fraud_checks(transaction_id);

CREATE INDEX IF NOT EXISTS idx_fraud_checks_user_created
  ON public.fraud_checks(user_id, created_at DESC);

-- Best-effort backfill for older rows where the transaction reference was
-- stored only in JSON payload. The regex guard prevents invalid UUID casts.
UPDATE public.fraud_checks fc
SET transaction_id = candidate.transaction_id::uuid
FROM (
  SELECT
    id,
    COALESCE(
      payload->>'transaction_id',
      payload->>'transactionId',
      payload->'transaction'->>'id',
      payload->'riskContext'->>'transactionId',
      payload->'risk_context'->>'transaction_id'
    ) AS transaction_id
  FROM public.fraud_checks
) candidate
WHERE fc.id = candidate.id
  AND fc.transaction_id IS NULL
  AND candidate.transaction_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  AND EXISTS (
    SELECT 1
    FROM public.transactions tx
    WHERE tx.id = candidate.transaction_id::uuid
  );
