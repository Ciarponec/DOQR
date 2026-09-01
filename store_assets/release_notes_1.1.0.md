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

## Build verification — 2026-09-01

- Release source: `e9c0394d361a1a17ed03b0c9854671050b2219f8`.
- Local Flutter analysis passed; all 27 Flutter tests passed.
- [GitHub CI](https://github.com/Ciarponec/DOQR/actions/runs/33553273232) passed, including the Flutter and database jobs.
- [Codemagic iOS build](https://codemagic.io/app/6a7a2779c4015b3fb8825ae2/build/6a97304640ead4d604fca037) passed and uploaded version 1.1.0 (10) to App Store Connect. Apple delivery ID: `b2619009-a01b-4d45-a78f-d4ee432ec995`.
- Android `bundleRelease` passed. Bundletool validation confirmed package `com.doqr.app`, version 1.1.0 (10), minimum SDK 24 and target SDK 36.
- The AAB signature verified and matches the previous release's upload certificate.
- AAB: `flutter_app/build/app/outputs/bundle/release/DOQR-1.1.0-10-release.aab` (82,169,965 bytes).
- AAB SHA-256: `b8910ad6cdd6fe8042fa32708edaadcb7be059b0cfe9ef2cc1ff35f1e122d229`.

## Store preparation

- App Store Connect processed build 10 successfully. It is selected and saved in the 1.1.0 update draft, with manual release retained. App Review submission was not triggered.
- Turkish and English release notes/promotional text were updated; Russian App Store localization was added with Russian support and privacy links. The review notes now refer to 1.1.0 (10), with the obsolete demo-video placeholder removed.
- Google Play accepted the AAB and its bundled ReTrace mapping/native debug symbols. The Alpha release preview reported no loss of supported devices and accepted release notes in Turkish, English and Russian.
- The single Alpha update was submitted for review. At handoff, Publishing overview displayed `Changes in review`, with Google's quick checks still running before review proceeds. This is not a production release and is not yet available to testers.
- Existing Google Play countries, tester configuration and production access settings were left unchanged.

### Windows build environment

The Windows Java process initially failed before compilation with `Unable to establish loopback connection` in `UnixDomainSockets.connect0`. The release succeeded using the existing Temurin JDK 17 and a process-scoped `JAVA_TOOL_OPTIONS` value setting `jdk.net.unixdomain.tmpdir` to the project's ignored `flutter_app/build/jsock` directory. No global Java configuration, signing key or signing credentials were changed.

See the [OpenJDK explanation of the socket directory setting](https://mail.openjdk.org/pipermail/nio-dev/2023-March/013297.html). Keep the selected Flutter/Gradle toolchain pinned until a separate Kotlin/Gradle migration is tested; the build reported deprecation notices for future Gradle and Flutter versions.
