-- Cache auth helpers once per statement and merge equivalent permissive
-- policies so participant reads stay fast as the ring history grows.

alter policy share_tokens_owner_all on public.door_share_tokens
using (
  exists (
    select 1
    from public.doors d
    where d.id = door_share_tokens.door_id
      and d.owner_user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.doors d
    where d.id = door_share_tokens.door_id
      and d.owner_user_id = (select auth.uid())
  )
);

alter policy users_permanent_self_select on public.users
using (
  (select auth.uid()) = id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
);
alter policy users_permanent_self_insert on public.users
with check (
  (select auth.uid()) = id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
);
alter policy users_permanent_self_update on public.users
using (
  (select auth.uid()) = id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
)
with check (
  (select auth.uid()) = id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
);

alter policy push_tokens_own_insert on public.user_push_tokens
with check (
  (select auth.uid()) = user_id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
);
alter policy push_tokens_own_update on public.user_push_tokens
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
);

alter policy doors_owner_insert on public.doors
with check (
  (select auth.uid()) = owner_user_id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
);

alter policy subscriptions_own_select on public.user_subscriptions
using (
  (select auth.uid()) = user_id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
);
alter policy usage_own_select on public.usage_monthly
using (
  (select auth.uid()) = user_id
  and coalesce(
    (((select auth.jwt()) ->> 'is_anonymous')::boolean),
    false
  ) is false
);

drop policy chat_host_select on public.chat_messages;
drop policy chat_visitor_select on public.chat_messages;
create policy chat_participant_select
on public.chat_messages for select to authenticated
using (
  exists (
    select 1
    from public.rings r
    where r.id = chat_messages.ring_id
      and (
        private.can_host_view_ring(r.id, (select auth.uid()))
        or (
          r.visitor_user_id = (select auth.uid())
          and r.session_expires_at > now()
        )
      )
  )
);

drop policy doors_owner_select on public.doors;
drop policy doors_shared_select on public.doors;
create policy doors_member_select
on public.doors for select to authenticated
using (
  owner_user_id = (select auth.uid())
  or exists (
    select 1
    from public.door_shared_users s
    where s.door_id = doors.id
      and s.user_id = (select auth.uid())
  )
);

drop policy ring_events_host_select on public.ring_events;
drop policy ring_events_visitor_select on public.ring_events;
create policy ring_events_participant_select
on public.ring_events for select to authenticated
using (
  exists (
    select 1
    from public.rings r
    where r.id = ring_events.ring_id
      and (
        private.can_host_view_ring(r.id, (select auth.uid()))
        or (
          r.visitor_user_id = (select auth.uid())
          and r.session_expires_at > now()
        )
      )
  )
);

drop policy rings_host_select on public.rings;
drop policy rings_visitor_select on public.rings;
create policy rings_participant_select
on public.rings for select to authenticated
using (
  private.can_host_view_ring(id, (select auth.uid()))
  or (
    visitor_user_id = (select auth.uid())
    and session_expires_at > now()
  )
);
