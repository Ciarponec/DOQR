import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    await tester.pumpWidget(MaterialApp(
      theme: buildDoqrTheme(),
      home: const PlansScreen(currentPlan: trialPlan),
    ));

    expect(find.text('Mevcut planın: Pro Deneme'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Pro'), findsOneWidget);
    expect(find.textContaining(r'$14.99'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
