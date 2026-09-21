import 'package:doqr_app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth redirect carries the selected language without changing callback',
      () {
    for (final language in ['tr', 'en', 'ru']) {
      final uri = Uri.parse(AppConfig.authEmailRedirect(language));
      expect(uri.scheme, 'com.doqr.app');
      expect(uri.host, 'auth');
      expect(uri.path, '/callback');
      expect(uri.queryParameters['email_language'], language);
      expect(uri.toString(), endsWith('?email_language=$language'));
    }
    expect(
        Uri.parse(AppConfig.authEmailRedirect('xx'))
            .queryParameters['email_language'],
        'tr');
  });

  test('web email redirect drops old auth parameters and hash routes', () {
    final uri = Uri.parse(AppConfig.authEmailRedirect('ru',
        webBase: Uri.parse('https://example.com/app/?next=doors#/login')));
    expect(uri.host, 'example.com');
    expect(uri.path, '/app/');
    expect(uri.fragment, '');
    expect(uri.toString(), 'https://example.com/app/?email_language=ru');
    expect(uri.queryParameters, {'email_language': 'ru'});
  });

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
