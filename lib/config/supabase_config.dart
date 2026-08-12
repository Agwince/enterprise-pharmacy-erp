class SupabaseConfig {
  static const String url = 'https://sodxtvyusndehtycgino.supabase.co';
  
  // Standard Supabase Anon Key fallback for prototype execution
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZHh0dnl1c25kZWh0eWNnaW5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MjAxNTAwMDAwMH0.signature_placeholder',
  );
}
