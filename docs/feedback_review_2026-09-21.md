# İlk kullanım geri bildirimleri — 21 Eylül 2026

Kaynak: Kullanıcının paylaştığı dört yorumun ekran görüntüsü. Yorumlar ürün geri bildirimi olarak değerlendirildi. Ekran görüntüsünden kullanılan uygulama sürümü ve yorum tarihleri belirlenemiyor.

| Yorum | Değerlendirme | Öncelik | Yapılan işlem |
|---|---|---|---|
| Uygulamanın faydasını ve nasıl kullanılacağını anlayamadım. | Mevcut açılış metni QR kodunun oluşturulup kapıya konması adımını anlatmıyordu. | Yüksek | Açılışta ürünün dijital kapı zili olduğu ve QR → ziyaretçi → telefondan yanıt akışı açıklandı. Demoya hesap oluşturma, zil ekleme ve QR çıktısını kapıya asma yönergesi eklendi. |
| Love it! | Olumlu, belirli bir sorun veya değişiklik talebi içermiyor. | İşlem gerekmiyor | Mevcut akış korundu. |
| Onay e-postasını alamadım. | Kullanıcı doğrulama yüzünden ilerleyemiyor. Yeniden gönderme vardı, ancak saklanan bekleyen adres normal açılışta geri yüklenmiyordu. | Yüksek | Bekleyen doğrulama geri yükleniyor; şifre gerektirmeyen yeniden gönderme ve farklı adres kullanma seçeneği eklendi. Gerçek teslimat ayrıca kontrol edildi. |
| Kayıtsız deneme iyi; daha görünür olmalı. | Seçenek küçük bir metin düğmesiydi. | Orta | Formun üstünde, tam genişlikte ve yüksek kontrastlı düğmeye dönüştürüldü; örnek zil açıklaması eklendi. |

## E-posta kontrolünün sonucu

21 Eylül'de canlı DOQR Supabase ve Zoho yönetim panellerinden salt okunur kontrol yapıldı:

- Özel SMTP açık: `smtp.zoho.eu`, port `465`; gönderen adı DOQR, kullanıcı başına minimum aralık 60 saniye.
- Gönderen alan adında tek SPF kaydı (`include:zohomail.eu`) ve DMARC kaydı mevcut; Zoho paneli alan adını SPF ve DKIM yapılandırılmış olarak gösteriyor. Bu bilgiler her mesajın SPF/DKIM sonucunu kanıtlamaz.
- Zoho'da yorum sahibinin adıyla eşleşen Gmail adresine 20 Eylül 2026 21:29 ve 21:31'de iki gönderim görülüyor. Her ikisinin ayrıntısında Gmail alıcı sunucusu için **Delivered** yazıyor. Saatler panelde gösterildiği şekliyle kaydedildi; alıcının tam adresi bu rapora alınmadı. Log ekranında konu bilgisi olmadığı için mesaj içeriği ayrıca doğrulanmadı.
- Supabase son 24 saat Auth loglarında 21 Eylül 20:07 civarında üç `400: Email not confirmed` olayı var. Bu loglar tek başına belirli bir yorum sahibiyle eşleştirilmedi.

**Sonuç:** İncelenen iki gönderimde SMTP teslimat hatası saptanmadı. Alıcı sunucunun kabul etmesi, e-postanın ana gelen kutusunda göründüğünü veya doğrulama bağlantısının kullanıldığını kanıtlamaz. Spam/diğer sekmeler ve bağlantının kullanılma durumu alıcıyla kontrol edilmeli. SMTP, DNS veya güvenlik ayarları değiştirilmedi. Teslimat şikâyeti kesin çözüldü olarak kapatılmadı.

Kaynak paneller: [Supabase SMTP](https://supabase.com/dashboard/project/warsaqcfovasaitcwtxy/auth/smtp), [Zoho teslimat logları](https://mailadmin.zoho.eu/cpanel/reports.do#logs/mailLogs/deliveryLogs). Referans: [Supabase e-posta gönderimi](https://supabase.com/docs/guides/auth/auth-smtp), [Zoho SMTP ayarları](https://www.zoho.com/mail/help/zoho-smtp.html).

## Spam uyarısı ve e-posta dili

- Bekleyen doğrulama ekranına Spam / Gereksiz klasörünü, diğer gelen kutusu sekmelerini kontrol etme, DOQR araması yapma ve bulunan mesajı “Spam değil” olarak işaretleme açıklaması eklendi.
- Kayıt, yeniden gönderme ve parola sıfırlama istekleri uygulamada o anda seçili dili (`tr`, `en`, `ru`) iletiyor. Yeniden gönderme öncesinde dil değiştirilirse yeni dil kullanılıyor. Kayıtta dil ayrıca kullanıcı metadatasına yazılıyor.
- Doğrulama ve parola sıfırlama e-postalarının konusu, başlığı, açıklaması, butonu ve alt metinleri tek dilde oluşturuluyor. İstek üzerindeki dil kayıtlı dilden öncelikli; dil bilgisi taşımayan eski istemcilerde kayıtlı dil, o da yoksa Türkçe kullanılıyor.
- Konu şablonları Supabase panelindeki 255 karakter sınırına uyuyor. Kısa konu şablonu uygulamanın ürettiği dönüş adresinin sonundaki dil kodunu kullanıyor; gövde `email_language` işaretini kontrol ediyor. Bu nedenle istemci dönüş adresinin sonunda dil parametresini tutmalı.
- Canlı Supabase'de iki e-posta şablonu ve konu alanları güncellendi. Aynı mobil callback adresinin üç dil parametresi taşıyan biçimi izinli dönüş adreslerine eklendi. SMTP ve DNS değiştirilmedi.

## Doğrulama ve yayın durumu

- `flutter test --no-pub`: 38 test geçti. Yeni testler yeniden açılışta doğrulamayı geri getirme, şifresiz yeniden gönderme, yanlış adresi değiştirme, geç yüklenen kaydın kullanıcının girdiğini ezmemesi, gönderim sınırı, üç dilde kayıt/yeniden gönderme ve sıfırlama isteğinin dilini kapsıyor. Mevcut demo, dil ve küçük ekran testleri de geçti.
- `go run scripts/check_auth_email_templates.go`: Supabase Auth ile aynı standart Go `html/template` motorunda 36 konu/gövde senaryosu geçti; konu uzunluğu ve doğrulama bağlantısının korunması da kontrol edildi. Bu kontrol GitHub CI'a eklendi.
- `flutter analyze --no-pub`: sorun bulunmadı.
- `git diff --check` ve Dart biçim kontrolü geçti.
- Yeni metinler Türkçe, İngilizce ve Rusça sağlandı.
- Mağazaya yeni sürüm gönderilmedi. Uygulamanın dil tercihini iletmesi ve yeni açıklamaları göstermesi için yeni uygulama sürümü gerekiyor. Gerçek alıcıya test e-postası gönderilmedi; gerçek cihaza kurulmuş yeni paketle uçtan uca test yapılmadı. Rusça şablonun tarayıcı önizlemesi görsel olarak kontrol edildi.
