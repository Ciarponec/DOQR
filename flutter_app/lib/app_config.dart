class AppConfig {
  static const authRedirectUrl = 'com.doqr.app://auth/callback';
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://warsaqcfovasaitcwtxy.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_Ysi4IwDnNUtUUaNCKhQalg_pz-cp6JX',
  );
  static const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const visitorBaseUrl = String.fromEnvironment(
    'VISITOR_BASE_URL',
    defaultValue: 'https://ciarponec.github.io/DOQR/',
  );

  static String get supabaseKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : legacyAnonKey;

  static Uri visitorUrlForToken(String qrToken) {
    final token = qrToken.trim();
    if (token.isEmpty) {
      throw ArgumentError.value(qrToken, 'qrToken', 'QR token boş olamaz');
    }
    final base = Uri.parse(visitorBaseUrl);
    return base.replace(
      queryParameters: <String, String>{
        ...base.queryParameters,
        'qr': token,
      },
    );
  }

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw StateError(
          'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required via --dart-define.');
    }
  }
}
