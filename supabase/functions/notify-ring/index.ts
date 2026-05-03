import { json, serviceClient } from "../_shared/utils.ts";

async function sendFcmBulk(tokens: string[], title: string, body: string, data: Record<string, string>) {
  const serverKey = Deno.env.get("FCM_SERVER_KEY");
  if (!serverKey) return { skipped: true, reason: "FCM_SERVER_KEY missing" };

  const resp = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${serverKey}`,
    },
    body: JSON.stringify({
      registration_ids: tokens,
      notification: { title, body },
      data,
      priority: "high",
    }),
  });

  const result = await resp.json();
  return { status: resp.status, result };
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") return json(405, { error: "Method not allowed" });
    const { ring_id } = await req.json();
    if (!ring_id) return json(400, { error: "ring_id required" });

    const admin = serviceClient();
    const { data: ring, error: ringErr } = await admin
      .from("rings")
      .select("id, door_id, visitor_alias, created_at")
      .eq("id", ring_id)
      .single();
    if (ringErr || !ring) return json(404, { error: "Ring not found" });

    const { data: members } = await admin
      .from("doors")
      .select("owner_user_id")
      .eq("id", ring.door_id)
      .single();

    const { data: shared } = await admin
      .from("door_shared_users")
      .select("user_id")
      .eq("door_id", ring.door_id);

    const recipientIds = new Set<string>();
    if (members?.owner_user_id) recipientIds.add(members.owner_user_id);
    for (const s of shared ?? []) recipientIds.add(s.user_id);

    const { data: fcmRows } = await admin
      .from("user_push_tokens")
      .select("fcm_token")
      .in("user_id", Array.from(recipientIds));

    const tokens = (fcmRows ?? []).map((x) => x.fcm_token);
    if (!tokens.length) return json(200, { notified: 0, message: "No tokens" });

    const sendResult = await sendFcmBulk(
      tokens,
      "DOQR Ring",
      `${ring.visitor_alias ?? "Bir ziyaretçi"} kapıda`,
      {
        type: "ring",
        ring_id: ring.id,
        door_id: ring.door_id,
      },
    );

    return json(200, { notified: tokens.length, sendResult });
  } catch (e) {
    return json(500, { error: e.message ?? "Unexpected error" });
  }
});
