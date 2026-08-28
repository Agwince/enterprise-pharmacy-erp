import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://sodxtvyusndehtycgino.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZHh0dnl1c25kZWh0eWNnaW5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NTQ0MDAsImV4cCI6MjEwMDIzMDQwMH0.URYtK86DQOW2-q_qHPFpEnDqF-onYzj8J69n74tyUQM',
  );

  try {
    final res = await supabase.from('users').select();
    print('Users table: $res');
  } catch (e) {
    print('Users table error: $e');
  }

  try {
    final res = await supabase.from('profiles').select();
    print('Profiles table: $res');
  } catch (e) {
    print('Profiles table error: $e');
  }
  
  exit(0);
}
