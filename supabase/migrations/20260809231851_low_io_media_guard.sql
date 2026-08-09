-- TURN usage is checked on demand only when media is requested. Remove the
-- minute-level scheduler and its network extension to keep idle database I/O
-- at zero.
do $$
declare
  target_job_id bigint;
begin
  if to_regclass('cron.job') is not null then
    select jobid into target_job_id
      from cron.job
     where jobname = 'doqr-turn-usage-sync';
    if target_job_id is not null then
      perform cron.unschedule(target_job_id);
    end if;
  end if;
end
$$;

drop function if exists private.enqueue_turn_usage_sync();
drop extension if exists pg_cron;
drop extension if exists pg_net;
delete from vault.secrets where name = 'doqr_turn_usage_cron_secret';

-- Rate-limit state is one row per scope instead of one row per time window.
-- This bounds table growth and makes a block survive window boundaries.
delete from public.ring_rate_limits older
using public.ring_rate_limits newer
where older.scope_type = newer.scope_type
  and older.scope_key = newer.scope_key
  and (older.updated_at, older.id) < (newer.updated_at, newer.id);

alter table public.ring_rate_limits
  drop constraint if exists ring_rate_limits_scope_type_scope_key_window_start_key;
drop index if exists public.ring_rate_limits_scope_idx;
alter table public.ring_rate_limits
  add constraint ring_rate_limits_scope_key_unique
  unique (scope_type, scope_key);

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
  _now timestamptz := clock_timestamp();
  _row public.ring_rate_limits%rowtype;
begin
  if _scope_type not in ('door', 'ip', 'token', 'device')
    or char_length(_scope_key) not between 8 and 256
    or _limit < 1
    or _window_seconds < 1
    or _block_seconds < 1 then
    raise exception 'INVALID_RATE_LIMIT';
  end if;

  insert into public.ring_rate_limits (
    scope_type, scope_key, window_start, attempt_count, blocked_until,
    created_at, updated_at
  ) values (
    _scope_type, _scope_key, _now, 1, null, _now, _now
  )
  on conflict (scope_type, scope_key) do update
  set attempt_count = case
        when public.ring_rate_limits.blocked_until > _now
          then public.ring_rate_limits.attempt_count + 1
        when public.ring_rate_limits.window_start
          + make_interval(secs => _window_seconds) <= _now then 1
        else public.ring_rate_limits.attempt_count + 1
      end,
      window_start = case
        when public.ring_rate_limits.blocked_until > _now
          then public.ring_rate_limits.window_start
        when public.ring_rate_limits.window_start
          + make_interval(secs => _window_seconds) <= _now then _now
        else public.ring_rate_limits.window_start
      end,
      blocked_until = case
        when public.ring_rate_limits.blocked_until > _now
          then public.ring_rate_limits.blocked_until
        when public.ring_rate_limits.window_start
          + make_interval(secs => _window_seconds) <= _now then null
        when public.ring_rate_limits.attempt_count + 1 > _limit
          then _now + make_interval(secs => _block_seconds)
        else null
      end,
      updated_at = _now
  returning * into _row;

  return jsonb_build_object(
    'allowed', _row.blocked_until is null or _row.blocked_until <= _now,
    'attempt_count', _row.attempt_count,
    'blocked_until', _row.blocked_until,
    'retry_after_seconds', case
      when _row.blocked_until > _now then
        ceil(extract(epoch from (_row.blocked_until - _now)))::integer
      else 0
    end
  );
end;
$$;

revoke all on function public.consume_doorbell_rate_limit(text, text, integer, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_doorbell_rate_limit(text, text, integer, integer, integer)
  to service_role;
