-- Store purchase tokens are sensitive bearer credentials. Only their SHA-256
-- digests are persisted and this audit table is never exposed to app roles.
create table public.store_purchase_records (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  provider text not null check (provider in ('google', 'apple')),
  product_id text not null check (char_length(product_id) between 1 and 200),
  purchase_token_hash text not null check (char_length(purchase_token_hash) = 64),
  original_transaction_id text,
  store_state text not null check (char_length(store_state) between 1 and 100),
  entitlement_active boolean not null default false,
  current_period_end timestamptz,
  acknowledgement_state text,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, purchase_token_hash)
);

create index store_purchase_records_user_id_idx
  on public.store_purchase_records (user_id);

alter table public.store_purchase_records enable row level security;
alter table public.store_purchase_records force row level security;

revoke all on table public.store_purchase_records from public, anon, authenticated;
revoke all on sequence public.store_purchase_records_id_seq from public, anon, authenticated;

comment on table public.store_purchase_records is
  'Server-only audit records for verified App Store and Google Play purchases.';
