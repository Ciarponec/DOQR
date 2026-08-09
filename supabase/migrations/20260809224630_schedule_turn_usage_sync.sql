create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

create or replace function private.enqueue_turn_usage_sync()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  cron_secret text;
  request_id bigint;
begin
  select decrypted_secret
    into cron_secret
    from vault.decrypted_secrets
   where name = 'doqr_turn_usage_cron_secret'
   limit 1;

  -- Local development and a newly restored project may not have the Vault
  -- secret yet. In that case the scheduled job safely becomes a no-op.
  if cron_secret is null or length(cron_secret) < 32 then
    return null;
  end if;

  select net.http_post(
    url := 'https://warsaqcfovasaitcwtxy.supabase.co/functions/v1/turn-usage-sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', cron_secret
    ),
    body := jsonb_build_object(
      'trigger', 'pg_cron',
      'requested_at', now()
    ),
    timeout_milliseconds := 10000
  ) into request_id;

  return request_id;
end;
$$;

revoke all on function private.enqueue_turn_usage_sync() from public, anon, authenticated;

select cron.schedule(
  'doqr-turn-usage-sync',
  '* * * * *',
  $job$select private.enqueue_turn_usage_sync();$job$
);
