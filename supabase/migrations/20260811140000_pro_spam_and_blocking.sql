-- Visitor throttling and manual device/network blocking are paid safety tools.
update public.plan_definitions
set features = features || '{"spam_protection":false,"visitor_blocking":false}'::jsonb
where id = 'free';

update public.plan_definitions
set features = features || '{"spam_protection":true,"visitor_blocking":true}'::jsonb
where id in ('trial', 'pro');
