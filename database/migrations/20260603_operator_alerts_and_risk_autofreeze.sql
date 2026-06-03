CREATE TABLE IF NOT EXISTS public.operator_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'HIGH', 'CRITICAL')),
    event_code TEXT NOT NULL,
    target_roles TEXT[] DEFAULT ARRAY['SUPER_ADMIN', 'ADMIN', 'RISK_OFFICER', 'AUDIT']::TEXT[],
    actor_id TEXT,
    transaction_id TEXT,
    resource_type TEXT,
    resource_id TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    actions JSONB DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'UNREAD' CHECK (status IN ('UNREAD', 'READ', 'RESOLVED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by TEXT,
    resolution_note TEXT
);

ALTER TABLE public.operator_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Operator alert read" ON public.operator_alerts;
CREATE POLICY "Operator alert read" ON public.operator_alerts
FOR SELECT USING ((SELECT public.get_auth_role()) IN ('SUPER_ADMIN', 'ADMIN', 'AUDIT', 'RISK_OFFICER', 'FRAUD', 'IT', 'CUSTOMER_CARE'));

DROP POLICY IF EXISTS "Operator alert system write" ON public.operator_alerts;
CREATE POLICY "Operator alert system write" ON public.operator_alerts
FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_operator_alerts_status_created ON public.operator_alerts(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_operator_alerts_event_created ON public.operator_alerts(event_code, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_operator_alerts_transaction_created ON public.operator_alerts(transaction_id, created_at DESC);

INSERT INTO public.infra_system_matrix (config_key, config_data, updated_at)
VALUES (
    'HEURISTIC_RULES',
    jsonb_build_object(
        'VL-001', jsonb_build_object('id', 'VL-001', 'active', true, 'name', 'Velocity Burst', 'severity', 'HIGH', 'parameters', jsonb_build_object('threshold', 10), 'description', 'High frequency transactional bursts'),
        'ID-001', jsonb_build_object('id', 'ID-001', 'active', true, 'name', 'Identity Node Check', 'severity', 'CRITICAL', 'parameters', jsonb_build_object(), 'description', 'Verified KYC status verification'),
        'broker_notifications', jsonb_build_object(
            'enabled', true,
            'thresholdUsd', 10000,
            'email', jsonb_build_object('enabled', true, 'recipients', jsonb_build_array('security@orbifinancial.com')),
            'slack', jsonb_build_object('enabled', false, 'channel', '#ops-security-feed'),
            'eventCode', 'DYNAMIC_BROKER_LIMIT_EXCEEDED',
            'updatedAt', null
        ),
        'auto_freeze', jsonb_build_object(
            'enabled', false,
            'riskScoreThreshold', 90,
            'action', 'SUSPEND_USER',
            'targetRoles', jsonb_build_array('SUPER_ADMIN', 'ADMIN', 'RISK_OFFICER', 'FRAUD'),
            'updatedAt', null
        )
    ),
    NOW()
)
ON CONFLICT (config_key) DO UPDATE
SET config_data = COALESCE(public.infra_system_matrix.config_data, '{}'::jsonb)
    || jsonb_build_object(
        'broker_notifications',
        COALESCE(public.infra_system_matrix.config_data->'broker_notifications', EXCLUDED.config_data->'broker_notifications'),
        'auto_freeze',
        COALESCE(public.infra_system_matrix.config_data->'auto_freeze', EXCLUDED.config_data->'auto_freeze')
    ),
    updated_at = NOW();
