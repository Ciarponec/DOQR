import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:doqr_app/services/media_session.dart';

void main() {
  test('uses the server-safe message for media function failures', () {
    const exception = FunctionsHttpException(
      status: 503,
      details: {
        'error': 'Sesli ve görüntülü görüşme geçici olarak kullanılamıyor',
        'code': 'TURN_UNAVAILABLE',
      },
    );

    expect(
      mediaSessionErrorMessage(exception),
      'Sesli ve görüntülü görüşme geçici olarak kullanılamıyor',
    );
  });

  test('does not expose raw internal function diagnostics', () {
    const exception = FunctionsHttpException(
      status: 500,
      details: 'Internal Server Error: provider stack trace',
    );

    final message = mediaSessionErrorMessage(exception);
    expect(message, contains('Görüşme altyapısına'));
    expect(message, isNot(contains('stack trace')));
  });
}
