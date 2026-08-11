-- A visitor rings first. The host can then answer by text or offer a media
-- call. Audio/video starts only after the visitor accepts that offer.
alter table public.rings drop constraint if exists rings_status_check;
alter table public.rings
  add constraint rings_status_check
  check (status in (
    'pending', 'media_requested', 'accepted', 'declined', 'cancelled', 'missed', 'ended'
  ));

alter table public.ring_events drop constraint if exists ring_events_event_type_check;
alter table public.ring_events
  add constraint ring_events_event_type_check
  check (event_type in (
    'created', 'accepted', 'declined', 'cancelled', 'missed', 'ended',
    'media_requested', 'media_accepted', 'media_declined',
    'courier_note_revealed', 'media_started', 'media_ended', 'security'
  ));

-- Media availability is checked when the host makes the offer, without
-- counting the same visitor ring a second time.
create or replace function public.assert_doorbell_media_available(
  _owner_user_id uuid,
  _mode text
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
  if _mode not in ('audio', 'video') then raise exception 'INVALID_MODE'; end if;

  select p.* into _plan
  from public.plan_definitions p
  where p.id = coalesce((
    select s.plan_id
    from public.user_subscriptions s
    where s.user_id = _owner_user_id
      and s.status in ('trialing', 'active')
      and (s.current_period_end is null or s.current_period_end > now())
  ), 'free') and p.is_active;

  if _plan.id is null then raise exception 'PLAN_NOT_FOUND'; end if;
  if _mode = 'audio' and coalesce((_plan.features->>'audio_call')::boolean, false) is false then
    raise exception 'PRO_REQUIRED_AUDIO';
  end if;
  if _mode = 'video' and coalesce((_plan.features->>'video_call')::boolean, false) is false then
    raise exception 'PRO_REQUIRED_VIDEO';
  end if;

  insert into public.usage_monthly (user_id, period_start)
  values (_owner_user_id, _period)
  on conflict (user_id, period_start) do nothing;

  select * into _usage
  from public.usage_monthly
  where user_id = _owner_user_id and period_start = _period
  for update;

  if _mode = 'audio' and _plan.monthly_audio_seconds > 0
    and _usage.audio_seconds >= _plan.monthly_audio_seconds then
    raise exception 'MONTHLY_AUDIO_LIMIT';
  end if;
  if _mode = 'video' and _plan.monthly_video_seconds > 0
    and _usage.video_seconds >= _plan.monthly_video_seconds then
    raise exception 'MONTHLY_VIDEO_LIMIT';
  end if;

  return jsonb_build_object('plan_id', _plan.id, 'features', _plan.features);
end;
$$;
revoke all on function public.assert_doorbell_media_available(uuid, text) from public, anon, authenticated;
grant execute on function public.assert_doorbell_media_available(uuid, text) to service_role;
