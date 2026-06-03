-- B2B operational depth for ORBI platform control:
-- merchant settlement reports, agent float controls, commission disputes,
-- and organization-level limit governance.

CREATE TABLE IF NOT EXISTS public.merchant_settlement_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id UUID REFERENCES public.merchants(id) ON DELETE CASCADE,
    owner_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    currency TEXT NOT NULL DEFAULT 'TZS',
    gross_amount NUMERIC NOT NULL DEFAULT 0,
    fee_amount NUMERIC NOT NULL DEFAULT 0,
    tax_amount NUMERIC NOT NULL DEFAULT 0,
    net_amount NUMERIC NOT NULL DEFAULT 0,
    transaction_count INTEGER NOT NULL DEFAULT 0,
    settled_transaction_count INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'generated',
    generated_by TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT merchant_settlement_reports_status_check
        CHECK (status IN ('generated', 'reviewed', 'exported', 'void'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_merchant_settlement_reports_unique_period
    ON public.merchant_settlement_reports(merchant_id, period_start, period_end, currency);
CREATE INDEX IF NOT EXISTS idx_merchant_settlement_reports_merchant_period
    ON public.merchant_settlement_reports(merchant_id, period_end DESC);

CREATE TABLE IF NOT EXISTS public.agent_float_controls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID REFERENCES public.agents(id) ON DELETE CASCADE,
    owner_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    currency TEXT NOT NULL DEFAULT 'TZS',
    min_float NUMERIC NOT NULL DEFAULT 0,
    max_float NUMERIC,
    daily_cash_in_limit NUMERIC,
    daily_cash_out_limit NUMERIC,
    status TEXT NOT NULL DEFAULT 'active',
    reason TEXT NOT NULL DEFAULT 'Initial float governance policy',
    updated_by TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT agent_float_controls_status_check
        CHECK (status IN ('active', 'paused', 'locked'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_float_controls_unique_currency
    ON public.agent_float_controls(agent_id, currency);
CREATE INDEX IF NOT EXISTS idx_agent_float_controls_status
    ON public.agent_float_controls(status, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.service_commission_disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commission_id UUID REFERENCES public.service_commissions(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'open',
    reason TEXT NOT NULL,
    resolution_note TEXT,
    opened_by TEXT,
    resolved_by TEXT,
    resolved_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT service_commission_disputes_status_check
        CHECK (status IN ('open', 'under_review', 'resolved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_service_commission_disputes_commission
    ON public.service_commission_disputes(commission_id);
CREATE INDEX IF NOT EXISTS idx_service_commission_disputes_actor_status
    ON public.service_commission_disputes(actor_user_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.organization_limit_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    currency TEXT NOT NULL DEFAULT 'TZS',
    max_amount_per_tx NUMERIC,
    daily_limit NUMERIC,
    monthly_limit NUMERIC,
    maker_checker_threshold NUMERIC,
    auto_freeze_threshold NUMERIC,
    status TEXT NOT NULL DEFAULT 'active',
    reason TEXT NOT NULL DEFAULT 'Initial organization limit policy',
    updated_by TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT organization_limit_configs_status_check
        CHECK (status IN ('active', 'paused', 'locked'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_organization_limit_configs_unique_currency
    ON public.organization_limit_configs(organization_id, currency);
CREATE INDEX IF NOT EXISTS idx_organization_limit_configs_status
    ON public.organization_limit_configs(status, updated_at DESC);
