create table if not exists public.murketa_keys (
  id text primary key,
  payload jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.murketa_keys enable row level security;
revoke all on table public.murketa_keys from anon, authenticated;
grant all on table public.murketa_keys to service_role;
