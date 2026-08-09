# DOQR

DOQR, fiziksel donanım gerektirmeyen dijital kapı zilidir. Host Flutter uygulamasını kullanır; ziyaretçi kapıdaki QR kodunu tarayıp uygulama yüklemeden web üzerinden yazılı, sesli veya görüntülü görüşme başlatır.

## Ürün modeli

| Özellik | Free | İlk 3 gün Pro deneme | Pro — yıllık $9.99 |
|---|---:|---:|---:|
| FCM zil bildirimi | ✓ | ✓ | ✓ |
| Yazılı görüşme | ✓ | ✓ | ✓ |
| Ziyaret adedi | Sınırsız | Sınırsız | Sınırsız |
| Görünen geçmiş | Son 3 ziyaret | Son 90 gün | Son 90 gün |
| Sesli / görüntülü görüşme | — | ✓ | ✓ |
| Kurye notları ve teslimat kodu | — | ✓ | ✓ |
| Dijital zil / host sayısı | 1 / 1 | 3 / zil başına 3 | 3 / zil başına 3 |

Pro medya için maliyet koruması olarak aylık 120 dakika ses ve 60 dakika video adil kullanım hakkı tanımlıdır. Üç günlük deneme hesap başına bir kez, ilk dijital zil oluşturulduğunda başlar ve toplam 30 dakika ses / 15 dakika video hakkı verir. Bu değerler `plan_definitions` üzerinden değiştirilebilir.

WebRTC doğrudan bağlantıyı önce dener; yalnızca gerektiğinde Cloudflare TURN relay kullanılır. Cloudflare aylık TURN egress kullanımı backend tarafından izlenir. 950 GB sert sınırında yeni medya oturumları kapatılır ve aktif kısa ömürlü TURN kimlikleri iptal edilir.

## Bileşenler

- `flutter_app/`: host uygulaması, FCM, görüşme yönetimi, engelleme ve kurye notları.
- `visitor_web/`: uygulamasız ziyaretçi deneyiminin kaynak dosyaları.
- `docs/`: GitHub Pages kopyası ve teknik belgeler.
- `supabase/`: Postgres migration'ları ve Edge Functions.
- `scripts/`: yerel doğrulama yardımcıları.

Mimari kararlar için [teknik plan](docs/doqr_audit_and_plan.md), kurulum için [deploy kontrol listesi](docs/deploy_and_checklist.md) kullanılmalıdır.
