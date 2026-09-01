import {
  cleanText,
  errorResponse,
  HttpError,
  json,
  options,
  readJson,
  requirePermanentUser,
  serviceClient,
} from "../_shared/utils.ts";

async function requireOwner(
  admin: ReturnType<typeof serviceClient>,
  doorId: string,
  userId: string,
) {
  const { data, error } = await admin.from("doors")
    .select("id, owner_user_id").eq("id", doorId).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new HttpError(404, "Dijital zil bulunamadı", "DOOR_NOT_FOUND");
  if (data.owner_user_id !== userId) {
    throw new HttpError(403, "Bu işlem için kapı sahibi olmalısınız", "FORBIDDEN");
  }
}

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    const user = await requirePermanentUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const admin = serviceClient();

    if (req.method === "GET") {
      const doorId = cleanText(
        new URL(req.url).searchParams.get("door_id"),
        36,
        true,
      )!;
      await requireOwner(admin, doorId, user.id);
      const [{ data: members, error: memberError }, { data: invites, error: inviteError }] = await Promise.all([
        admin.from("door_shared_users")
          .select("id, user_id, created_at")
          .eq("door_id", doorId).order("created_at"),
        admin.from("door_share_tokens")
          .select("id, expires_at, max_uses, used_count, revoked_at, created_at")
          .eq("door_id", doorId).order("created_at", { ascending: false }),
      ]);
      if (memberError || inviteError) {
        throw new Error(memberError?.message ?? inviteError?.message);
      }
      const memberRows = await Promise.all((members ?? []).map(async (member) => {
        const { data } = await admin.auth.admin.getUserById(member.user_id);
        return {
          id: member.id,
          user_id: member.user_id,
          email: data.user?.email ?? null,
          created_at: member.created_at,
        };
      }));
      return json(200, {
        members: memberRows,
        invites: (invites ?? []).filter((invite) =>
          invite.revoked_at == null &&
          new Date(invite.expires_at).getTime() > Date.now() &&
          invite.used_count < invite.max_uses
        ),
      }, req);
    }

    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed", code: "METHOD_NOT_ALLOWED" }, req);
    }
    const body = await readJson<Record<string, unknown>>(req);
    const action = cleanText(body.action, 30, true)!;

    if (action === "leave") {
      const doorId = cleanText(body.door_id, 36, true)!;
      const { data, error } = await admin.from("door_shared_users").delete()
        .eq("door_id", doorId).eq("user_id", user.id).select("id").maybeSingle();
      if (error) throw new Error(error.message);
      if (!data) throw new HttpError(404, "Paylaşım kaydı bulunamadı", "MEMBERSHIP_NOT_FOUND");
      return json(200, { left: true }, req);
    }

    if (action === "remove_member") {
      const doorId = cleanText(body.door_id, 36, true)!;
      const memberUserId = cleanText(body.member_user_id, 36, true)!;
      await requireOwner(admin, doorId, user.id);
      const { data, error } = await admin.from("door_shared_users").delete()
        .eq("door_id", doorId).eq("user_id", memberUserId).select("id").maybeSingle();
      if (error) throw new Error(error.message);
      if (!data) throw new HttpError(404, "Paylaşılan kullanıcı bulunamadı", "MEMBER_NOT_FOUND");
      return json(200, { removed: true }, req);
    }

    if (action === "revoke_invite") {
      const tokenId = cleanText(body.token_id, 36, true)!;
      const { data: token, error: tokenError } = await admin.from("door_share_tokens")
        .select("id, door_id").eq("id", tokenId).maybeSingle();
      if (tokenError) throw new Error(tokenError.message);
      if (!token) throw new HttpError(404, "Davet bulunamadı", "INVITE_NOT_FOUND");
      await requireOwner(admin, token.door_id, user.id);
      const { error } = await admin.from("door_share_tokens")
        .update({ revoked_at: new Date().toISOString() }).eq("id", tokenId);
      if (error) throw new Error(error.message);
      return json(200, { revoked: true }, req);
    }

    throw new HttpError(400, "Geçersiz erişim işlemi", "VALIDATION_ERROR");
  } catch (error) {
    return errorResponse(error, req);
  }
});
