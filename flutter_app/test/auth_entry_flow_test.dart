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

  @override
  Stream<AuthException> get authErrors => authErrorController.stream;

  @override
  Future<void> clearPendingConfirmationEmail() async => pendingEmail = null;

  @override
  Future<String?> loadPendingConfirmationEmail() async => pendingEmail;

  @override
  Future<void> resendSignupConfirmation({required String email}) async {
    if (resendError != null) throw resendError!;
    resendCount++;
    resentEmail = email;
  }

  @override
  Future<void> savePendingConfirmationEmail(String email) async {
    pendingEmail = email;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (signInError != null) throw signInError!;
  }

  @override
  Future<bool> signUp(
          {required String email, required String password}) async =>
      false;
}

void main() {
  Future<void> pumpEntry(
    WidgetTester tester, {
    AuthGateway? authGateway,
    Duration resendCooldown = const Duration(seconds: 60),
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);
    await tester.pumpWidget(AppLanguageScope(
      controller: languageController,
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en')],
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

    expect(find.text('Host hesabına giriş yap'), findsOneWidget);
    expect(find.text('Giriş yap'), findsWidgets);
    expect(find.text('Kayıt olmadan dene'), findsOneWidget);

    await tester.tap(find.text('Hesap oluştur').first);
    await tester.pump();

    expect(find.text('Ücretsiz hesap oluştur'), findsOneWidget);
    expect(find.text('Hesabı oluştur'), findsOneWidget);
    expect(find.text('En az 8 karakter.'), findsOneWidget);
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
