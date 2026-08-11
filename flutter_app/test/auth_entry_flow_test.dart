import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqr_app/l10n/app_language.dart';
import 'package:doqr_app/screens/auth_screen.dart';
import 'package:doqr_app/screens/demo_screen.dart';
import 'package:doqr_app/ui/app_theme.dart';

void main() {
  Future<void> pumpEntry(WidgetTester tester) async {
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
          '/': (_) => const AuthScreen(),
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
}
