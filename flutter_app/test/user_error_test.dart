import 'package:flutter_test/flutter_test.dart';
import 'package:doqr_app/l10n/app_language.dart';
import 'package:doqr_app/services/user_error.dart';

void main() {
  test('API hata kodları teknik ayrıntı sızdırmadan yerelleştirilir', () {
    const error = DoqrApiException(
      'QR_TOKEN_INVALID',
      'postgres relation public.secret missing',
      status: 404,
    );

    AppLanguageController.currentLanguageCode = 'tr';
    expect(userErrorMessage(error), contains('QR kodu'));
    expect(userErrorMessage(error), isNot(contains('postgres')));

    AppLanguageController.currentLanguageCode = 'en';
    expect(userErrorMessage(error), contains('QR code'));

    AppLanguageController.currentLanguageCode = 'ru';
    expect(userErrorMessage(error), contains('QR-код'));
  });

  test('bilinmeyen hata kullanıcıya güvenli genel mesaj verir', () {
    AppLanguageController.currentLanguageCode = 'tr';
    final message = userErrorMessage(Exception('password=secret'));
    expect(message, isNot(contains('secret')));
    expect(message, contains('Bağlantı'));
  });
}
