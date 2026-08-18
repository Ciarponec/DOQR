import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqr_app/l10n/app_language.dart';
import 'package:doqr_app/models/door_item.dart';
import 'package:doqr_app/screens/doors_manage_screen.dart';
import 'package:doqr_app/services/doqr_api.dart';
import 'package:doqr_app/services/providers.dart';
import 'package:doqr_app/ui/app_theme.dart';

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

const _door = DoorItem(
  id: 'review-door',
  label: 'Apple App Review Kapısı',
  addressText: 'Demo',
  plan: _freePlan,
);

class _FakeDoqrApi extends Fake implements DoqrApi {
  @override
  Future<DoorListResult> listDoors() async =>
      const DoorListResult([_door], _freePlan);
}

void main() {
  testWidgets('Free plan kilitleri dokununca açıklama gösterir',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(820, 1180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final languageController = AppLanguageController();
    addTearDown(languageController.dispose);
    final api = _FakeDoqrApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [doqrApiProvider.overrideWithValue(api)],
        child: AppLanguageScope(
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
            home: const DoorsManageScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Ekle'),
    );
    expect(addButton.onPressed, isNotNull);
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Free plan zil sınırına ulaştın'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    final courierButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Kurye (Pro)'),
    );
    expect(courierButton.onPressed, isNotNull);
    await tester.tap(find.text('Kurye (Pro)'));
    await tester.pumpAndSettle();
    expect(find.text('Kurye notları Pro özelliğidir'), findsOneWidget);
    expect(find.text('Planları gör'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
