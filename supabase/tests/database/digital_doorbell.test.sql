begin;

create extension if not exists pgtap with schema extensions;
select plan(29);

select ok(
  has_table_privilege('service_role', 'public.users', 'INSERT'),
  'Service role can create application user profiles'
);
select ok(
  has_table_privilege('service_role', 'public.doors', 'DELETE'),
  'Service role can perform owner-authorized door deletion'
);
select ok(
  has_table_privilege('service_role', 'public.rings', 'SELECT'),
  'Service role can evaluate active visitor sessions'
);

select is(
  (select (features->>'push_notifications')::boolean from public.plan_definitions where id = 'free'),
  true,
  'Free includes push notifications'
);
select is(
  (select monthly_ring_limit from public.plan_definitions where id = 'free'),
  null::integer,
  'Free has no monthly ring limit'
);
select is(
  (select log_retention_count from public.plan_definitions where id = 'free'),
  3,
  'Free retains three visits'
);
select hasnt_table('public', 'door_devices', 'Hardware device table is removed');
select hasnt_table('public', 'door_unlock_requests', 'Unlock request table is removed');
select ok(
  not exists (select 1 from pg_extension where extname = 'pg_cron'),
  'Minute-level pg_cron scheduler is removed'
);
select ok(
  not exists (select 1 from pg_extension where extname = 'pg_net'),
  'Idle outbound HTTP extension is removed'
);
select ok(
  has_schema_privilege('authenticated', 'private', 'USAGE'),
  'Authenticated policies can resolve private helpers'
);
select ok(
  has_function_privilege(
    'authenticated',
    'private.can_host_view_ring(uuid, uuid)',
    'EXECUTE'
  ),
  'Authenticated RLS can execute the private ring helper'
);
select ok(
  not has_function_privilege(
    'anon',
    'private.can_host_view_ring(uuid, uuid)',
    'EXECUTE'
  ),
  'Anonymous API role cannot execute the private ring helper'
);
select ok(
  to_regprocedure('public.can_access_ring_realtime(text, boolean)') is null,
  'Realtime authorization helper is not exposed as a public RPC'
);
select ok(
  has_function_privilege(
    'authenticated',
    'private.can_access_ring_realtime(text, boolean)',
    'EXECUTE'
  ),
  'Realtime policies can execute the private authorization helper'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.increment_doorbell_media_usage(uuid, text, integer)',
    'EXECUTE'
  ),
  'Service role can atomically record media usage'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.increment_doorbell_media_usage(uuid, text, integer)',
    'EXECUTE'
  ),
  'Authenticated clients cannot alter media usage counters'
);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'pro-owner@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'free-owner@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'host-one@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'host-two@example.test'),
  ('55555555-5555-5555-5555-555555555555', 'host-three@example.test');
insert into public.users (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222'),
  ('33333333-3333-3333-3333-333333333333'),
  ('44444444-4444-4444-4444-444444444444'),
  ('55555555-5555-5555-5555-555555555555');
insert into public.doors (id, owner_user_id, label) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Pro door'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'Free door');

select lives_ok(
  $$select public.increment_doorbell_media_usage(
    '11111111-1111-1111-1111-111111111111', 'audio', 12
  )$$,
  'Media usage can be inserted atomically'
);
select is(
  (public.increment_doorbell_media_usage(
    '11111111-1111-1111-1111-111111111111', 'audio', 8
  )->>'audio_seconds')::integer,
  20,
  'Concurrent-safe upsert increments existing usage'
);

select throws_ok(
  $$insert into public.door_shared_users (door_id, user_id, granted_by) values
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111')$$,
  'P0001',
  'HOST_PLAN_LIMIT',
  'Free owner cannot add another host'
);

insert into public.user_subscriptions (user_id, plan_id, status)
values ('11111111-1111-1111-1111-111111111111', 'pro', 'active');
select lives_ok(
  $$insert into public.door_shared_users (door_id, user_id, granted_by) values
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111')$$,
  'Pro permits the second total host'
);
select lives_ok(
  $$insert into public.door_shared_users (door_id, user_id, granted_by) values
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111')$$,
  'Pro permits the third total host'
);
select throws_ok(
  $$insert into public.door_shared_users (door_id, user_id, granted_by) values
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111')$$,
  'P0001',
  'HOST_PLAN_LIMIT',
  'Pro blocks a fourth total host'
);

insert into public.rings (id, door_id, status, created_at) values
  ('10000000-0000-0000-0000-000000000001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ended', now() - interval '4 hours'),
  ('10000000-0000-0000-0000-000000000002', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ended', now() - interval '3 hours'),
  ('10000000-0000-0000-0000-000000000003', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ended', now() - interval '2 hours'),
  ('10000000-0000-0000-0000-000000000004', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ended', now() - interval '1 hour');
insert into public.chat_messages (ring_id, sender_type, message_text) values
  ('10000000-0000-0000-0000-000000000001', 'system', 'old hidden message'),
  ('10000000-0000-0000-0000-000000000004', 'system', 'recent visible message');

set local role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated","is_anonymous":false}',
  true
);
select is((select count(*) from public.rings), 3::bigint, 'Free RLS exposes only the latest three visits');
select is((select count(*) from public.chat_messages), 1::bigint, 'Chat RLS follows Free visit retention');

reset role;

select ok(
  (public.consume_doorbell_rate_limit(
    'device', 'test-door-device-0001', 1, 30, 60
  )->>'allowed')::boolean,
  'First ring from a device is allowed'
);
select ok(
  not (public.consume_doorbell_rate_limit(
    'device', 'test-door-device-0001', 1, 30, 60
  )->>'allowed')::boolean,
  'Immediate second ring from the same device is blocked'
);
update public.ring_rate_limits
   set window_start = now() - interval '2 minutes'
 where scope_type = 'device'
   and scope_key = 'test-door-device-0001';
select ok(
  not (public.consume_doorbell_rate_limit(
    'device', 'test-door-device-0001', 1, 30, 60
  )->>'allowed')::boolean,
  'Active device block survives a rate-window boundary'
);
select is(
  (select count(*) from public.ring_rate_limits
    where scope_type = 'device'
      and scope_key = 'test-door-device-0001'),
  1::bigint,
  'Rate-limit storage remains bounded to one row per scope'
);

select * from finish();
rollback;
