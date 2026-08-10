import {
  errorResponse,
  json,
  options,
  requirePermanentUser,
  serviceClient,
} from "../_shared/utils.ts";

Deno.serve(async (req) => {
  const preflight = options(req);
  if (preflight) return preflight;
  try {
    if (req.method !== "POST") {
      return json(405, { error: "Method not allowed" }, req);
    }
    const user = await requirePermanentUser(
      req.headers.get("Authorization") ?? undefined,
    );
    const admin = serviceClient();

    // Records owned through public.users are removed by FK cascades. Messages
    // and audit rows authored in a shared door are deleted explicitly before
    // the auth identity is removed.
    const { error: messageError } = await admin
      .from("chat_messages")
      .delete()
      .eq("sender_user_id", user.id);
    if (messageError) throw new Error(messageError.message);

    const { error: auditError } = await admin
      .from("audit_events")
      .delete()
      .eq("actor_user_id", user.id);
    if (auditError) throw new Error(auditError.message);

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw new Error(deleteError.message);

    return json(200, { deleted: true }, req);
  } catch (error) {
    return errorResponse(error, req);
  }
});
