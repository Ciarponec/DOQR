# Visitor Web (GitHub Pages)

Bu klasor statik ziyaretci akisi icindir.

## Yayina alma
1. Repo ayarlarindan GitHub Pages'i `main` branch `/visitor_web` klasoru olacak sekilde ac.
2. `visitor_web/chat.html` icindeki `SUPABASE_ANON_KEY` degerini proje anon key ile degistir.
3. QR koduna su formatta link koy:
   - `https://ciarponec.github.io/DOQR/?qr=<qr_token>`

## Akis
- `index.html`: `qr-ring-create` cagirir.
- Basarili olursa `chat.html` sayfasina `ring_id` + `visitor_session_token` ile gecer.
- `chat.html`: `visitor-chat-send` ile mesaj yollar, realtime ile owner mesajlarini gorur.
