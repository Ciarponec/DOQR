-- Record completed media usage with one atomic upsert. The Edge Function is
-- the only caller; public API roles cannot choose another user's counter.
create or replace function public.increment_doorbell_media_usage(
  _user_id uuid,
  _mode text,
  _seconds integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _row public.usage_monthly%rowtype;
begin
  if _mode not in ('audio', 'video') then
    raise exception 'INVALID_MEDIA_MODE';
  end if;
  if _seconds < 0 or _seconds > 7200 then
    raise exception 'INVALID_MEDIA_DURATION';
  end if;

  insert into public.usage_monthly (
    user_id, period_start, audio_seconds, video_seconds, updated_at
  ) values (
    _user_id,
    date_trunc('month', now())::date,
    case when _mode = 'audio' then _seconds else 0 end,
    case when _mode = 'video' then _seconds else 0 end,
    now()
  )
  on conflict (user_id, period_start) do update set
    audio_seconds = public.usage_monthly.audio_seconds + excluded.audio_seconds,
    video_seconds = public.usage_monthly.video_seconds + excluded.video_seconds,
    updated_at = now()
  returning * into _row;

  return jsonb_build_object(
    'period_start', _row.period_start,
    'audio_seconds', _row.audio_seconds,
    'video_seconds', _row.video_seconds
  );
end;
$$;

revoke all on function public.increment_doorbell_media_usage(uuid, text, integer)
  from public, anon, authenticated;
grant execute on function public.increment_doorbell_media_usage(uuid, text, integer)
  to service_role;
