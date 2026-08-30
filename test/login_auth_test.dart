import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacy_erp/config/supabase_config.dart';

void main() {
  test('Verify ceo and hr logins', () async {
    final client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ',
      },
    );

    // 1. CEO login
    final ceoRes = await client.auth.signInWithPassword(
      email: 'ceo@pharmacy.com',
      password: 'Pharmacy@2026',
    );
    expect(ceoRes.user, isNotNull);
    expect(ceoRes.user?.email, equals('ceo@pharmacy.com'));
    print('CEO LOGIN VERIFIED: ' + ceoRes.user!.id);

    // 2. HR login
    final hrRes = await client.auth.signInWithPassword(
      email: 'hr@pharmacy.com',
      password: 'Pharmacy@2026',
    );
    expect(hrRes.user, isNotNull);
    expect(hrRes.user?.email, equals('hr@pharmacy.com'));
    print('HR LOGIN VERIFIED: ' + hrRes.user!.id);

    client.dispose();
  });
}
