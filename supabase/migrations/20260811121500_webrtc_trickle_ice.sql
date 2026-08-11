-- Send the SDP immediately, then stream ICE candidates as they arrive. This
-- avoids holding a media call for TURN/STUN gathering (often several seconds).
create table if not exists public.webrtc_ice_candidates (
  id bigint generated always as identity primary key,
  ring_id uuid not null references public.rings(id) on delete cascade,
  sender_role text not null check (sender_role in ('host', 'visitor')),
  candidate text not null check (length(candidate) between 1 and 4096),
  sdp_mid text,
  sdp_mline_index integer,
  created_at timestamptz not null default now()
);

create index if not exists webrtc_ice_candidates_ring_id_id_idx
  on public.webrtc_ice_candidates (ring_id, id);

alter table public.webrtc_ice_candidates enable row level security;

create policy webrtc_ice_candidates_participant_select
on public.webrtc_ice_candidates
for select
to authenticated
using (
  private.is_ring_host(ring_id)
  or private.is_ring_visitor(ring_id, true)
);

create policy webrtc_ice_candidates_participant_insert
on public.webrtc_ice_candidates
for insert
to authenticated
with check (
  (sender_role = 'host' and private.is_ring_host(ring_id))
  or (sender_role = 'visitor' and private.is_ring_visitor(ring_id, true))
);

revoke all on public.webrtc_ice_candidates from public, anon, authenticated;
grant select (id, ring_id, sender_role, candidate, sdp_mid, sdp_mline_index, created_at)
  on public.webrtc_ice_candidates to authenticated;
grant insert (ring_id, sender_role, candidate, sdp_mid, sdp_mline_index)
  on public.webrtc_ice_candidates to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'webrtc_ice_candidates'
  ) then
    alter publication supabase_realtime add table public.webrtc_ice_candidates;
  end if;
end;
$$;
