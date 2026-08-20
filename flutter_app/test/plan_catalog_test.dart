import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqr_app/l10n/app_language.dart';
import 'package:doqr_app/models/door_item.dart';
import 'package:doqr_app/models/plan_catalog.dart';
import 'package:doqr_app/screens/plans_screen.dart';
import 'package:doqr_app/ui/app_theme.dart';

void main() {
  test('Pro yıllık fiyatı 14.99 USD olarak tanımlıdır', () {
    expect(PlanCatalog.proAnnualPriceUsdCents, 1499);
    expect(PlanCatalog.proAnnualPriceLabel, r'$14.99 / yıl');
  });

  test('Free ve Pro özellikleri doğru şekilde ayrılır', () {
    expect(
      PlanCatalog.freeFeatures.any((item) => item.title.contains('görüntülü')),
      isFalse,
    );
    expect(
      PlanCatalog.proFeatures.any((item) => item.title.contains('görüntülü')),
      isTrue,
    );
    expect(
      PlanCatalog.freeFeatures.any((item) => item.title.contains('Son 3')),
      isTrue,
    );
    expect(
      PlanCatalog.proFeatures.any((item) => item.title.contains('90 günlük')),
      isTrue,
    );
  });

  testWidgets('Pro deneme durumu ve plan karşılaştırması gösterilir',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const trialPlan = PlanItem(
      id: 'trial',
      displayName: 'Pro Deneme',
      annualPriceUsdCents: 0,
      maxDoors: 3,
      maxHostsPerDoor: 3,
      logRetentionDays: 90,
      logRetentionCount: null,
      monthlyAudioSeconds: 1800,
      monthlyVideoSeconds: 900,
      features: {},
      subscriptionStatus: 'trialing',
      currentPeriodEnd: null,
      trialEndsAt: null,
      isTrial: true,
    );

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
        home: const PlansScreen(currentPlan: trialPlan),
      ),
    ));

    expect(find.text('Mevcut planın: Pro Deneme'), findsOneWidget);
    expect(find.textContaining('bir App Store aboneliği değildir'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    // The purchase UI must not hardcode a storefront price. StoreKit replaces
    // this fallback with the user's localized App Store price on device.
    expect(find.textContaining('Mağazada gösterilir'), findsWidgets);
    expect(
      tester.getCenter(find.text('Free')).dx,
      lessThan(tester.getCenter(find.text('Pro')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Free')).dy,
      closeTo(tester.getTopLeft(find.text('Pro')).dy, 2),
    );
    await tester.scrollUntilVisible(
      find.text('DOQR Pro Yıllık'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DOQR Pro Yıllık'), findsOneWidget);
    expect(find.textContaining('Süre: 1 yıl'), findsOneWidget);
    final trialPurchaseButton =
        find.textContaining('Pro aboneliğini başlat');
    for (var i = 0; i < 10 && trialPurchaseButton.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -150),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(trialPurchaseButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ücretli Pro planında satın alma düğmesi kapanır',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    const paidPlan = PlanItem(
      id: 'pro',
      displayName: 'Pro',
      annualPriceUsdCents: 1499,
      maxDoors: 3,
      maxHostsPerDoor: 3,
      logRetentionDays: 90,
      logRetentionCount: null,
      monthlyAudioSeconds: 7200,
      monthlyVideoSeconds: 3600,
      features: {},
      subscriptionStatus: 'active',
      currentPeriodEnd: null,
      trialEndsAt: null,
      isTrial: false,
    );

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
        home: const PlansScreen(currentPlan: paidPlan),
      ),
    ));

    expect(find.text('Mevcut planın: Pro'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pro planın aktif'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Pro planın aktif'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan ekranı İngilizce gösterilebilir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);

    const freePlan = PlanItem(
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

    await tester.pumpWidget(AppLanguageScope(
      controller: languageController,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildDoqrTheme(),
        home: const PlansScreen(currentPlan: freePlan),
      ),
    ));

    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Compare plans'), findsOneWidget);
    expect(find.textContaining('Shown in the store'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Restore purchases'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('DOQR Pro Annual'), findsOneWidget);
    expect(find.textContaining('Length: 1 year'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Terms of Use'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
