# DOQR Flutter App

## Run
```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://wlfspfxyykdxpfhjqpkg.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Covered flows
- Auth (email/password)
- Owner/shared ring list
- QR token -> ring create test
- Owner/shared chat send
- Visitor anonymous chat send (session token based)
- Share token accept
- Manual unlock request trigger
