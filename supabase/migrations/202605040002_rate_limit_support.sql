alter table public.rings
  add column if not exists visitor_ip_hash text;

create index if not exists rings_door_created_idx on public.rings(door_id, created_at desc);
create index if not exists chat_messages_ring_created_idx on public.chat_messages(ring_id, created_at desc);
