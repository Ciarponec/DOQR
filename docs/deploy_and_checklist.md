# Deployment + Security Checklist

## Supabase secrets (required)
```bash
supabase secrets set --project-ref wlfspfxyykdxpfhjqpkg SUPABASE_URL=https://wlfspfxyykdxpfhjqpkg.supabase.co
supabase secrets set --project-ref wlfspfxyykdxpfhjqpkg SUPABASE_ANON_KEY=YOUR_ANON_KEY
supabase secrets set --project-ref wlfspfxyykdxpfhjqpkg SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
supabase secrets set --project-ref wlfspfxyykdxpfhjqpkg FCM_SERVER_KEY=YOUR_FCM_SERVER_KEY
```

## Migrations
```bash
supabase db push --project-ref wlfspfxyykdxpfhjqpkg --include-all
```

## Functions deploy
```bash
supabase functions deploy qr-ring-create --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy visitor-chat-send --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy notify-ring --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy chat-send --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy door-share-create --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy door-share-accept --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy register-push-token --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy door-unlock-request --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy device-poll-unlock --project-ref wlfspfxyykdxpfhjqpkg
supabase functions deploy device-report-unlock --project-ref wlfspfxyykdxpfhjqpkg
```

## Live test order
1. Login from Flutter app.
2. Create/obtain a QR token row (`door_public_tokens`).
3. Use QR token in app -> `qr-ring-create`.
4. Open owner chat and visitor chat with returned session token.
5. Verify owner/shared can read `rings` + `chat_messages`.
6. Verify visitor only sends via `visitor-chat-send` (no direct table write).
7. Register push token and trigger ring notification.
8. Test share accept token flow.
9. Test unlock request + device poll/report simulation.

## Critical security checks
- No service role key in Flutter.
- `door_public_tokens` and `door_share_tokens` store only hash.
- Visitor session token expires (2 hours default).
- Unlock request TTL default 30 seconds.
- All unlock events in `door_unlock_logs`.
