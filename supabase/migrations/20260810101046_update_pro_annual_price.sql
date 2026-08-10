update public.plan_definitions
set annual_price_usd_cents = 1499,
    updated_at = now()
where id = 'pro';
