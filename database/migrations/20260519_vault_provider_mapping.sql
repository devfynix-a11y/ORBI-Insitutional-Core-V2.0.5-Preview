-- External reconciliation requires each reconcilable platform vault to declare
-- which configured financial partner owns the matching external balance.

COMMENT ON COLUMN public.platform_vaults.metadata IS
  'JSON metadata. External reconciliation reads provider_id, providerId, provider_code, providerCode, partner_id, partnerId, partner_code, or partnerCode from this object.';

CREATE INDEX IF NOT EXISTS idx_platform_vaults_metadata_provider_id
  ON public.platform_vaults ((metadata->>'provider_id'));

CREATE INDEX IF NOT EXISTS idx_platform_vaults_metadata_provider_code
  ON public.platform_vaults ((metadata->>'provider_code'));

CREATE OR REPLACE FUNCTION public.set_platform_vault_partner_mapping(
  p_vault_id UUID,
  p_provider_id UUID DEFAULT NULL,
  p_provider_code TEXT DEFAULT NULL
)
RETURNS public.platform_vaults
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_partner public.financial_partners%ROWTYPE;
  v_vault public.platform_vaults%ROWTYPE;
  v_provider_code TEXT;
BEGIN
  IF p_provider_id IS NULL AND BTRIM(COALESCE(p_provider_code, '')) = '' THEN
    RAISE EXCEPTION 'PROVIDER_MAPPING_REQUIRED';
  END IF;

  IF p_provider_id IS NOT NULL THEN
    SELECT *
      INTO v_partner
      FROM public.financial_partners
     WHERE id = p_provider_id
     LIMIT 1;
  ELSE
    SELECT *
      INTO v_partner
      FROM public.financial_partners
     WHERE BTRIM(LOWER(provider_metadata->>'provider_code')) = BTRIM(LOWER(p_provider_code))
     LIMIT 1;
  END IF;

  IF v_partner.id IS NULL THEN
    RAISE EXCEPTION 'FINANCIAL_PARTNER_NOT_FOUND';
  END IF;

  v_provider_code := BTRIM(COALESCE(v_partner.provider_metadata->>'provider_code', p_provider_code, v_partner.name));

  UPDATE public.platform_vaults
     SET metadata = COALESCE(metadata, '{}'::jsonb)
       || jsonb_build_object(
            'provider_id', v_partner.id,
            'provider_code', v_provider_code,
            'partner_id', v_partner.id,
            'partner_code', v_provider_code,
            'provider_mapping_updated_at', NOW()
          ),
         updated_at = NOW()
   WHERE id = p_vault_id
   RETURNING * INTO v_vault;

  IF v_vault.id IS NULL THEN
    RAISE EXCEPTION 'PLATFORM_VAULT_NOT_FOUND';
  END IF;

  RETURN v_vault;
END;
$$;

CREATE OR REPLACE VIEW public.platform_vault_provider_mapping_gaps AS
SELECT
  pv.id,
  pv.name,
  pv.vault_role,
  pv.currency,
  pv.status,
  pv.metadata,
  pv.created_at,
  pv.updated_at
FROM public.platform_vaults pv
WHERE COALESCE(pv.status, 'active') = 'active'
  AND (
    NULLIF(BTRIM(COALESCE(pv.metadata->>'provider_id', pv.metadata->>'providerId', pv.metadata->>'partner_id', pv.metadata->>'partnerId')), '') IS NULL
    AND NULLIF(BTRIM(COALESCE(pv.metadata->>'provider_code', pv.metadata->>'providerCode', pv.metadata->>'partner_code', pv.metadata->>'partnerCode')), '') IS NULL
  );
