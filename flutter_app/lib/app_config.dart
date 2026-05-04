class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const visitorBaseUrl = String.fromEnvironment('VISITOR_BASE_URL', defaultValue: 'https://ciarponec.github.io/DOQR/');

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError('SUPABASE_URL and SUPABASE_ANON_KEY are required via --dart-define.');
    }
  }
}
