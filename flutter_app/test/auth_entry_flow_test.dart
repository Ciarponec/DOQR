import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:doqr_app/l10n/app_language.dart';
import 'package:doqr_app/screens/auth_screen.dart';
import 'package:doqr_app/screens/demo_screen.dart';
import 'package:doqr_app/ui/app_theme.dart';

class _FakeAuthGateway implements AuthGateway {
  final authErrorController = StreamController<AuthException>.broadcast();
  int resendCount = 0;
  String? resentEmail;
  String? pendingEmail;
  AuthException? signInError;
  AuthException? resendError;
  Future<String?>? pendingEmailLoad;
  int passwordResetCount = 0;
  String? passwordResetEmail;
  String? signupLanguage;
  String? resendLanguage;
  String? resetLanguage;

  @override
  Stream<AuthException> get authErrors => authErrorController.stream;

  @override
  Future<void> clearPendingConfirmationEmail() async => pendingEmail = null;

  @override
  Future<String?> loadPendingConfirmationEmail() async =>
      pendingEmailLoad == null ? pendingEmail : await pendingEmailLoad!;

  @override
  Future<void> resendSignupConfirmation(
      {required String email, required String languageCode}) async {
    resendLanguage = languageCode;
    if (resendError != null) throw resendError!;
    resendCount++;
    resentEmail = email;
  }

  @override
  Future<void> savePendingConfirmationEmail(String email) async {
    pendingEmail = email;
  }

  @override
  Future<void> sendPasswordReset(
      {required String email, required String languageCode}) async {
    resetLanguage = languageCode;
    passwordResetCount++;
    passwordResetEmail = email;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (signInError != null) throw signInError!;
  }

  @override
  Future<bool> signUp(
      {required String email,
      required String password,
      required String languageCode}) async {
    signupLanguage = languageCode;
    return false;
  }
}

