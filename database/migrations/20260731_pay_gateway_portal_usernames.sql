-- Pay Gateway Developer Portal usernames.
-- Every developer/operator/admin portal identity must have a unique username.

create table if not exists public.pay_gateway_portal_users (
  user_id text primary key,
  username text,
  email text not null unique,
  name text not null,
  role text not null check (role in ('developer','operator','admin')),
  permissions text[] not null default '{}',
  live_access boolean not null default false,
  service_codes text[] not null default '{}',
  password_salt text not null,
  password_hash text not null,
  password_iterations integer not null default 210000,
  totp_secret text,
  mfa_required boolean not null default false,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.pay_gateway_portal_users
  add column if not exists username text;

update public.pay_gateway_portal_users
  set username = lower(regexp_replace(split_part(email, '@', 1), '[^a-zA-Z0-9_-]+', '_', 'g')) || '_' || substr(md5(email), 1, 8)
  where username is null or trim(username) = '';

alter table public.pay_gateway_portal_users
  alter column username set not null;

create unique index if not exists pay_gateway_portal_users_username_unique_idx
  on public.pay_gateway_portal_users (lower(username));

comment on column public.pay_gateway_portal_users.username is
  'Unique developer portal username used as a stable public-facing handle. Email remains private login identity.';

notify pgrst, 'reload schema';
