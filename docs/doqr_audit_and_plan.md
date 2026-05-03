# DOQR Technical Audit & Security-First MVP Scaffold

## 1) Mevcut Repo Analizi
- Klasor taramasinda (`C:\Users\Blasphemy\Desktop\DOQR`) mevcut dosya bulunmadi.
- Bu nedenle mevcut kodu iyilestirme yerine, dogrudan guvenli MVP backend iskeleti olusturuldu.
- Eklenenler:
  - `supabase/migrations/20260503_001_doqr_core.sql`
  - `supabase/functions/*` altinda Edge Function'lar

## 2) Eksikler (Mevcut Duruma Gore)
- Supabase migration yok.
- RLS politikalari yok.
- QR -> ring dogrulama ve token hash akisi yok.
- Ring bildirimi icin FCM entegrasyon katmani yok.
- Door share token/PIN akisi yok.
- Chat icin ring-bagimli yetkilendirme katmani yok.
- Gelecek donanim (device/unlock/audit) tablolari ve API iskeleti yok.

## 3) Onerilen Database Semasi
`supabase/migrations/20260503_001_doqr_core.sql` dosyasi ile eklendi.

### Core tablolar
- `users`
- `user_push_tokens`
- `doors`
- `door_public_tokens` (QR public token hash map)
- `rings`
- `chat_messages`
- `door_share_tokens`
- `door_shared_users`

### Gelecek donanim tablolari
- `door_devices`
- `door_unlock_requests`
- `door_unlock_logs`
- `device_heartbeats`

### Guvenlik
- Tum tablolarda RLS aktif.
- Yardimci fonksiyon: `is_door_member(door_id, user_id)`
- Owner/shared yetki ayrimi policy bazli.
- Public QR token tablosu dogrudan client read'e kapali.

## 4) Edge Function Listesi
Eklenen fonksiyonlar:
- `qr-ring-create`: QR token dogrular, ring olusturur, `notify-ring` tetikler.
- `notify-ring`: owner + shared user push tokenlarina FCM ring bildirimi yollar.
- `chat-send`: owner/shared user mesajini ring'e yazar.
- `door-share-create`: owner tarafinda PIN opsiyonlu paylasim tokeni uretir.
- `door-share-accept`: token + opsiyonel PIN ile paylasimi kabul eder.
- `register-push-token`: login user FCM token kaydi.
- `door-unlock-request`: gelecekteki manuel kapi acma istegi yaratir.
- `device-poll-unlock`: cihaz kimlik dogrulama + pending unlock claim.
- `device-report-unlock`: cihaz sonucu raporlar (success/failed/timeout).
- `_shared/utils.ts`: ortak auth/hash/json yardimcilari.

## 5) Flutter Entegrasyon Adimlari
Flutter istemci tarafinda `supabase_flutter` ile:

1. Auth
- Supabase Auth ile login/signup.
- Login sonrasi `register-push-token` cagrisi yap.

2. QR -> Ring
- QR icerigini `qr_token` olarak `qr-ring-create`'e POST et.
- Donen `ring_id` ile ziyaretci chat sayfasina gec.

3. Chat
- Owner/shared user mesaji icin `chat-send` cagir.
- Mesaj listesi icin `chat_messages` tablosunu `ring_id` bazli realtime dinle.

4. Ring Gecmisi
- `rings` tablosunu (RLS ile) member oldugu door'lar icin listele.

5. Door Share
- Owner `door-share-create` ile token uretir.
- Diger kullanici `door-share-accept` ile baglanir.

### Flutter invoke ornegi
```dart
final res = await Supabase.instance.client.functions.invoke(
  'qr-ring-create',
  body: {
    'qr_token': qrToken,
    'visitor_alias': visitorAlias,
  },
);
```

## 6) Raspberry/Kapi Acma Gelecek Mimarisi
- Mobilde "Kapıyı Aç" butonu -> `door-unlock-request`.
- Cihaz periyodik veya realtime `device-poll-unlock` ile pending istek claim eder.
- Role tetigi sonrasi `device-report-unlock` ile sonucu yazar.
- Her adim `door_unlock_logs`'a audit event olarak yazilir.
- `expires_at` + tek-kullanim state gecisleri replay riskini azaltir.
- `last_seen_at` + `device_heartbeats` ile offline durum UI'da gosterilir.

## 7) Kritik Guvenlik Aciklari / Notlar
- Service role key kesinlikle Flutter app'e konmamalidir.
- `door_public_tokens`/`door_share_tokens` ham token DB'de tutulmuyor, sadece hash tutuluyor.
- QR'da dogrudan `door_id` tasimamayi oneririm; yalniz token kullanin.
- Chat insert yalniz owner/shared user tarafindan ve ring-uyeligiyle sinirli.
- FCM server key sadece Edge Function env'de olmali.
- Unlock API'leri varsayilan olarak manuel tetik + audit zorunlulugu ile tasarlandi.

## 8) Sonraki Yapilacaklar (Onceliklendirilmis)
1. Supabase migration'i calistir.
2. Function deploy + env set et (`SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVER_KEY`).
3. Flutter ekranlarini bu fonksiyonlara bagla.
4. Visitor chat tarafi icin anonim/session bazli guvenli endpoint ekle (su an owner/shared yazimi hazir).
5. QR token rotate/iptal UI'si ekle.
6. Device kimlik rotasyonu ve rate limiting ekle.
