import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doqr_app/l10n/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dil seçimi cihazda saklanır ve yeniden yüklenir', () async {
    SharedPreferences.setMockInitialValues({});
    final first = AppLanguageController();
    addTearDown(first.dispose);

    expect(first.locale.languageCode, 'tr');
    await first.setLocale(const Locale('en'));
    expect(first.locale.languageCode, 'en');

    final second = AppLanguageController();
    addTearDown(second.dispose);
    await second.load();
    expect(second.locale.languageCode, 'en');

    await second.setLocale(const Locale('tr'));
  });

  test('Rusça cihaz dili ilk açılışta seçilir ve saklanır', () async {
    SharedPreferences.setMockInitialValues({});
    final initial = await AppLanguageController.resolveInitialLocale(
        deviceLocale: const Locale('ru', 'RU'));
    expect(initial.languageCode, 'ru');

    final controller = AppLanguageController(initialLocale: initial);
    addTearDown(controller.dispose);
    await controller.setLocale(const Locale('en'));
    final restored = await AppLanguageController.resolveInitialLocale(
        deviceLocale: const Locale('ru', 'RU'));
    expect(restored.languageCode, 'en');
  });
}
