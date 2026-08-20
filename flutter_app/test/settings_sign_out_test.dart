import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqr_app/l10n/app_language.dart';
import 'package:doqr_app/models/door_item.dart';
import 'package:doqr_app/screens/settings_screen.dart';

const _freePlan = PlanItem(
  id: 'free',
  displayName: 'Free',
  annualPriceUsdCents: 0,
  maxDoors: 1,
  maxHostsPerDoor: 1,
  logRetentionDays: null,
  logRetentionCount: 3,
  monthlyAudioSeconds: 0,
  monthlyVideoSeconds: 0,
  features: {},
  subscriptionStatus: 'inactive',
  currentPeriodEnd: null,
  trialEndsAt: null,
  isTrial: false,
);

void main() {
  testWidgets('çıkış tamamlanınca giriş ekranına döner', (tester) async {
    var signOutCompleted = false;
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/settings',
          routes: {
            '/': (_) => const Scaffold(body: Text('Giriş ekranı')),
            '/settings': (_) => SettingsScreen(
                  plan: _freePlan,
                  onDeleteAccount: () async {},
                  onSignOut: () async {
                    signOutCompleted = true;
                  },
                ),
          },
        ),
      ),
    );

    expect(find.text('Ayarlar'), findsOneWidget);
    await tester.tap(find.text('Çıkış yap'));
    await tester.pumpAndSettle();

    expect(signOutCompleted, isTrue);
    expect(find.text('Giriş ekranı'), findsOneWidget);
    expect(find.text('Ayarlar'), findsNothing);
  });
}
