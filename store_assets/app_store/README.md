# DOQR App Store paketi

Bu klasör App Store Connect'e girilecek Türkçe/İngilizce metadata, gizlilik
cevapları, inceleme notları ve deterministik görsel çıktıları içerir.

## Dosyalar

- `metadata.tr.md`: ürün sayfası, kategori, abonelik ve inceleme metinleri.
- `metadata.en.md`: English (U.S.) ürün sayfası ve abonelik yerelleştirmesi.
- `privacy_answers.tr.md`: App Privacy beyanı için alan bazlı cevaplar.
- `submission_checklist.md`: Apple Developer ve App Store Connect işlemleri.
- `iphone-6.9-*.png`: 1290 × 2796 piksel iPhone ekran görüntüleri.
- `iphone-6.5-*.png`: 1284 × 2778 piksel iPhone ekran görüntüleri.
- `ipad-13-01-host-login.png`: 2732 × 2048 piksel iPad ekran görüntüsü.
- `doqr-app-icon-1024.png`: 1024 × 1024, opak App Store simgesi.
- `export-manifest.json`: boyut, kaynak ve SHA-256 özeti.

Görseller `scripts/generate_app_store_assets.py` ile mevcut gerçek uygulama
ekran görüntülerinden yeniden üretilebilir. Metinler ve logolar deterministik
olarak yerleştirilir; görsel üretim modeli kullanılmaz.

Apple bir ile on ekran görüntüsüne izin verir ve iPad destekleyen uygulamalar
için 13 inç iPad ekran görüntüsü ister:
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
