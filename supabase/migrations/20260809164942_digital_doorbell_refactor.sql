-- DOQR digital doorbell refactor
-- Host: authenticated Flutter app. Visitor: anonymous Supabase Auth session in a web browser.

create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Hardware is intentionally outside the first product phase.
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'door_unlock_requests'
  ) then
    alter publication supabase_realtime drop table public.door_unlock_requests;
  end if;
end
$$;

drop table if exists public.door_unlock_logs cascade;
drop table if exists public.door_unlock_requests cascade;
drop table if exists public.device_heartbeats cascade;
drop table if exists public.door_devices cascade;

alter table public.ring_rate_limits
  drop constraint if exists ring_rate_limits_scope_type_check;
alter table public.ring_rate_limits
  add constraint ring_rate_limits_scope_type_check
  check (scope_type in ('door', 'ip', 'token', 'device'));

-- Sharing remains useful for Pro multi-host access, but no longer carries unlock rights.
update public.door_shared_users
set permission = 'notify_chat'
where permission <> 'notify_chat';

alter table public.door_shared_users
  drop constraint if exists door_shared_users_permission_check;
alter table public.door_shared_users
  add constraint door_shared_users_permission_check
  check (permission = 'notify_chat');

create table if not exists public.plan_definitions (
  id text primary key,
  display_name text not null,
  annual_price_usd_cents integer not null default 0 check (annual_price_usd_cents >= 0),
  max_doors integer not null check (max_doors > 0),
  max_hosts_per_door integer not null check (max_hosts_per_door > 0),
  monthly_ring_limit integer check (monthly_ring_limit is null or monthly_ring_limit > 0),
  log_retention_days integer check (log_retention_days is null or log_retention_days > 0),
  log_retention_count integer check (log_retention_count is null or log_retention_count > 0),
  monthly_audio_seconds integer not null default 0 check (monthly_audio_seconds >= 0),
  monthly_video_seconds integer not null default 0 check (monthly_video_seconds >= 0),
  features jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.plan_definitions (
  id, display_name, annual_price_usd_cents, max_doors, max_hosts_per_door,
  monthly_ring_limit, log_retention_days, log_retention_count, monthly_audio_seconds,
  monthly_video_seconds, features
)
values
  (
    'free', 'Free', 0, 1, 1, null, null, 3, 0, 0,
    '{"push_notifications":true,"text_chat":true,"audio_call":false,"video_call":false,"courier_notes":false,"custom_branding":false}'::jsonb
  ),
  (
    'trial', 'Pro Deneme', 0, 3, 3, null, 90, null, 1800, 900,
    '{"push_notifications":true,"text_chat":true,"audio_call":true,"video_call":true,"courier_notes":true,"custom_branding":true}'::jsonb
  ),
  (
    'pro', 'Pro', 999, 3, 3, null, 90, null, 7200, 3600,
    '{"push_notifications":true,"text_chat":true,"audio_call":true,"video_call":true,"courier_notes":true,"custom_branding":true}'::jsonb
  )
on conflict (id) do update set
  display_name = excluded.display_name,
  annual_price_usd_cents = excluded.annual_price_usd_cents,
  max_doors = excluded.max_doors,
  max_hosts_per_door = excluded.max_hosts_per_door,
  monthly_ring_limit = excluded.monthly_ring_limit,
  log_retention_days = excluded.log_retention_days,
  log_retention_count = excluded.log_retention_count,
  monthly_audio_seconds = excluded.monthly_audio_seconds,
  monthly_video_seconds = excluded.monthly_video_seconds,
  features = excluded.features,
  is_active = excluded.is_active,
  updated_at = now();

create table if not exists public.user_subscriptions (
  user_id uuid primary key references public.users(id) on delete cascade,
  plan_id text not null references public.plan_definitions(id),
  status text not null default 'active'
    check (status in ('trialing', 'active', 'past_due', 'cancelled', 'expired')),
  provider text check (provider in ('apple', 'google', 'stripe', 'manual')),
  provider_customer_id text,
  provider_subscription_id text,
  product_id text,
  current_period_end timestamptz,
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  entitlement_override jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_subscriptions
  add column if not exists trial_started_at timestamptz,
  add column if not exists trial_ends_at timestamptz;

create table if not exists public.usage_monthly (
  user_id uuid not null references public.users(id) on delete cascade,
  period_start date not null,
  ring_count integer not null default 0 check (ring_count >= 0),
  audio_seconds integer not null default 0 check (audio_seconds >= 0),
  video_seconds integer not null default 0 check (video_seconds >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, period_start)
);

-- Cloudflare TURN is disabled before the paid egress tier. Analytics is cached
-- server-side and never exposed directly to visitor or host clients.
create table if not exists public.turn_service_state (
  singleton boolean primary key default true check (singleton),
  period_start date not null,
  egress_bytes bigint not null default 0 check (egress_bytes >= 0),
  limit_bytes bigint not null default 950000000000 check (limit_bytes > 0),
  is_enabled boolean not null default false,
  disabled_reason text check (disabled_reason in ('monthly_limit', 'analytics_unavailable')),
  last_checked_at timestamptz,
  last_error text check (last_error is null or char_length(last_error) <= 500),
  updated_at timestamptz not null default now()
);

insert into public.turn_service_state (
  singleton, period_start, egress_bytes, limit_bytes, is_enabled,
  disabled_reason, last_checked_at
) values (
  true, date_trunc('month', now())::date, 0, 950000000000, false,
  'analytics_unavailable', null
) on conflict (singleton) do nothing;

create table if not exists public.turn_credentials_issued (
  username text primary key check (char_length(username) between 1 and 512),
  ring_id uuid references public.rings(id) on delete set null,
  user_id uuid not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists turn_credentials_active_idx
  on public.turn_credentials_issued (expires_at)
  where revoked_at is null;

alter table public.turn_service_state enable row level security;
alter table public.turn_credentials_issued enable row level security;
revoke all on table public.turn_service_state from public, anon, authenticated;
revoke all on table public.turn_credentials_issued from public, anon, authenticated;
grant select, insert, update, delete on table public.turn_service_state to service_role;
grant select, insert, update, delete on table public.turn_credentials_issued to service_role;

create or replace function private.enforce_door_host_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _owner_user_id uuid;
  _max_hosts integer;
  _current_hosts integer;
begin
  select d.owner_user_id into _owner_user_id
  from public.doors d where d.id = new.door_id;
  if _owner_user_id is null then raise exception 'DOOR_NOT_FOUND'; end if;
  if new.user_id = _owner_user_id then raise exception 'OWNER_ALREADY_HOST'; end if;

  select p.max_hosts_per_door into _max_hosts
  from public.plan_definitions p
  where p.id = coalesce((
    select s.plan_id from public.user_subscriptions s
    where s.user_id = _owner_user_id
      and s.status in ('trialing', 'active')
      and (s.current_period_end is null or s.current_period_end > now())
  ), 'free') and p.is_active;

  select count(*) + 1 into _current_hosts
  from public.door_shared_users shared_host
  where shared_host.door_id = new.door_id;
  if _current_hosts >= coalesce(_max_hosts, 1) then
    raise exception 'HOST_PLAN_LIMIT';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_door_host_limit() from public, anon, authenticated;
drop trigger if exists enforce_door_host_limit on public.door_shared_users;
create trigger enforce_door_host_limit
before insert on public.door_shared_users
for each row execute function private.enforce_door_host_limit();

create or replace function public.accept_door_share(
  _user_id uuid,
  _token_hash text,
  _pin_hash text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _token public.door_share_tokens%rowtype;
begin
  select * into _token
  from public.door_share_tokens token
  where token.token_hash = _token_hash
  for update;
  if _token.id is null then raise exception 'SHARE_TOKEN_INVALID'; end if;
  if _token.revoked_at is not null then raise exception 'SHARE_TOKEN_REVOKED'; end if;
  if _token.expires_at <= now() then raise exception 'SHARE_TOKEN_EXPIRED'; end if;
  if _token.pin_hash is not null and _token.pin_hash is distinct from _pin_hash then
    raise exception 'SHARE_PIN_INVALID';
  end if;
  if exists (
    select 1 from public.door_shared_users existing
    where existing.door_id = _token.door_id and existing.user_id = _user_id
  ) then
    return jsonb_build_object('door_id', _token.door_id, 'accepted', true, 'already_member', true);
  end if;
  if _token.used_count >= _token.max_uses then raise exception 'SHARE_TOKEN_USED'; end if;

  insert into public.door_shared_users (
    door_id, user_id, permission, granted_by
  ) values (
    _token.door_id, _user_id, 'notify_chat', _token.created_by
  );
  update public.door_share_tokens
  set used_count = used_count + 1
  where id = _token.id;
  return jsonb_build_object('door_id', _token.door_id, 'accepted', true, 'already_member', false);
end;
$$;
revoke all on function public.accept_door_share(uuid, text, text) from public, anon, authenticated;
grant execute on function public.accept_door_share(uuid, text, text) to service_role;

alter table public.user_push_tokens
  add column if not exists device_id text,
  add column if not exists app_version text,
  add column if not exists locale text,
  add column if not exists last_seen_at timestamptz not null default now(),
  add column if not exists disabled_at timestamptz;
delete from public.user_push_tokens older
using public.user_push_tokens newer
where older.fcm_token = newer.fcm_token
  and (
    older.updated_at < newer.updated_at
    or (older.updated_at = newer.updated_at and older.id < newer.id)
  );
alter table public.user_push_tokens
  drop constraint if exists user_push_tokens_user_id_fcm_token_key;
create unique index if not exists user_push_tokens_fcm_unique_idx
  on public.user_push_tokens (fcm_token);
create unique index if not exists user_push_tokens_user_device_idx
  on public.user_push_tokens (user_id, device_id)
  where device_id is not null;

create table if not exists public.door_settings (
  door_id uuid primary key references public.doors(id) on delete cascade,
  welcome_message text check (char_length(welcome_message) <= 280),
  text_enabled boolean not null default true,
  audio_enabled boolean not null default false,
  video_enabled boolean not null default false,
  require_visitor_name boolean not null default false,
  ring_timeout_seconds integer not null default 45 check (ring_timeout_seconds between 15 and 120),
  quiet_hours jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.door_settings (door_id)
select id from public.doors
on conflict (door_id) do nothing;

create table if not exists public.courier_notes (
  id uuid primary key default gen_random_uuid(),
  door_id uuid not null references public.doors(id) on delete cascade,
  courier_code text not null check (courier_code ~ '^[a-z0-9_-]{2,40}$'),
  courier_label text not null check (char_length(courier_label) between 2 and 80),
  title text not null default 'Teslimat notu' check (char_length(title) between 1 and 100),
  message_text text not null check (char_length(message_text) between 1 and 500),
  -- AES-GCM ciphertext; plaintext is limited to 80 characters by the Edge Function.
  delivery_code text check (char_length(delivery_code) between 1 and 512),
  active_from timestamptz,
  active_until timestamptz,
  is_active boolean not null default true,
  created_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (active_until is null or active_from is null or active_until > active_from)
);

create table if not exists public.door_blocks (
  id uuid primary key default gen_random_uuid(),
  door_id uuid not null references public.doors(id) on delete cascade,
  block_type text not null check (block_type in ('device', 'network')),
  value_hash text not null check (char_length(value_hash) = 64),
  reason text check (char_length(reason) <= 240),
  expires_at timestamptz,
  created_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (door_id, block_type, value_hash)
);
create index if not exists door_blocks_active_lookup_idx
  on public.door_blocks (door_id, block_type, value_hash, expires_at);

create unique index if not exists courier_notes_one_active_per_carrier_idx
  on public.courier_notes (door_id, courier_code)
  where is_active;
create index if not exists courier_notes_lookup_idx
  on public.courier_notes (door_id, courier_code, is_active, active_until);

-- Anonymous Auth replaces bearer secrets in URLs. Old sessions remain historical only.
alter table public.rings
  add column if not exists visitor_user_id uuid references auth.users(id) on delete set null,
  add column if not exists requested_mode text,
  add column if not exists accepted_mode text,
  add column if not exists visitor_kind text,
  add column if not exists courier_code text,
  add column if not exists client_metadata jsonb not null default '{}'::jsonb,
  add column if not exists consent_version text,
  add column if not exists session_expires_at timestamptz,
  add column if not exists answered_at timestamptz,
  add column if not exists courier_note_id uuid references public.courier_notes(id) on delete set null,
  add column if not exists visitor_device_hash text;

alter table public.rings drop constraint if exists rings_status_check;
update public.rings set status = 'accepted' where status = 'answered';
update public.rings set status = 'ended' where status = 'closed';
alter table public.rings
  add constraint rings_status_check
  check (status in ('pending', 'accepted', 'declined', 'cancelled', 'missed', 'ended'));

update public.rings set requested_mode = 'text' where requested_mode is null;
update public.rings set visitor_kind = 'guest' where visitor_kind is null;
alter table public.rings
  alter column requested_mode set default 'text',
  alter column requested_mode set not null,
  alter column visitor_kind set default 'guest',
  alter column visitor_kind set not null;
alter table public.rings
  add constraint rings_requested_mode_check check (requested_mode in ('text', 'audio', 'video')),
  add constraint rings_accepted_mode_check check (accepted_mode is null or accepted_mode in ('text', 'audio', 'video')),
  add constraint rings_visitor_kind_check check (visitor_kind in ('guest', 'courier', 'other')),
  add constraint rings_consent_required_check check (visitor_user_id is null or consent_version is not null);

alter table public.rings
  drop column if exists visitor_session_token_hash,
  drop column if exists visitor_session_expires_at;

create index if not exists rings_visitor_user_created_idx
  on public.rings (visitor_user_id, created_at desc);
create index if not exists rings_active_door_idx
  on public.rings (door_id, status, created_at desc);

alter table public.chat_messages drop constraint if exists chat_messages_sender_type_check;
alter table public.chat_messages drop constraint if exists chat_messages_sender_user_id_fkey;
update public.chat_messages set sender_type = 'host' where sender_type in ('owner', 'shared_user');
alter table public.chat_messages
  add constraint chat_messages_sender_type_check check (sender_type in ('visitor', 'host', 'system')),
  add constraint chat_messages_sender_user_id_fkey foreign key (sender_user_id) references auth.users(id) on delete set null,
  add constraint chat_messages_length_check check (char_length(message_text) between 1 and 2000);
alter table public.chat_messages
  add column if not exists client_message_id uuid;
create unique index if not exists chat_messages_idempotency_idx
  on public.chat_messages (ring_id, sender_user_id, client_message_id)
  where client_message_id is not null;

create table if not exists public.ring_events (
  id bigint generated always as identity primary key,
  ring_id uuid not null references public.rings(id) on delete cascade,
  event_type text not null check (event_type in (
    'created', 'accepted', 'declined', 'cancelled', 'missed', 'ended',
    'courier_note_revealed', 'media_started', 'media_ended', 'security'
  )),
  actor_type text not null check (actor_type in ('visitor', 'host', 'system')),
  actor_user_id uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists ring_events_ring_created_idx
  on public.ring_events (ring_id, created_at desc);
create unique index if not exists ring_events_courier_reveal_once_idx
  on public.ring_events (ring_id)
  where event_type = 'courier_note_revealed';

-- Data API access is explicit because new Supabase projects no longer auto-expose tables.
grant select on public.plan_definitions to anon, authenticated;
grant select on public.users, public.user_subscriptions, public.usage_monthly to authenticated;
grant select, insert, update, delete on public.user_push_tokens to authenticated;
grant select, insert, update, delete on public.doors, public.door_settings to authenticated;
grant select on public.rings, public.chat_messages, public.ring_events to authenticated;
grant select, insert, update, delete on public.courier_notes to authenticated;
grant select, insert, update, delete on public.door_blocks to authenticated;
grant select, insert, update, delete on public.door_shared_users, public.door_share_tokens to authenticated;

alter table public.plan_definitions enable row level security;
alter table public.user_subscriptions enable row level security;
alter table public.usage_monthly enable row level security;
alter table public.door_settings enable row level security;
alter table public.courier_notes enable row level security;
alter table public.door_blocks enable row level security;
alter table public.ring_events enable row level security;

-- Replace legacy permissive policies with participant-scoped policies.
drop policy if exists shared_users_owner_all on public.door_shared_users;
drop policy if exists shared_users_member_read on public.door_shared_users;
create policy shared_users_owner_select on public.door_shared_users for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (select 1 from public.doors d where d.id = door_shared_users.door_id and d.owner_user_id = (select auth.uid()))
);
create policy shared_users_owner_insert on public.door_shared_users for insert to authenticated
with check (exists (select 1 from public.doors d where d.id = door_shared_users.door_id and d.owner_user_id = (select auth.uid())));
create policy shared_users_owner_update on public.door_shared_users for update to authenticated
using (exists (select 1 from public.doors d where d.id = door_shared_users.door_id and d.owner_user_id = (select auth.uid())))
with check (exists (select 1 from public.doors d where d.id = door_shared_users.door_id and d.owner_user_id = (select auth.uid())));
create policy shared_users_owner_delete on public.door_shared_users for delete to authenticated
using (exists (select 1 from public.doors d where d.id = door_shared_users.door_id and d.owner_user_id = (select auth.uid())));

drop policy if exists users_self_select on public.users;
drop policy if exists users_self_upsert on public.users;
create policy users_permanent_self_select on public.users for select to authenticated
using ((select auth.uid()) = id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false);
create policy users_permanent_self_insert on public.users for insert to authenticated
with check ((select auth.uid()) = id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false);
create policy users_permanent_self_update on public.users for update to authenticated
using ((select auth.uid()) = id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false)
with check ((select auth.uid()) = id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false);

drop policy if exists push_own on public.user_push_tokens;
create policy push_tokens_own_select on public.user_push_tokens for select to authenticated
using ((select auth.uid()) = user_id);
create policy push_tokens_own_insert on public.user_push_tokens for insert to authenticated
with check ((select auth.uid()) = user_id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false);
create policy push_tokens_own_update on public.user_push_tokens for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false);
create policy push_tokens_own_delete on public.user_push_tokens for delete to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists doors_owner_all on public.doors;
drop policy if exists doors_shared_read on public.doors;
create policy doors_owner_select on public.doors for select to authenticated
using ((select auth.uid()) = owner_user_id);
create policy doors_owner_insert on public.doors for insert to authenticated
with check ((select auth.uid()) = owner_user_id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false);
create policy doors_owner_update on public.doors for update to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);
create policy doors_owner_delete on public.doors for delete to authenticated
using ((select auth.uid()) = owner_user_id);
create policy doors_shared_select on public.doors for select to authenticated
using (exists (
  select 1 from public.door_shared_users s
  where s.door_id = doors.id and s.user_id = (select auth.uid())
));

drop policy if exists rings_member_read on public.rings;
drop policy if exists rings_member_update on public.rings;
create or replace function public.can_host_view_ring(_ring_id uuid, _user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  _ring public.rings%rowtype;
  _owner_id uuid;
  _is_member boolean;
  _is_pro boolean;
begin
  if _user_id is null
    or _user_id <> auth.uid()
    or coalesce((auth.jwt()->>'is_anonymous')::boolean, false) is true then
    return false;
  end if;

  select r.*
  into _ring
  from public.rings r
  where r.id = _ring_id;
  if _ring.id is null then return false; end if;
  select d.owner_user_id into _owner_id
  from public.doors d where d.id = _ring.door_id;

  _is_member := _owner_id = _user_id or exists (
    select 1 from public.door_shared_users s
    where s.door_id = _ring.door_id and s.user_id = _user_id
  );
  if not _is_member then return false; end if;

  _is_pro := exists (
    select 1 from public.user_subscriptions s
    where s.user_id = _owner_id
      and s.plan_id in ('pro', 'trial')
      and s.status in ('trialing', 'active')
      and (s.current_period_end is null or s.current_period_end > now())
  );
  if _is_pro then
    return _ring.created_at >= now() - interval '90 days';
  end if;

  return _ring.id in (
    select recent.id
    from public.rings recent
    join public.doors recent_door on recent_door.id = recent.door_id
    where recent_door.owner_user_id = _owner_id
    order by recent.created_at desc
    limit 3
  );
end;
$$;
revoke all on function public.can_host_view_ring(uuid, uuid) from public, anon;
grant execute on function public.can_host_view_ring(uuid, uuid) to authenticated;

create policy rings_host_select on public.rings for select to authenticated
using (public.can_host_view_ring(id, (select auth.uid())));
create policy rings_visitor_select on public.rings for select to authenticated
using (
  visitor_user_id = (select auth.uid())
  and session_expires_at > now()
);

drop policy if exists chat_member_read on public.chat_messages;
drop policy if exists chat_member_insert on public.chat_messages;
create policy chat_host_select on public.chat_messages for select to authenticated
using (exists (
  select 1 from public.rings r
  where r.id = chat_messages.ring_id
    and public.can_host_view_ring(r.id, (select auth.uid()))
));
create policy chat_visitor_select on public.chat_messages for select to authenticated
using (exists (
  select 1 from public.rings r
  where r.id = chat_messages.ring_id
    and r.visitor_user_id = (select auth.uid())
    and r.session_expires_at > now()
));

create policy plans_public_select on public.plan_definitions for select to anon, authenticated
using (is_active);
create policy subscriptions_own_select on public.user_subscriptions for select to authenticated
using ((select auth.uid()) = user_id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false);
create policy usage_own_select on public.usage_monthly for select to authenticated
using ((select auth.uid()) = user_id and coalesce((select (auth.jwt()->>'is_anonymous')::boolean), false) is false);

create policy door_settings_member_select on public.door_settings for select to authenticated
using (exists (
  select 1 from public.doors d
  where d.id = door_settings.door_id
    and (
      d.owner_user_id = (select auth.uid())
      or exists (select 1 from public.door_shared_users s where s.door_id = d.id and s.user_id = (select auth.uid()))
    )
));
create policy door_settings_owner_insert on public.door_settings for insert to authenticated
with check (exists (select 1 from public.doors d where d.id = door_settings.door_id and d.owner_user_id = (select auth.uid())));
create policy door_settings_owner_update on public.door_settings for update to authenticated
using (exists (select 1 from public.doors d where d.id = door_settings.door_id and d.owner_user_id = (select auth.uid())))
with check (exists (select 1 from public.doors d where d.id = door_settings.door_id and d.owner_user_id = (select auth.uid())));

create policy courier_notes_member_select on public.courier_notes for select to authenticated
using (exists (
  select 1 from public.doors d
  where d.id = courier_notes.door_id
    and (
      d.owner_user_id = (select auth.uid())
      or exists (select 1 from public.door_shared_users s where s.door_id = d.id and s.user_id = (select auth.uid()))
    )
));
create policy courier_notes_owner_insert on public.courier_notes for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (select 1 from public.doors d where d.id = courier_notes.door_id and d.owner_user_id = (select auth.uid()))
);
create policy courier_notes_owner_update on public.courier_notes for update to authenticated
using (exists (select 1 from public.doors d where d.id = courier_notes.door_id and d.owner_user_id = (select auth.uid())))
with check (created_by = (select auth.uid()) and exists (select 1 from public.doors d where d.id = courier_notes.door_id and d.owner_user_id = (select auth.uid())));
create policy courier_notes_owner_delete on public.courier_notes for delete to authenticated
using (exists (select 1 from public.doors d where d.id = courier_notes.door_id and d.owner_user_id = (select auth.uid())));

create policy door_blocks_owner_select on public.door_blocks for select to authenticated
using (exists (select 1 from public.doors d where d.id = door_blocks.door_id and d.owner_user_id = (select auth.uid())));
create policy door_blocks_owner_insert on public.door_blocks for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (select 1 from public.doors d where d.id = door_blocks.door_id and d.owner_user_id = (select auth.uid()))
);
create policy door_blocks_owner_delete on public.door_blocks for delete to authenticated
using (exists (select 1 from public.doors d where d.id = door_blocks.door_id and d.owner_user_id = (select auth.uid())));

create policy ring_events_host_select on public.ring_events for select to authenticated
using (exists (
  select 1 from public.rings r
  where r.id = ring_events.ring_id
    and public.can_host_view_ring(r.id, (select auth.uid()))
));
create policy ring_events_visitor_select on public.ring_events for select to authenticated
using (exists (
  select 1 from public.rings r
  where r.id = ring_events.ring_id
    and r.visitor_user_id = (select auth.uid())
    and r.session_expires_at > now()
));

-- Atomic server-only usage reservation. Client-side feature hiding is never trusted.
create or replace function public.reserve_doorbell_usage(
  _owner_user_id uuid,
  _requested_mode text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _plan public.plan_definitions%rowtype;
  _period date := date_trunc('month', now())::date;
  _usage public.usage_monthly%rowtype;
begin
  if _requested_mode not in ('text', 'audio', 'video') then
    raise exception 'INVALID_MODE';
  end if;

  select p.* into _plan
  from public.plan_definitions p
  where p.id = coalesce((
    select s.plan_id
    from public.user_subscriptions s
    where s.user_id = _owner_user_id
      and s.status in ('trialing', 'active')
      and (s.current_period_end is null or s.current_period_end > now())
  ), 'free')
    and p.is_active;

  if _plan.id is null then
    raise exception 'PLAN_NOT_FOUND';
  end if;
  if _requested_mode = 'audio' and coalesce((_plan.features->>'audio_call')::boolean, false) is false then
    raise exception 'PRO_REQUIRED_AUDIO';
  end if;
  if _requested_mode = 'video' and coalesce((_plan.features->>'video_call')::boolean, false) is false then
    raise exception 'PRO_REQUIRED_VIDEO';
  end if;

  insert into public.usage_monthly (user_id, period_start)
  values (_owner_user_id, _period)
  on conflict (user_id, period_start) do nothing;

  select * into _usage
  from public.usage_monthly
  where user_id = _owner_user_id and period_start = _period
  for update;

  if _plan.monthly_ring_limit is not null and _usage.ring_count >= _plan.monthly_ring_limit then
    raise exception 'MONTHLY_RING_LIMIT';
  end if;
  if _requested_mode = 'audio'
    and _plan.monthly_audio_seconds > 0
    and _usage.audio_seconds >= _plan.monthly_audio_seconds then
    raise exception 'MONTHLY_AUDIO_LIMIT';
  end if;
  if _requested_mode = 'video'
    and _plan.monthly_video_seconds > 0
    and _usage.video_seconds >= _plan.monthly_video_seconds then
    raise exception 'MONTHLY_VIDEO_LIMIT';
  end if;

  update public.usage_monthly
  set ring_count = ring_count + 1, updated_at = now()
  where user_id = _owner_user_id and period_start = _period;

  return jsonb_build_object(
    'plan_id', _plan.id,
    'ring_count', _usage.ring_count + 1,
    'monthly_ring_limit', _plan.monthly_ring_limit,
    'features', _plan.features
  );
end;
$$;
revoke all on function public.reserve_doorbell_usage(uuid, text) from public, anon, authenticated;
grant execute on function public.reserve_doorbell_usage(uuid, text) to service_role;

create or replace function public.consume_doorbell_rate_limit(
  _scope_type text,
  _scope_key text,
  _limit integer,
  _window_seconds integer,
  _block_seconds integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _window_start timestamptz;
  _row public.ring_rate_limits%rowtype;
begin
  if _scope_type not in ('door', 'ip', 'token', 'device')
    or _limit < 1
    or _window_seconds < 1
    or _block_seconds < 1 then
    raise exception 'INVALID_RATE_LIMIT';
  end if;
  _window_start := to_timestamp(
    floor(extract(epoch from now()) / _window_seconds) * _window_seconds
  );

  insert into public.ring_rate_limits (
    scope_type, scope_key, window_start, attempt_count, blocked_until
  ) values (
    _scope_type, _scope_key, _window_start, 1, null
  )
  on conflict (scope_type, scope_key, window_start) do update
  set attempt_count = public.ring_rate_limits.attempt_count + 1,
      blocked_until = case
        when public.ring_rate_limits.attempt_count + 1 > _limit
          then greatest(
            coalesce(public.ring_rate_limits.blocked_until, now()),
            now() + make_interval(secs => _block_seconds)
          )
        else public.ring_rate_limits.blocked_until
      end,
      updated_at = now()
  returning * into _row;

  return jsonb_build_object(
    'allowed', _row.blocked_until is null or _row.blocked_until <= now(),
    'attempt_count', _row.attempt_count,
    'blocked_until', _row.blocked_until
  );
end;
$$;
revoke all on function public.consume_doorbell_rate_limit(text, text, integer, integer, integer) from public, anon, authenticated;
grant execute on function public.consume_doorbell_rate_limit(text, text, integer, integer, integer) to service_role;

-- Courier approval and message creation are one transaction, preventing duplicate delivery codes.
create or replace function public.share_courier_note_message(
  _ring_id uuid,
  _actor_user_id uuid,
  _message_text text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _message_id uuid;
begin
  if char_length(trim(_message_text)) not between 1 and 2000 then
    raise exception 'INVALID_COURIER_MESSAGE';
  end if;
  if not exists (
    select 1 from public.rings r
    where r.id = _ring_id and r.status in ('pending', 'accepted')
  ) then
    raise exception 'RING_CLOSED';
  end if;

  insert into public.ring_events (
    ring_id, event_type, actor_type, actor_user_id, metadata
  ) values (
    _ring_id, 'courier_note_revealed', 'host', _actor_user_id,
    '{"approved_by_host":true}'::jsonb
  );

  insert into public.chat_messages (
    ring_id, sender_type, sender_user_id, message_text
  ) values (
    _ring_id, 'system', _actor_user_id, trim(_message_text)
  )
  returning id into _message_id;
  return _message_id;
end;
$$;
revoke all on function public.share_courier_note_message(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.share_courier_note_message(uuid, uuid, text) to service_role;

create or replace function public.purge_doorbell_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _missed integer := 0;
  _rings_deleted integer := 0;
  _anonymous_deleted integer := 0;
begin
  update public.rings r
  set status = 'missed', closed_at = now()
  from public.door_settings s
  where r.door_id = s.door_id
    and r.status = 'pending'
    and r.created_at + make_interval(secs => s.ring_timeout_seconds) < now();
  get diagnostics _missed = row_count;

  with ranked as (
    select
      r.id,
      r.created_at,
      row_number() over (partition by d.owner_user_id order by r.created_at desc) as position,
      exists (
        select 1 from public.user_subscriptions sub
        where sub.user_id = d.owner_user_id
          and sub.plan_id in ('pro', 'trial')
          and sub.status in ('trialing', 'active')
          and (sub.current_period_end is null or sub.current_period_end > now())
      ) as is_pro
    from public.rings r
    join public.doors d on d.id = r.door_id
  ), deleted as (
    delete from public.rings target
    using ranked item
    where target.id = item.id
      and (
        (item.is_pro and item.created_at < now() - interval '90 days')
        or (not item.is_pro and item.position > 3)
      )
    returning target.id
  )
  select count(*) into _rings_deleted from deleted;

  delete from public.ring_rate_limits where window_start < now() - interval '1 day';
  delete from public.door_blocks where expires_at is not null and expires_at < now();
  delete from public.turn_credentials_issued
    where expires_at < now() - interval '1 day';
  update public.door_public_tokens set revoked_at = now()
    where revoked_at is null and expires_at is not null and expires_at < now();
  update public.door_share_tokens set revoked_at = now()
    where revoked_at is null and expires_at < now();

  delete from auth.users anonymous_user
  where anonymous_user.is_anonymous is true
    and not exists (
      select 1 from public.rings active_ring
      where active_ring.visitor_user_id = anonymous_user.id
        and active_ring.session_expires_at > now()
    )
    and coalesce((
      select max(recent_ring.created_at)
      from public.rings recent_ring
      where recent_ring.visitor_user_id = anonymous_user.id
    ), anonymous_user.created_at) < now() - interval '1 day';
  get diagnostics _anonymous_deleted = row_count;

  return jsonb_build_object(
    'missed', _missed,
    'rings_deleted', _rings_deleted,
    'anonymous_users_deleted', _anonymous_deleted,
    'completed_at', now()
  );
end;
$$;
revoke all on function public.purge_doorbell_data() from public, anon, authenticated;
grant execute on function public.purge_doorbell_data() to service_role;

-- Private ring channels carry chat notifications and WebRTC signaling.
drop policy if exists doqr_ring_receive on realtime.messages;
drop policy if exists doqr_ring_send on realtime.messages;
create policy doqr_ring_receive on realtime.messages
for select to authenticated
using (
  realtime.messages.extension in ('broadcast', 'presence')
  and exists (
    select 1 from public.rings r
    where (select realtime.topic()) = 'ring:' || r.id::text
      and (
        (r.visitor_user_id = (select auth.uid()) and r.session_expires_at > now())
        or exists (select 1 from public.doors d where d.id = r.door_id and d.owner_user_id = (select auth.uid()))
        or exists (select 1 from public.door_shared_users s where s.door_id = r.door_id and s.user_id = (select auth.uid()))
      )
  )
);
create policy doqr_ring_send on realtime.messages
for insert to authenticated
with check (
  realtime.messages.extension in ('broadcast', 'presence')
  and exists (
    select 1 from public.rings r
    where (select realtime.topic()) = 'ring:' || r.id::text
      and r.status in ('pending', 'accepted')
      and (
        (r.visitor_user_id = (select auth.uid()) and r.session_expires_at > now())
        or exists (select 1 from public.doors d where d.id = r.door_id and d.owner_user_id = (select auth.uid()))
        or exists (select 1 from public.door_shared_users s where s.door_id = r.door_id and s.user_id = (select auth.uid()))
      )
  )
);

create or replace function private.broadcast_chat_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object(
      'id', new.id,
      'ring_id', new.ring_id,
      'sender_type', new.sender_type,
      'message_text', new.message_text,
      'created_at', new.created_at
    ),
    'chat_message',
    'ring:' || new.ring_id::text,
    true
  );
  return new;
end;
$$;
revoke all on function private.broadcast_chat_message() from public, anon, authenticated;

drop trigger if exists chat_message_broadcast on public.chat_messages;
create trigger chat_message_broadcast
after insert on public.chat_messages
for each row execute function private.broadcast_chat_message();

-- Service-role inserts are used by Edge Functions; identity sequence is not client-writable.
grant usage, select on sequence public.ring_events_id_seq to service_role;
