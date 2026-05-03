import { json, randomSecret, serviceClient, sha256Hex } from "../_shared/utils.ts";

async function incrScope(admin: ReturnType<typeof serviceClient>, scopeType: 'door' | 'ip' | 'token', scopeKey: string, windowStart: string) {
  const { data: existing } = await admin
    .from('ring_rate_limits')
    .select('id, attempt_count, blocked_until')
    .eq('scope_type', scopeType)
    .eq('scope_key', scopeKey)
    .eq('window_start', windowStart)
    .maybeSingle();

  if (!existing) {
    const { data } = await admin
      .from('ring_rate_limits')
      .insert({ scope_type: scopeType, scope_key: scopeKey, window_start: windowStart, attempt_count: 1 })
      .select('attempt_count, blocked_until')
      .single();
    return data;
  }

  const nextCount = existing.attempt_count + 1;
  let blockedUntil: string | null = existing.blocked_until;

  if (scopeType === 'ip' && nextCount >= 20) {
    blockedUntil = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  }
  if (scopeType === 'token' && nextCount >= 12) {
    blockedUntil = new Date(Date.now() + 5 * 60 * 1000).toISOString();
  }
  if (scopeType === 'door' && nextCount >= 30) {
    blockedUntil = new Date(Date.now() + 3 * 60 * 1000).toISOString();
  }

  const { data } = await admin
    .from('ring_rate_limits')
    .update({ attempt_count: nextCount, blocked_until: blockedUntil, updated_at: new Date().toISOString() })
    .eq('id', existing.id)
    .select('attempt_count, blocked_until')
    .single();

  return data;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const { qr_token, visitor_alias } = await req.json();
    if (!qr_token || typeof qr_token !== "string") return json(400, { error: "qr_token required" });

    const admin = serviceClient();
    const tokenHash = await sha256Hex(qr_token);

    const { data: tokenRow, error: tokenErr } = await admin
      .from('door_public_tokens')
      .select('door_id, revoked_at, expires_at')
      .eq('token_hash', tokenHash)
      .maybeSingle();

    if (tokenErr) return json(500, { error: tokenErr.message });
    if (!tokenRow) return json(404, { error: 'Invalid QR' });
    if (tokenRow.revoked_at) return json(410, { error: 'QR revoked' });
    if (tokenRow.expires_at && new Date(tokenRow.expires_at).getTime() < Date.now()) return json(410, { error: 'QR expired' });

    const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
    const ipHash = await sha256Hex(ip);

    const windowStart = new Date();
    windowStart.setSeconds(0, 0);
    const ws = windowStart.toISOString();

    const ipScope = await incrScope(admin, 'ip', ipHash, ws);
    if (ipScope?.blocked_until && new Date(ipScope.blocked_until).getTime() > Date.now()) {
      return json(429, { error: 'IP temporarily blocked due to excessive attempts' });
    }

    const tokenScope = await incrScope(admin, 'token', tokenHash, ws);
    if (tokenScope?.blocked_until && new Date(tokenScope.blocked_until).getTime() > Date.now()) {
      return json(429, { error: 'QR token temporarily throttled' });
    }

    const doorScope = await incrScope(admin, 'door', tokenRow.door_id, ws);
    if (doorScope?.blocked_until && new Date(doorScope.blocked_until).getTime() > Date.now()) {
      return json(429, { error: 'Door temporarily throttled' });
    }

    const visitorSessionToken = randomSecret(24);
    const visitorSessionHash = await sha256Hex(visitorSessionToken);
    const sessionExpiresAt = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();

    const { data: ring, error: ringErr } = await admin
      .from('rings')
      .insert({
        door_id: tokenRow.door_id,
        visitor_alias: visitor_alias ?? null,
        source_token_hash: tokenHash,
        visitor_ip_hash: ipHash,
        visitor_session_token_hash: visitorSessionHash,
        visitor_session_expires_at: sessionExpiresAt,
        status: 'pending',
      })
      .select('id, door_id, status, created_at')
      .single();

    if (ringErr) return json(500, { error: ringErr.message });

    await admin.functions.invoke('notify-ring', { body: { ring_id: ring.id } });

    return json(200, {
      ring_id: ring.id,
      door_id: ring.door_id,
      chat_session: ring.id,
      visitor_session_token: visitorSessionToken,
      visitor_session_expires_at: sessionExpiresAt,
      status: ring.status,
      created_at: ring.created_at,
    });
  } catch (e) {
    return json(500, { error: e.message ?? 'Unexpected error' });
  }
});
