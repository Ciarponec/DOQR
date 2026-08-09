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
}
