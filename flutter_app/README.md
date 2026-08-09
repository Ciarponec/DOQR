# DOQR host uygulaması

Flutter uygulaması host hesabı, dijital zil/QR yönetimi, FCM bildirimi, yazılı görüşme, Pro WebRTC ses/video, kurye notları ve ziyaretçi engelleme akışlarını içerir. Ziyaretçi bu uygulamayı kullanmaz.

## Çalıştırma

Gerekli `--dart-define` değerleri ve platform hazırlığı için [deploy kontrol listesine](../docs/deploy_and_checklist.md) bakın.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

DOQR Free projesinin URL ve publishable key değeri uygulamada varsayılan olarak tanımlıdır. Staging veya başka bir proje için bunları `--dart-define=SUPABASE_URL=...` ve `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` ile override edebilirsiniz.

Firebase istemci yapılandırması platform dosyalarından otomatik okunur:

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`

Her iki uygulama kimliği `com.doqr.app` olarak Firebase kaydıyla eşleştirilmiştir. iOS bildirimleri için Apple Developer portalından alınan APNs `.p8` anahtarı ayrıca Firebase Cloud Messaging ayarlarına yüklenmelidir. Backend'in FCM HTTP v1 üzerinden bildirim göndermesi için Firebase service-account JSON'u yalnızca Supabase Edge Function sırrı olarak tanımlanır; uygulamaya veya repoya eklenmez.
