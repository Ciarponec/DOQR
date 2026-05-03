alter table public.rings
  add column if not exists visitor_session_token_hash text,
  add column if not exists visitor_session_expires_at timestamptz,
  add column if not exists visitor_last_seen_at timestamptz;

create index if not exists rings_visitor_token_hash_idx on public.rings(visitor_session_token_hash);
