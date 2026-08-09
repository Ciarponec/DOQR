-- Security Advisor hardening for functions used by RLS.

alter function public.is_door_member(uuid, uuid)
  set search_path = '';

-- Keep the RLS helper callable by authenticated policies without exposing it
-- as a public Data API RPC.
alter function public.can_host_view_ring(uuid, uuid)
  set schema private;

revoke all on function private.enforce_door_host_limit() from public, anon, authenticated;
revoke all on function private.can_host_view_ring(uuid, uuid) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.can_host_view_ring(uuid, uuid) to authenticated;
