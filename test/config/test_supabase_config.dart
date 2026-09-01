class TestSupabaseConfig {
  static String get url {
    final v = const String.fromEnvironment('TEST_SUPABASE_URL');
    if (v.isEmpty) {
      throw StateError(
        'Tests require --dart-define=TEST_SUPABASE_URL. '
        'Refusing to run against production.',
      );
    }
    return v;
  }

  static String get anonKey {
    final v = const String.fromEnvironment('TEST_SUPABASE_ANON_KEY');
    if (v.isEmpty) {
      throw StateError(
        'Tests require --dart-define=TEST_SUPABASE_ANON_KEY. '
        'Refusing to run against production.',
      );
    }
    return v;
  }
}
