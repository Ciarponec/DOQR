# DOQR 1.1.1 (11)

Google Play closed testing — existing Alpha track.

## Türkçe (tr-TR)

• İlk kullanım açıklamaları yenilendi, kayıtsız deneme daha görünür hale getirildi.
• E-posta doğrulamasına devam etme ve bağlantıyı yeniden isteme kolaylaştırıldı.
• E-posta bulunamadığında spam klasörü için yönlendirme eklendi.
• Doğrulama ve parola sıfırlama e-postaları uygulamada seçilen dilde gönderilir.

## English (en-US)

• Clearer first-use instructions and a more visible option to try without an account.
• Easier email verification recovery and link resending.
• Added guidance to check the spam folder for missing emails.
• Verification and password reset emails use the language selected in the app.

## Русский (ru-RU)

• Улучшены инструкции при первом запуске и видимость пробного режима без регистрации.
• Упрощены подтверждение почты и повторная отправка ссылки.
• Добавлена подсказка проверить папку «Спам», если письмо не найдено.
• Письма подтверждения и сброса пароля отправляются на выбранном в приложении языке.

## Build verification — 2026-09-21

- Release source: `9d2e899` (application changes: `775dcf5`).
- Application validation: 38 Flutter tests, clean Flutter analysis, 36 auth email template cases. [Application CI](https://github.com/Ciarponec/DOQR/actions/runs/35648119125) passed all Flutter, auth email and database jobs.
- `flutter build appbundle --release` succeeded using the existing Android release signing configuration.
- Bundletool validation passed: package `com.doqr.app`, version `1.1.1` (11), minimum SDK 24, target SDK 36.
- AAB signature verified and its upload certificate SHA-256 matches release 1.1.0 (10): `31:66:78:61:C6:0D:B5:DA:90:85:EF:8B:40:3C:78:1C:B1:C7:5D:16:8D:68:85:2C:D2:A4:1B:40:E0:ED:C1:27`.
- Local artifact: `flutter_app/build/app/outputs/bundle/release/DOQR-1.1.1-11-release.aab` (81,659,426 bytes).
- AAB SHA-256: `cb0f44a64817e2889145e7222974dc23cae9d72be64b6b9d53c5df9ad00de2e3`.
- The existing process-scoped `jdk.net.unixdomain.tmpdir` workaround was used. No signing credentials or binaries are committed.
- [Release source CI](https://github.com/Ciarponec/DOQR/actions/runs/35649958216) also passed after the version bump.

## Google Play submission

- The signed AAB was accepted in the existing Closed testing — Alpha track, with its ReTrace mapping file and native debug symbols.
- The release preview reported no loss of supported devices and accepted release notes in Turkish, English and Russian.
- Release: `DOQR 1.1.1 (11) – Alpha`; full rollout to the existing test track.
- Existing tester, country and production settings were retained.
- The single Alpha update was submitted for review. Publishing overview confirmed **Changes in review**, with Google's quick checks still running before review proceeds. The update was not yet available to testers at this handoff.
- [Publishing overview](https://play.google.com/console/u/0/developers/4770544674252057574/app/4974415141501792540/publishing).
