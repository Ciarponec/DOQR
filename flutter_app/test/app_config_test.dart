import 'package:doqr_app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visitor URL always carries the encoded QR token', () {
    const token = 'door/token + güvenli';

    final uri = AppConfig.visitorUrlForToken(token);

    expect(uri.scheme, 'https');
    expect(uri.host, 'ciarponec.github.io');
    expect(uri.path, '/DOQR/');
    expect(uri.queryParameters['qr'], token);
  });

  test('empty visitor QR token is rejected', () {
    expect(
      () => AppConfig.visitorUrlForToken('   '),
      throwsArgumentError,
    );
  });

  test('legal pages resolve for Turkish, English, and Russian', () {
    expect(AppConfig.legalUrl('privacy', 'tr').path, '/DOQR/privacy.html');
    expect(AppConfig.legalUrl('privacy', 'en').path, '/DOQR/privacy-en.html');
    expect(AppConfig.legalUrl('privacy', 'ru').path, '/DOQR/privacy-ru.html');
  });
}
