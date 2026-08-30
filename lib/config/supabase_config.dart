class SupabaseConfig {
  static const String url = 'https://sodxtvyusndehtycgino.supabase.co';

  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String anonKey = _envAnonKey == ''
      ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZHh0dnl1c25kZWh0eWNnaW5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NTQ0MDAsImV4cCI6MjEwMDIzMDQwMH0.URYtK86DQOW2-q_qHPFpEnDqF-onYzj8J69n74tyUQM'
      : _envAnonKey;
}
