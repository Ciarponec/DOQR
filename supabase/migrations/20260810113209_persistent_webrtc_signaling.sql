-- WebRTC offers and answers must survive a late Realtime subscription. The
-- complete SDP (including gathered ICE candidates) is stored once per side;
-- this keeps database I/O bounded to two writes per media session.

create table if not exists public.webrtc_signals (
  ring_id uuid primary key references public.rings(id) on delete cascade,
  offer_type text not null default 'offer'
    check (offer_type = 'offer'),
  offer_sdp text not null
    check (length(offer_sdp) between 1 and 262144),
  answer_type text
    check (answer_type is null or answer_type = 'answer'),
  answer_sdp text
    check (answer_sdp is null or length(answer_sdp) between 1 and 262144),
  offer_created_at timestamptz not null default now(),
  answer_created_at timestamptz,
  check (
    (answer_sdp is null and answer_type is null and answer_created_at is null)
    or
    (answer_sdp is not null and answer_type = 'answer' and answer_created_at is not null)
  )
);

comment on table public.webrtc_signals is
  'Ephemeral per-ring WebRTC SDP mailbox; rows cascade with ring retention.';

alter table public.webrtc_signals enable row level security;

create or replace function private.is_ring_host(_ring_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth.uid() is not null
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is false
    and exists (
      select 1
      from public.rings r
      join public.doors d on d.id = r.door_id
      where r.id = _ring_id
        and (
          d.owner_user_id = auth.uid()
          or exists (
            select 1
            from public.door_shared_users s
            where s.door_id = r.door_id
              and s.user_id = auth.uid()
          )
        )
    );
$$;

create or replace function private.is_ring_visitor(
  _ring_id uuid,
  _require_active boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.rings r
    where r.id = _ring_id
      and r.visitor_user_id = auth.uid()
      and r.session_expires_at > now()
      and (
        _require_active is false
        or r.status = 'accepted'
      )
  );
$$;

revoke all on function private.is_ring_host(uuid)
from public, anon, authenticated;
revoke all on function private.is_ring_visitor(uuid, boolean)
from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_ring_host(uuid) to authenticated;
grant execute on function private.is_ring_visitor(uuid, boolean) to authenticated;

drop policy if exists webrtc_signals_participant_select
on public.webrtc_signals;
create policy webrtc_signals_participant_select
on public.webrtc_signals
for select
to authenticated
using (
  private.is_ring_host(ring_id)
  or private.is_ring_visitor(ring_id, false)
);

drop policy if exists webrtc_signals_host_insert
on public.webrtc_signals;
create policy webrtc_signals_host_insert
on public.webrtc_signals
for insert
to authenticated
with check (
  private.is_ring_host(ring_id)
  and answer_sdp is null
  and answer_type is null
  and answer_created_at is null
);

drop policy if exists webrtc_signals_visitor_answer
on public.webrtc_signals;
create policy webrtc_signals_visitor_answer
on public.webrtc_signals
for update
to authenticated
using (private.is_ring_visitor(ring_id, true))
with check (private.is_ring_visitor(ring_id, true));

revoke all on public.webrtc_signals from public, anon, authenticated;
grant select on public.webrtc_signals to authenticated;
grant insert (ring_id, offer_type, offer_sdp)
on public.webrtc_signals to authenticated;
grant update (answer_type, answer_sdp, answer_created_at)
on public.webrtc_signals to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'webrtc_signals'
  ) then
    alter publication supabase_realtime add table public.webrtc_signals;
  end if;
end;
$$;
