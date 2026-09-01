# DOQR ziyaretçi webi

Bu klasör uygulama yüklemeyen ziyaretçinin statik web deneyiminin kaynak sürümüdür. Sayfa QR tokenini doğrular, güvenlik bilgilendirmesi ve açık onay alır, Supabase Anonymous Auth oturumu açar ve kapı zilini çalar. Kapı yöneticisi yazılı yanıt verebilir veya ziyaretçiden sesli/görüntülü görüşme izni isteyebilir.

Kurye şirketi ziyaretçinin doğrulanmamış beyanıdır. Cihaz verilerinden kurye tahmini yapılmaz; hazır not ve teslimat kodu kapı yöneticisinin onayı olmadan gösterilmez.

## Yerel servis

```powershell
npx serve visitor_web
```

`index.html` içindeki `data-supabase-url` hedef projeyi göstermelidir. Yayın için bu klasördeki `index.html`, `chat.html`, `app.js`, `styles.css` ve `assets/` içeriği `docs/` klasörüne eşitlenir; GitHub Pages kaynağı `main /docs` seçilir.

QR bağlantısı `https://<domain>/?qr=<token>` biçimindedir. Ham service-role anahtarı veya ziyaretçi oturum sırrı hiçbir zaman URL'ye eklenmez.
