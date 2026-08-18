# DOQR iOS / App Store gönderim kontrol listesi

## 1. Apple Developer

- [ ] `com.doqr.app` Explicit App ID oluşturuldu.
- [ ] Push Notifications capability etkin.
- [ ] Distribution certificate ve App Store provisioning profile hazır.
- [ ] APNs `.p8` anahtarı Firebase Console → Cloud Messaging'e yüklendi.
- [x] App Store Connect'te DOQR uygulaması ve sayısal Apple ID `6800038738` oluşturuldu.
- [x] `APPLE_APP_ID` Supabase secret'ına yalnız sayısal Apple ID olarak eklendi.

## 2. App Store Connect ürünü

- [x] Subscription group `DOQR Pro` oluşturuldu.
- [x] `doqr_pro_annual` ürün kimliğiyle 1 yıllık auto-renewable subscription oluşturuldu.
- [x] Türkçe ve English (U.S.) display name/description alanları girildi.
- [x] ABD fiyatı $14.99 seçildi ve 175 storefront için fiyatlar oluşturuldu.
- [x] Introductory Offer kapalı; uygulama içi 3 günlük deneme App Store satın alması değildir.
- [ ] Review screenshot olarak `iphone-6.9-03-plans.png` yüklendi.
- [ ] İlk abonelik ilk uygulama sürümüyle aynı gönderime eklendi.

## 3. App Store Server Notifications V2

- [ ] Production URL: `https://warsaqcfovasaitcwtxy.supabase.co/functions/v1/apple-store-notifications`
- [ ] Sandbox URL: aynı endpoint.
- [x] Supabase function deploy edildi ve `verify_jwt = false` ayarı uygulandı.
- [ ] App Store Connect'ten Test Notification gönderildi; HTTP 200 ve Edge Function logunda `test: true` görüldü.

## 4. Metadata ve gizlilik

- [x] Türkçe ve English (U.S.) metadata alanları App Store Connect'e girildi.
- [ ] Türkçe/İngilizce Support, Privacy ve Privacy Choices URL'leri canlı ve herkese açık.
- [ ] Privacy Policy alanında `https://ciarponec.github.io/DOQR/privacy.html` kayıtlı ve bağlantı gizli sekmede açılıyor.
- [ ] Türkçe ve English (U.S.) App Description sonuna Privacy Policy ve Apple Standard EULA bağlantıları eklendi.
- [x] `privacy_answers.tr.md` cevapları App Privacy ekranına girilip yayınlandı.
- [x] Age Rating'de Messaging and Chat = Yes; reklam, sosyal medya ve unrestricted web = No.
- [x] Uygulama 175 storefront için ücretsiz olarak fiyatlandırıldı.
- [ ] Digital Services Act trader/non-trader durumu hesap sahibi tarafından tamamlandı.
- [ ] Export compliance sorusunda yalnız standart/istisna kapsamındaki şifreleme doğru şekilde beyan edildi; `ITSAppUsesNonExemptEncryption = NO` binary içinde mevcut.

## 5. İnceleme erişimi

- [x] Ayrı, kalıcı bir review hesabı oluşturuldu ve e-postası doğrulandı.
- [x] Review hesabında en az bir örnek dijital zil ve aktif QR hazırlandı.
- [x] Hesap bilgileri ve aktif örnek QR yalnız App Store Connect'e girildi; parola/token repoya yazılmadı.
- [ ] Fiziksel Apple cihazları ve basılı QR etiketiyle uçtan uca demo videosu herkese açık bağlantıya yüklendi.
- [ ] Demo video bağlantısı App Review Information → Notes alanına ve Apple'a verilecek yanıta eklendi.
- [ ] Backend, visitor web ve FCM inceleme boyunca canlı tutulacak.

## 6. Mac üzerinde release build

- [ ] macOS'ta güncel Flutter stable kurulu.
- [ ] Xcode 26 veya daha yenisiyle iOS 26 SDK kullanılıyor (28 Nisan 2026 sonrası zorunlu).
- [ ] `cd flutter_app && flutter pub get && cd ios && pod install --repo-update` başarılı.
- [ ] `Runner.xcworkspace` açıldı; Team ve Automatic Signing seçildi.
- [ ] Release bundle ID `com.doqr.app`, version `1.0.0`, build `7` doğrulandı.
- [ ] Product → Archive → Validate App başarılı.
- [ ] Organizer Privacy Report, `privacy_answers.tr.md` ile karşılaştırıldı.
- [ ] Archive App Store Connect'e yüklendi.

## 7. Sandbox / TestFlight kabul testi

- [ ] Yeni hesap, e-posta doğrulama, giriş ve çıkış.
- [ ] Bildirim iznini reddedince uygulamanın geri kalanı kullanılabiliyor.
- [ ] APNs/FCM bildirimi foreground, background ve terminated durumda çalışıyor.
- [ ] QR tarama, yazılı zil ve cevap akışı.
- [ ] Kamera/mikrofon izinleri yalnız sesli/görüntülü görüşmede isteniyor.
- [ ] Sandbox `doqr_pro_annual` satın alımı server-side doğrulanıyor.
- [ ] Restore Purchases aynı Apple hesabında Pro erişimini geri getiriyor.
- [ ] Abonelik iptal/yenileme sandbox notification'ı backend tarihini güncelliyor.
- [ ] Hesabımı sil akışı verileri siliyor ve aboneliğin ayrıca Apple'dan iptal edilmesi gerektiğini açıklıyor.
- [ ] iPhone ve iPad'de portrait/landscape taşma testi.
- [ ] Temiz kurulumda Free hesapla `1/1 zil` durumundayken `Ekle` açıklama/Planlar akışını açıyor.
- [ ] Free hesapta `Kurye (Pro)` açıklama/Planlar akışını açıyor; kontrol tepkisiz veya disabled değil.
- [ ] iPad Air 11-inch sınıfı ekranda yukarıdaki iki kilitli özellik akışı doğrulandı.

Apple kaynakları:

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/news/?id=ueeok6yw
- https://developer.apple.com/app-store/subscriptions/