void main() {
  Future<void> pumpEntry(
    WidgetTester tester, {
    AuthGateway? authGateway,
    Duration resendCooldown = const Duration(seconds: 60),
    Locale locale = const Locale('tr'),
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final languageController = AppLanguageController(initialLocale: locale);
    addTearDown(languageController.dispose);
    await tester.pumpWidget(AppLanguageScope(
      controller: languageController,
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildDoqrTheme(),
        routes: {
          '/': (_) => AuthScreen(
                authGateway: authGateway ?? _FakeAuthGateway(),
                resendCooldown: resendCooldown,
              ),
          '/demo': (_) => const DemoScreen(),
        },
      ),
    ));
  }

  testWidgets('giriş ve kayıt modları açıkça ayrılır', (tester) async {
    await pumpEntry(tester);

    expect(find.text('Kapı yöneticisi hesabına giriş yap'), findsOneWidget);
    expect(find.text('Giriş yap'), findsWidgets);
    expect(find.text('Kayıt olmadan dene'), findsOneWidget);
    expect(
        find.widgetWithText(FilledButton, 'Kayıt olmadan dene').hitTestable(),
        findsOneWidget);
    expect(find.text('Şifremi unuttum'), findsOneWidget);

    await tester.tap(find.text('Hesap oluştur').first);
    await tester.pump();

    expect(find.text('Ücretsiz hesap oluştur'), findsOneWidget);
    expect(find.text('Hesabı oluştur'), findsOneWidget);
    expect(find.text('En az 8 karakter.'), findsOneWidget);
  });

  for (final language in ['tr', 'en', 'ru']) {
    testWidgets('kayıt ve yeniden gönderme seçilen $language dilini kullanır',
        (tester) async {
      final gateway = _FakeAuthGateway();
      await pumpEntry(tester,
          authGateway: gateway,
          locale: Locale(language),
          resendCooldown: const Duration(seconds: 1));
      await tester.ensureVisible(find.byType(ChoiceChip).at(1));
      await tester.tap(find.byType(ChoiceChip).at(1));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).at(0), 'tester@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      final submit = find.byType(FilledButton).last;
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      expect(gateway.signupLanguage, language);
      await tester.pump(const Duration(seconds: 1));

      // Rebuild in a different selected language while preserving the pending account.
      final nextLanguage = language == 'en' ? 'ru' : 'en';
      await pumpEntry(tester,
          authGateway: gateway,
          locale: Locale(nextLanguage),
          resendCooldown: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final resend =
          find.widgetWithIcon(TextButton, Icons.mark_email_unread_outlined);
      await tester.ensureVisible(resend);
      await tester.pumpAndSettle();
      await tester.tap(resend);
      await tester.pump();
      expect(gateway.resendLanguage, nextLanguage);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('parola sıfırlama seçilen İngilizce dilini gönderir',
      (tester) async {
    final gateway = _FakeAuthGateway();
    await pumpEntry(tester, authGateway: gateway, locale: const Locale('en'));
    await tester.enterText(find.byType(TextField).first, 'tester@example.com');
    final reset = find.text('Forgot password');
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pump();
    expect(gateway.resetLanguage, 'en');
  });

  testWidgets('giriş ekranı Rusça ve tutarlı gösterilir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final languageController =
        AppLanguageController(initialLocale: const Locale('ru'));
    addTearDown(languageController.dispose);
    await tester.pumpWidget(AppLanguageScope(
      controller: languageController,
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildDoqrTheme(),
        home: AuthScreen(authGateway: _FakeAuthGateway()),
      ),
    ));

    expect(find.text('Ваш дверной звонок с QR-кодом.'), findsOneWidget);
    expect(find.text('Войдите в учётную запись управляющего дверью'),
        findsOneWidget);
    expect(find.text('Управляйте дверным звонком и входящими посетителями.'),
        findsOneWidget);
    expect(find.text('Забыли пароль?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('parola sıfırlama bağlantısı istenir', (tester) async {
    final authGateway = _FakeAuthGateway();
    await pumpEntry(tester, authGateway: authGateway);
    await tester.enterText(find.byType(TextField).first, 'tester@example.com');
    await tester.ensureVisible(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pump();

    expect(authGateway.passwordResetCount, 1);
    expect(authGateway.passwordResetEmail, 'tester@example.com');
    expect(
        find.textContaining('Parola sıfırlama bağlantısını'), findsOneWidget);
  });

  testWidgets('bekleyen doğrulama yeniden açılışta geri yüklenir',
      (tester) async {
    final gateway = _FakeAuthGateway()..pendingEmail = 'tester@example.com';
    await pumpEntry(tester, authGateway: gateway);
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'tester@example.com');
    expect(find.textContaining('Doğrulanacak adres: tester@example.com'),
        findsOneWidget);
    final resend =
        find.widgetWithText(TextButton, 'Doğrulama e-postasını yeniden gönder');
    await tester.ensureVisible(resend);
    await tester.pumpAndSettle();
    await tester.tap(resend);
    await tester.pump();
    expect(gateway.resentEmail, 'tester@example.com');
    expect(gateway.resendCount, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('e-posta gelmediyse şifresiz yeniden gönderme yapılır',
      (tester) async {
    final gateway = _FakeAuthGateway();
    await pumpEntry(tester, authGateway: gateway);
    final missing = find.text('Doğrulama e-postası gelmedi mi?');
    await tester.ensureVisible(missing);
    await tester.pumpAndSettle();
    await tester.tap(missing);
    await tester.pump();
    expect(gateway.resendCount, 0);
    expect(find.textContaining('Önce kayıt olurken'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'tester@example.com');
    await tester.ensureVisible(missing);
    await tester.pumpAndSettle();
    await tester.tap(missing);
    await tester.pump();
    expect(gateway.resentEmail, 'tester@example.com');
    expect(gateway.pendingEmail, 'tester@example.com');
    expect(gateway.resendCount, 1);
    expect(find.text('60 sn sonra yeniden gönder'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bekleyen yanlış adres değiştirilebilir', (tester) async {
    final gateway = _FakeAuthGateway()..pendingEmail = 'wrong@example.com';
    await pumpEntry(tester, authGateway: gateway);
    await tester.pumpAndSettle();
    final change = find.text('Farklı e-posta kullan');
    await tester.ensureVisible(change);
    await tester.pumpAndSettle();
    await tester.tap(change);
    await tester.pump();
    expect(gateway.pendingEmail, isNull);
    await tester.enterText(find.byType(TextField).first, 'correct@example.com');
    final missing = find.text('Doğrulama e-postası gelmedi mi?');
    await tester.ensureVisible(missing);
    await tester.pumpAndSettle();
    await tester.tap(missing);
    await tester.pump();
    expect(gateway.resentEmail, 'correct@example.com');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('geç yüklenen kayıt yazılmakta olan adresi değiştirmez',
      (tester) async {
    final saved = Completer<String?>();
    final gateway = _FakeAuthGateway()..pendingEmailLoad = saved.future;
    await pumpEntry(tester, authGateway: gateway);
    await tester.enterText(find.byType(TextField).first, 'new@example.com');
    saved.complete('old@example.com');
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'new@example.com');
    expect(find.textContaining('Doğrulanacak adres:'), findsNothing);
  });

  testWidgets('yeniden gönderme sınırı çift gönderimi engeller',
      (tester) async {
    final gateway = _FakeAuthGateway()
      ..pendingEmail = 'tester@example.com'
      ..resendError =
          const AuthException('Too many requests', statusCode: '429');
    await pumpEntry(tester, authGateway: gateway);
    await tester.pumpAndSettle();
    final resend =
        find.widgetWithText(TextButton, 'Doğrulama e-postasını yeniden gönder');
    await tester.ensureVisible(resend);
    await tester.pumpAndSettle();
    await tester.tap(resend);
    await tester.pump();
    expect(find.textContaining('60 saniye bekle'), findsOneWidget);
    final waiting =
        find.widgetWithText(TextButton, '60 sn sonra yeniden gönder');
    expect(tester.widget<TextButton>(waiting).onPressed, isNull);
    expect(gateway.resendCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('demo küçük ekranda ve büyük metinde taşma yapmaz',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    await tester.pumpWidget(AppLanguageScope(
      controller: languageController,
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ru')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildDoqrTheme(),
          home: const DemoScreen(),
        ),
      ),
    ));

    expect(find.text('Kayıt olmadan örnek akış'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Örnek zili çal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Örnek zili çal'));
    await tester.pump();
    expect(find.text('Anında bildirim alırsınız'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kayıtsız deneme veri kaydetmeyen örneği açar', (tester) async {
    await pumpEntry(tester);

    await tester.tap(find.text('Kayıt olmadan dene'));
    await tester.pumpAndSettle();

    expect(find.text('Kayıt olmadan örnek akış'), findsOneWidget);
    expect(find.text('Örnek zili çal'), findsOneWidget);

    await tester.tap(find.text('Örnek zili çal'));
    await tester.pump();
    expect(find.text('Anında bildirim alırsınız'), findsOneWidget);
  });

  testWidgets('doğrulama e-postası bekleme sonrası yeniden gönderilir',
      (tester) async {
    final authGateway = _FakeAuthGateway();
    await pumpEntry(
      tester,
      authGateway: authGateway,
      resendCooldown: const Duration(seconds: 2),
    );

    await tester.tap(find.text('Hesap oluştur').first);
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), 'tester@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    final createButton = find.widgetWithText(FilledButton, 'Hesabı oluştur');
    await tester.ensureVisible(createButton);
    await tester.pumpAndSettle();
    await tester.tap(createButton);
    await tester.pump();

    expect(
      find.textContaining('Bağlantı 60 dakika geçerlidir'),
      findsOneWidget,
    );
    expect(find.text('2 sn sonra yeniden gönder'), findsOneWidget);
    expect(authGateway.resendCount, 0);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Doğrulama e-postasını yeniden gönder'), findsOneWidget);

    final resendButton =
        find.widgetWithText(TextButton, 'Doğrulama e-postasını yeniden gönder');
    await tester.ensureVisible(resendButton);
    await tester.pumpAndSettle();
    await tester.tap(resendButton);
    await tester.pump();

    expect(authGateway.resendCount, 1);
    expect(authGateway.resentEmail, 'tester@example.com');
    expect(
      find.textContaining('Doğrulama e-postası yeniden gönderildi'),
      findsOneWidget,
    );
    expect(find.text('2 sn sonra yeniden gönder'), findsOneWidget);
  });

  testWidgets('doğrulanmamış giriş yeni bağlantı istemeyi sağlar',
      (tester) async {
    final authGateway = _FakeAuthGateway()
      ..signInError = const AuthException(
        'Email not confirmed',
        code: 'email_not_confirmed',
      );
    await pumpEntry(tester, authGateway: authGateway);

    await tester.enterText(find.byType(TextField).at(0), 'tester@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    final signInButton = find.widgetWithText(FilledButton, 'Giriş yap');
    await tester.ensureVisible(signInButton);
    await tester.pumpAndSettle();
    await tester.tap(signInButton);
    await tester.pump();

    expect(find.textContaining('henüz doğrulanmamış'), findsOneWidget);
    expect(find.textContaining('60 dakika geçerlidir'), findsOneWidget);
    expect(find.text('Doğrulama e-postasını yeniden gönder'), findsOneWidget);
  });

  testWidgets('süresi geçmiş callback yeni bağlantıya yönlendirir',
      (tester) async {
    final authGateway = _FakeAuthGateway()..pendingEmail = 'tester@example.com';
    addTearDown(authGateway.authErrorController.close);
    await pumpEntry(tester, authGateway: authGateway);

    authGateway.authErrorController.add(const AuthException(
      'Email link is invalid or has expired',
      code: 'access_denied',
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('süresi geçmiş'), findsOneWidget);
    expect(find.textContaining('60 dakika geçerli'), findsOneWidget);
    expect(find.text('Doğrulama e-postasını yeniden gönder'), findsOneWidget);
  });

  testWidgets('e-posta servisi hatası ham JSON göstermeden açıklanır',
      (tester) async {
    final authGateway = _FakeAuthGateway()
      ..pendingEmail = 'tester@example.com'
      ..resendError = const AuthException(
        'Error sending confirmation email',
        code: 'unexpected_failure',
      );
    await pumpEntry(tester, authGateway: authGateway);

    authGateway.authErrorController.add(const AuthException(
      'Email link is invalid or has expired',
      code: 'access_denied',
    ));
    await tester.pumpAndSettle();
    final resendButton =
        find.widgetWithText(TextButton, 'Doğrulama e-postasını yeniden gönder');
    await tester.ensureVisible(resendButton);
    await tester.pumpAndSettle();
    await tester.tap(resendButton);
    await tester.pump();

    expect(
      find.textContaining('şu anda gönderilemedi'),
      findsOneWidget,
    );
    expect(find.textContaining('unexpected_failure'), findsNothing);
  });
}
