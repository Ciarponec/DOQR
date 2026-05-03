-- DOQR secure MVP + future hardware prep
create extension if not exists pgcrypto;

-- profiles
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  fcm_token text not null,
  platform text check (platform in ('android','ios','web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, fcm_token)
);

create table if not exists public.doors (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.users(id) on delete cascade,
  label text not null,
  address_text text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- token-based QR indirection (no direct door_id exposure)
create table if not exists public.door_public_tokens (
  id uuid primary key default gen_random_uuid(),
  door_id uuid not null references public.doors(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.rings (
  id uuid primary key default gen_random_uuid(),
  door_id uuid not null references public.doors(id) on delete cascade,
  visitor_alias text,
  source_token_hash text,
  status text not null default 'pending' check (status in ('pending','answered','closed','missed')),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  ring_id uuid not null references public.rings(id) on delete cascade,
  sender_type text not null check (sender_type in ('visitor','owner','shared_user','system')),
  sender_user_id uuid references public.users(id) on delete set null,
  message_text text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.door_share_tokens (
  id uuid primary key default gen_random_uuid(),
  door_id uuid not null references public.doors(id) on delete cascade,
  token_hash text not null unique,
  pin_hash text,
  expires_at timestamptz not null,
  max_uses int not null default 1,
  used_count int not null default 0,
  revoked_at timestamptz,
  created_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.door_shared_users (
  id uuid primary key default gen_random_uuid(),
  door_id uuid not null references public.doors(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  permission text not null default 'notify_chat' check (permission in ('notify_chat','notify_chat_unlock')),
  granted_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(door_id, user_id)
);

-- Future hardware tables
create table if not exists public.door_devices (
  id uuid primary key default gen_random_uuid(),
  door_id uuid not null references public.doors(id) on delete cascade,
  device_name text not null,
  device_identifier text not null unique,
  device_token_hash text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.device_heartbeats (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.door_devices(id) on delete cascade,
  status text not null default 'online' check (status in ('online','degraded','offline')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.door_unlock_requests (
  id uuid primary key default gen_random_uuid(),
  door_id uuid not null references public.doors(id) on delete cascade,
  requested_by uuid not null references public.users(id) on delete cascade,
  reason text,
  state text not null default 'pending' check (state in ('pending','claimed','success','failed','timeout','cancelled')),
  expires_at timestamptz not null,
  claimed_by_device_id uuid references public.door_devices(id) on delete set null,
  idempotency_key text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.door_unlock_logs (
  id uuid primary key default gen_random_uuid(),
  unlock_request_id uuid not null references public.door_unlock_requests(id) on delete cascade,
  door_id uuid not null references public.doors(id) on delete cascade,
  actor_type text not null check (actor_type in ('user','device','system')),
  actor_user_id uuid references public.users(id) on delete set null,
  actor_device_id uuid references public.door_devices(id) on delete set null,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- helper function
create or replace function public.is_door_member(_door_id uuid, _user_id uuid)
returns boolean
language sql
stable
as $$
  select exists(
    select 1 from public.doors d
    where d.id = _door_id and d.owner_user_id = _user_id
  )
  or exists(
    select 1 from public.door_shared_users s
    where s.door_id = _door_id and s.user_id = _user_id
  );
$$;

alter table public.users enable row level security;
alter table public.user_push_tokens enable row level security;
alter table public.doors enable row level security;
alter table public.door_public_tokens enable row level security;
alter table public.rings enable row level security;
alter table public.chat_messages enable row level security;
alter table public.door_share_tokens enable row level security;
alter table public.door_shared_users enable row level security;
alter table public.door_devices enable row level security;
alter table public.device_heartbeats enable row level security;
alter table public.door_unlock_requests enable row level security;
alter table public.door_unlock_logs enable row level security;

-- users
create policy users_self_select on public.users for select using (id = auth.uid());
create policy users_self_upsert on public.users for all using (id = auth.uid()) with check (id = auth.uid());

-- push tokens
create policy push_own on public.user_push_tokens for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- doors: owner full access, shared read
create policy doors_owner_all on public.doors for all
using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());
create policy doors_shared_read on public.doors for select
using (exists (select 1 from public.door_shared_users s where s.door_id = id and s.user_id = auth.uid()));

-- no direct read for public token rows from clients
create policy door_public_tokens_none on public.door_public_tokens for select using (false);

-- rings visibility by membership
create policy rings_member_read on public.rings for select
using (public.is_door_member(door_id, auth.uid()));
create policy rings_member_update on public.rings for update
using (public.is_door_member(door_id, auth.uid()))
with check (public.is_door_member(door_id, auth.uid()));

-- chat visibility by ring membership
create policy chat_member_read on public.chat_messages for select
using (
  exists (
    select 1 from public.rings r
    where r.id = ring_id and public.is_door_member(r.door_id, auth.uid())
  )
);
create policy chat_member_insert on public.chat_messages for insert
with check (
  (
    sender_type in ('owner','shared_user')
    and sender_user_id = auth.uid()
    and exists (
      select 1 from public.rings r
      where r.id = ring_id and public.is_door_member(r.door_id, auth.uid())
    )
  )
);

-- share token owner-only
create policy share_tokens_owner_all on public.door_share_tokens for all
using (exists (select 1 from public.doors d where d.id = door_id and d.owner_user_id = auth.uid()))
with check (exists (select 1 from public.doors d where d.id = door_id and d.owner_user_id = auth.uid()));

-- shared users: owner manage, members read relation
create policy shared_users_owner_all on public.door_shared_users for all
using (exists (select 1 from public.doors d where d.id = door_id and d.owner_user_id = auth.uid()))
with check (exists (select 1 from public.doors d where d.id = door_id and d.owner_user_id = auth.uid()));
create policy shared_users_member_read on public.door_shared_users for select
using (public.is_door_member(door_id, auth.uid()));

-- hardware tables: owner/shared read for visibility, owner write; devices handled via service role edge function
create policy devices_member_read on public.door_devices for select
using (public.is_door_member(door_id, auth.uid()));
create policy devices_owner_write on public.door_devices for all
using (exists (select 1 from public.doors d where d.id = door_id and d.owner_user_id = auth.uid()))
with check (exists (select 1 from public.doors d where d.id = door_id and d.owner_user_id = auth.uid()));

create policy heartbeats_member_read on public.device_heartbeats for select
using (
  exists (
    select 1 from public.door_devices dv
    where dv.id = device_id and public.is_door_member(dv.door_id, auth.uid())
  )
);

create policy unlock_requests_member_read on public.door_unlock_requests for select
using (public.is_door_member(door_id, auth.uid()));
create policy unlock_requests_owner_or_priv_shared_insert on public.door_unlock_requests for insert
with check (
  requested_by = auth.uid() and (
    exists (select 1 from public.doors d where d.id = door_id and d.owner_user_id = auth.uid())
    or exists (
      select 1 from public.door_shared_users s
      where s.door_id = door_id and s.user_id = auth.uid() and s.permission = 'notify_chat_unlock'
    )
  )
);

create policy unlock_logs_member_read on public.door_unlock_logs for select
using (public.is_door_member(door_id, auth.uid()));

-- realtime publication (customize per project)
alter publication supabase_realtime add table public.rings;
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.door_unlock_requests;
