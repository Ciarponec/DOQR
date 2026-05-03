create table if not exists public.ring_rate_limits (
  id uuid primary key default gen_random_uuid(),
  scope_type text not null check (scope_type in ('door','ip','token')),
  scope_key text not null,
  window_start timestamptz not null,
  attempt_count int not null default 0,
  blocked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(scope_type, scope_key, window_start)
);

alter table public.ring_rate_limits enable row level security;

create policy ring_rate_limits_none on public.ring_rate_limits
for all using (false) with check (false);

create index if not exists ring_rate_limits_scope_idx
  on public.ring_rate_limits(scope_type, scope_key, window_start desc);
