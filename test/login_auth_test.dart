import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacy_erp/config/supabase_config.dart';

void main() {
  test('Verify complete login and role lookup for catalog@pharmacy.com', () async {
    final client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {
        'apikey': SupabaseConfig.anonKey,
      },
    );

    // 1. Authenticate user
    final authRes = await client.auth.signInWithPassword(
      email: 'catalog@pharmacy.com',
      password: 'Pharmacy@2026',
    );
    expect(authRes.user, isNotNull);
    expect(authRes.user?.email, equals('catalog@pharmacy.com'));
    print('1. AUTH SIGN-IN PASSED: ');

    // 2. Fetch role from public.roles
    final roleRes = await client
        .from('roles')
        .select('*')
        .eq('email', authRes.user!.email!)
        .maybeSingle();

    expect(roleRes, isNotNull);
    expect(roleRes!['role'], equals('CATALOG_ADMIN'));
    print('2. ROLE LOOKUP PASSED: role=');

    client.dispose();
  });

  test('Verify complete login and role lookup for admin@pharmacy.com', () async {
    final client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {
        'apikey': SupabaseConfig.anonKey,
      },
    );

    final authRes = await client.auth.signInWithPassword(
      email: 'admin@pharmacy.com',
      password: 'Pharmacy@2026',
    );
    expect(authRes.user, isNotNull);
    expect(authRes.user?.email, equals('admin@pharmacy.com'));
    print('1. AUTH SIGN-IN PASSED: ');

    final roleRes = await client
        .from('roles')
        .select('*')
        .eq('email', authRes.user!.email!)
        .maybeSingle();

    expect(roleRes, isNotNull);
    expect(roleRes!['role'], equals('SUPER_ADMIN'));
    print('2. ROLE LOOKUP PASSED: role=');

    client.dispose();
  });
}
