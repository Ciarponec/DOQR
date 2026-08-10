-- Realtime authorizes a private channel inside a rolled-back query. Keep the
-- policy itself small and bypass nested RLS evaluation while still deriving
-- the participant exclusively from the signed JWT.
create or replace function public.can_access_ring_realtime(
  _topic text,
  _require_active boolean
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
    where _topic = 'ring:' || r.id::text
      and (
        _require_active is false
        or r.status in ('pending', 'accepted')
      )
      and (
        (
          r.visitor_user_id = auth.uid()
          and r.session_expires_at > now()
        )
        or (
          coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is false
          and (
            exists (
              select 1
              from public.doors d
              where d.id = r.door_id
                and d.owner_user_id = auth.uid()
            )
            or exists (
              select 1
              from public.door_shared_users s
              where s.door_id = r.door_id
                and s.user_id = auth.uid()
            )
          )
        )
      )
  );
$$;

revoke all on function public.can_access_ring_realtime(text, boolean)
from public, anon, authenticated;
grant execute on function public.can_access_ring_realtime(text, boolean)
to authenticated;

drop policy if exists doqr_ring_receive on realtime.messages;
drop policy if exists doqr_ring_send on realtime.messages;

create policy doqr_ring_receive
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension in ('broadcast', 'presence')
  and public.can_access_ring_realtime(
    (select realtime.topic()),
    false
  )
);

create policy doqr_ring_send
on realtime.messages
for insert
to authenticated
with check (
  realtime.messages.extension in ('broadcast', 'presence')
  and public.can_access_ring_realtime(
    (select realtime.topic()),
    true
  )
);
