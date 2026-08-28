import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://sodxtvyusndehtycgino.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZHh0dnl1c25kZWh0eWNnaW5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2NTQ0MDAsImV4cCI6MjEwMDIzMDQwMH0.URYtK86DQOW2-q_qHPFpEnDqF-onYzj8J69n74tyUQM',
  );

  try {
    final tRes = await supabase.auth.signUp(email: 'telesales@pharmacy.com', password: 'Test1234!');
    if (tRes.user != null) {
      final tId = tRes.user!.id;
      await supabase.from('profiles').upsert({'id': tId, 'email': 'telesales@pharmacy.com', 'role': 'TELESALES'});
      print('Telesales created: $tId');
    }
  } catch (e) {
    print('Error T: $e');
  }

  try {
    final sRes = await supabase.auth.signUp(email: 'secretary@pharmacy.com', password: 'Test1234!');
    if (sRes.user != null) {
      final sId = sRes.user!.id;
      await supabase.from('profiles').upsert({'id': sId, 'email': 'secretary@pharmacy.com', 'role': 'SECRETARY'});
      print('Secretary created: $sId');
    }
  } catch (e) {
    print('Error S: $e');
  }

  exit(0);
}
