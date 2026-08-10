# App Store Connect — App Privacy cevapları

## Genel

- Uygulama veya üçüncü taraf ortaklar veri topluyor mu? `Evet`
- Veriler takip amacıyla kullanılıyor mu? `Hayır`
- Kullanıcılar veya cihazlar başka şirketlerin uygulama/site verileriyle izleniyor mu? `Hayır`
- Reklam veya üçüncü taraf reklam SDK'sı var mı? `Hayır`

## Beyan edilecek veri türleri

| App Store veri türü | Kullanıcıya bağlı | Takip | Amaç | DOQR karşılığı |
|---|---:|---:|---|---|
| Contact Info → Email Address | Evet | Hayır | App Functionality | Host hesabı ve doğrulama |
| Contact Info → Physical Address | Evet | Hayır | App Functionality | İsteğe bağlı zil/adres açıklaması |
| User Content → Emails or Text Messages | Evet | Hayır | App Functionality | Ziyaretçi-host yazılı görüşmeleri |
| User Content → Other User Content | Evet | Hayır | App Functionality | Zil adları, kurye notları ve teslimat bilgileri |
| Identifiers → User ID | Evet | Hayır | App Functionality | Supabase hesap kimliği |
| Identifiers → Device ID | Evet | Hayır | App Functionality | FCM/APNs bildirim tokenı |
| Purchases → Purchase History | Evet | Hayır | App Functionality | Ürün kimliği, abonelik durumu ve bitiş tarihi |
| Usage Data → Product Interaction | Evet | Hayır | App Functionality | Zil, ziyaret ve görüşme olayları |

## Toplanmayan veya App Store anlamında saklanmayan veriler

- Payment Info: Kart/banka verisi Apple tarafından işlenir; DOQR erişmez.
- Audio Data ve Photos or Videos: Ses/görüntü yalnız canlı görüşme için gerçek zamanlı iletilir, kaydedilmez veya olağan isteği karşılamak için gerekenden uzun tutulmaz.
- Precise/Coarse Location: Konum özelliği yoktur.
- Contacts: Adres defteri erişimi yoktur.
- Advertising Data: Reklam yoktur.
- Crash/Performance Diagnostics: Crash veya analitik SDK'sı yapılandırılmamıştır.

## URL'ler

- Privacy Policy: `https://ciarponec.github.io/DOQR/privacy.html`
- User Privacy Choices: `https://ciarponec.github.io/DOQR/account-deletion.html`

Bu cevaplar yayınlanan binary ve backend davranışı değiştiğinde yeniden gözden geçirilmelidir. Xcode Organizer'dan üretilen Privacy Report, `PrivacyInfo.xcprivacy` ve üçüncü taraf SDK manifestleriyle karşılaştırılmalıdır.
