-- Official Pay Gateway developer secret vault.
-- Stores fingerprints only. Raw API keys and webhook secrets must never be persisted.

create extension if not exists pgcrypto;

create table if not exists public.pay_gateway_developer_services (
  service_code text primary key,
  display_name text not null,
  legal_name text,
  business_type text,
  country_code text,
  contact_email text,
  contact_phone text,
  status text not null default 'draft',
  environments text[] not null default array[]::text[],
  scopes_granted text[] not null default array[]::text[],
  scopes_pending text[] not null default array[]::text[],
  redirect_urls text[] not null default array[]::text[],
  webhook_urls text[] not null default array[]::text[],
  external_developer_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pay_gateway_developer_services_status_check
    check (status in ('draft', 'active', 'suspended', 'revoked'))
);

create table if not exists public.pay_gateway_developer_api_keys (
  key_id text primary key,
  service_code text not null references public.pay_gateway_developer_services(service_code) on delete cascade,
  environment text not null,
  fingerprint text not null,
  encrypted_secret jsonb,
  status text not null default 'active',
  issued_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  issued_by text,
  revoked_by text,
  rotation_reason text,
  metadata jsonb not null default '{}'::jsonb,
  constraint pay_gateway_developer_api_keys_environment_check
    check (environment in ('sandbox', 'live')),
  constraint pay_gateway_developer_api_keys_status_check
    check (status in ('active', 'revoked', 'expired')),
  constraint pay_gateway_developer_api_keys_fingerprint_unique
    unique (fingerprint)
);

create table if not exists public.pay_gateway_developer_webhook_secrets (
  secret_id text primary key,
  service_code text not null references public.pay_gateway_developer_services(service_code) on delete cascade,
  environment text not null,
  fingerprint text not null,
  status text not null default 'active',
  issued_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  issued_by text,
  revoked_by text,
  rotation_reason text,
  metadata jsonb not null default '{}'::jsonb,
  constraint pay_gateway_developer_webhook_secrets_environment_check
    check (environment in ('sandbox', 'live')),
  constraint pay_gateway_developer_webhook_secrets_status_check
    check (status in ('active', 'revoked', 'expired')),
  constraint pay_gateway_developer_webhook_secrets_fingerprint_unique
    unique (fingerprint)
);

create table if not exists public.pay_gateway_developer_secret_events (
  event_id text primary key,
  service_code text references public.pay_gateway_developer_services(service_code) on delete set null,
  environment text,
  event_type text not null,
  actor_id text,
  actor_name text,
  target_type text,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint pay_gateway_developer_secret_events_environment_check
    check (environment is null or environment in ('sandbox', 'live'))
);

create index if not exists pay_gateway_developer_api_keys_lookup_idx
  on public.pay_gateway_developer_api_keys (fingerprint, status, environment);

create index if not exists pay_gateway_developer_api_keys_service_idx
  on public.pay_gateway_developer_api_keys (service_code, environment, status);

create index if not exists pay_gateway_developer_webhook_secrets_lookup_idx
  on public.pay_gateway_developer_webhook_secrets (fingerprint, status, environment);

create index if not exists pay_gateway_developer_secret_events_service_idx
  on public.pay_gateway_developer_secret_events (service_code, occurred_at desc);

comment on table public.pay_gateway_developer_api_keys is
  'Developer API key vault. Stores fingerprints only; raw keys are displayed once and never persisted.';

comment on table public.pay_gateway_developer_webhook_secrets is
  'Developer webhook secret vault. Stores fingerprints and encrypted signing secrets. Raw webhook secrets are never stored in plaintext.';
