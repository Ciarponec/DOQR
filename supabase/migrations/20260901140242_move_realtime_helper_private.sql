-- Realtime policies need this helper, but it should not be exposed as a
-- callable Data API RPC from the public schema.
alter function public.can_access_ring_realtime(text, boolean)
  set schema private;

revoke all on function private.can_access_ring_realtime(text, boolean)
from public, anon, authenticated;

grant usage on schema private to authenticated;
grant execute on function private.can_access_ring_realtime(text, boolean)
to authenticated;
