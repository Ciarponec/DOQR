# Deploy ve güvenlik kontrol listesi

Bağlı Supabase projesinin DOQR proje ref'i olduğundan emin olun. Başka bir projeye migration uygulamayın.

## 1. Yerel doğrulama

```powershell
supabase start
supabase db reset --local
deno check supabase/functions/*/index.ts
node --check visitor_web/app.js
cd flutter_app
flutter pub get
flutter analyze
flutter test
```

Docker Desktop, `supabase start` ve migration entegrasyon testi için çalışır durumda olmalıdır.

## 2. Edge Function sırları

```powershell
supabase secrets set --project-ref <project-ref> `
  SUPABASE_PUBLISHABLE_KEY=<publishable-key> `
  FIREBASE_SERVICE_ACCOUNT_JSON='<firebase-service-account-json>' `
  VISITOR_IP_HASH_SALT=<random-secret> `
  VISITOR_DEVICE_HASH_SALT=<different-random-secret> `
  VISITOR_CONSENT_VERSION=2026-08-01 `
  COURIER_NOTE_ENCRYPTION_KEY=<32-byte-base64url-key> `
  ALLOWED_ORIGINS=https://<visitor-domain> `
  CLEANUP_CRON_SECRET=<random-secret> `
  CLOUDFLARE_ACCOUNT_ID=<cloudflare-account-id> `
  CLOUDFLARE_TURN_KEY_ID=<turn-key-id> `
  CLOUDFLARE_TURN_API_TOKEN=<turn-key-api-token> `
  CLOUDFLARE_ANALYTICS_API_TOKEN=<account-analytics-read-token> `
  TURN_MONTHLY_HARD_LIMIT_GB=950 `
  TURN_USAGE_CACHE_SECONDS=300 `
  TURN_CREDENTIAL_TTL_SECONDS=600
```

`CLOUDFLARE_TURN_API_TOKEN` kısa ömürlü TURN kimliği üretme yetkisidir. `CLOUDFLARE_ANALYTICS_API_TOKEN` yalnızca Account Analytics okuma yetkisine sahip ayrı bir token olmalıdır. Bu sırlar hiçbir Flutter/web istemcisine yazılmaz. Cloudflare port 53 adresleri tarayıcıya gönderilmeden filtrelenir. Sesli görüşme TURN kimlikleri en fazla 10 dakika geçerlidir; görüntülü görüşmede süre sunucuda 60 saniyeye ve kimlik süresi kalan görüşme süresine sınırlandırılır.

TURN kullanımı yalnızca bir medya oturumu başlatılırken Cloudflare Analytics'ten sorgulanır ve Edge Function örneğinin belleğinde beş dakika tutulur. Supabase tablosuna her istek için durum veya kimlik satırı yazılmaz; boşta çalışan dakika cron'u yoktur. 950 GB kesicisi 1 TB ücretsiz kotadan 50 GB güvenlik payı bırakır ve eşik görüldüğünde yeni medya kimliği üretimini durdurur.

`SUPABASE_URL` ile service-role/secret key barındırılan Edge Runtime tarafından sağlanır. Eski projelerde gerekirse `SUPABASE_ANON_KEY` ve `SUPABASE_SERVICE_ROLE_KEY` kullanılabilir. Turnstile açılacaksa Supabase Auth CAPTCHA ayarı ile `TURNSTILE_SITE_KEY` birlikte yapılandırılmalıdır.

## 3. Backend deploy

```powershell
supabase link --project-ref <project-ref>
supabase db push --linked
supabase functions deploy --project-ref <project-ref>
```

`20260809231851_low_io_media_guard.sql` migration'ı eski dakika cron'unu, Vault sırrını, `pg_cron` ve `pg_net` uzantılarını kaldırır. Rate-limit durumu her kapsam için tek satırdır; zaman pencereleri yeni satır üretmez. Periyodik temizlik görevi kurulmaz. İşlemden sonra Supabase Database Advisors güvenlik ve performans uyarıları kontrol edilmelidir.

## 4. Visitor web

`visitor_web/index.html` içindeki `data-supabase-url` gerçek proje URL'si olmalıdır. Kaynak dosyaları `docs/` klasörüne kopyalanıp GitHub Pages `main /docs` üzerinden yayınlanır. QR formatı:

```text
https://<visitor-domain>/?qr=<one-time-generated-public-token>
```

Publishable key istemci açısından gizli değildir; yine de sayfa anahtarı `visitor-config` üzerinden alır. Service-role/secret key hiçbir istemci dosyasına konmaz.

## 5. Flutter build

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> `
  --dart-define=VISITOR_BASE_URL=https://<visitor-domain>/
```

Supabase değerleri DOQR projesi için varsayılan olarak gömülüdür; bu komuttaki ilk iki `--dart-define` yalnız farklı bir ortamı hedeflemek için gerekir. Publishable key istemciye açıktır; service-role/secret key hiçbir zaman uygulamaya eklenmez.

Firebase istemci yapılandırması `android/app/google-services.json` ile `ios/Runner/GoogleService-Info.plist` dosyalarından okunur; Firebase için `--dart-define` kullanılmaz. Android application ID ve iOS bundle ID `com.doqr.app` değerindedir. iOS için APNs `.p8` anahtarı Firebase Cloud Messaging ekranına yüklenmeli; Apple Developer hesabında bu App ID için Push Notifications yetkisi açık olmalıdır. Backend bildirimi için Firebase **Service accounts > Generate new private key** ile alınan ayrı service-account JSON'u `FIREBASE_SERVICE_ACCOUNT_JSON` sırrına koyun. Bu özel anahtar hiçbir zaman repoya veya istemci uygulamasına eklenmez. Android release imzası yayın öncesi tamamlanmalıdır.

## 6. Canlı kabul testi

1. Host kayıt olur, dijital zil ve kalıcı QR üretir.
2. İlk dijital zil oluşturulunca üç günlük Pro denemesinin bir kez başladığı ve tekrar hesap açılmadan yenilenemediği doğrulanır.
3. Deneme bittikten sonra Free host cihazında FCM; ziyaretçi tarafında yalnızca yazılı seçenek görülür.
4. Dördüncü ziyaret sonrasında Free host yalnızca son üç kaydı görür.
5. Pro/deneme hostta ses/video iki farklı ağ arasında TURN ile denenir.
6. Görüntülü görüşmenin hostun yanıtladığı andan 60 saniye sonra iki uçta da kapandığı doğrulanır.
7. Cloudflare aylık TURN kullanımı 950 GB üstündeyken `rtc-config` isteğinin reddedildiği denenir.
8. Aynı cihazın aynı kapıyı 30 saniye içinde ikinci kez çalmasının 60 saniye engellendiği doğrulanır.
9. Kurye şirketi seçiminin “doğrulanmamış beyan” olduğu ve kodun host onayından önce görünmediği doğrulanır.
10. Aynı ziyaretçi cihaz engelinden sonra yeni zil başlatamaz; ağ engeli 24 saat sonra kalkar.
11. İptal edilmiş QR, başka ring/chat verisi ve başka kapının özel Realtime kanalına erişemez.
