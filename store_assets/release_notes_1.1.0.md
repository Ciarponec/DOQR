# DOQR 1.1.0 (10)

Release scope: iOS App Store update preparation and Google Play closed testing (Alpha). No Google Play production rollout.

## Türkçe (tr-TR)

• Türkçe, İngilizce ve Rusça dil desteği.
• Daha anlaşılır açıklamalar ve hata mesajları.
• Şifre yenileme, QR kodunu yenileme ve erişim yönetimi iyileştirmeleri.
• Erişilebilirlik, görüşme kararlılığı ve güvenlik iyileştirmeleri.

## English (en-US)

• Turkish, English and Russian language support.
• Clearer instructions and error messages.
• Improved password recovery, QR code renewal and access management.
• Accessibility, call stability and security improvements.

## Русский (ru-RU)

• Поддержка турецкого, английского и русского языков.
• Более понятные инструкции и сообщения об ошибках.
• Улучшены восстановление пароля, обновление QR-кода и управление доступом.
• Улучшены доступность, стабильность звонков и безопасность.

## Release safeguards

- Version and build number are maintained in `flutter_app/pubspec.yaml`.
- Codemagic uses the validated Flutter 3.44.4 toolchain and the existing Apple signing integration.
- The iOS workflow uploads to App Store Connect without automatically submitting App Review or releasing publicly.
- Android must be signed with the existing DOQR upload key; never commit signing credentials or binaries.
