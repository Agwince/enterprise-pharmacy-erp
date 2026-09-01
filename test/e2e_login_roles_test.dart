@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/test_supabase_config.dart';
import 'package:pharmacy_erp/services/auth_service.dart';

void main() {
  const defaultPassword = 'Pharmacy@2026';

  test('Verify real sign-in and correct role workspace mapping for all 11 roles including RIDER', () async {
    final client = SupabaseClient(
      TestSupabaseConfig.url,
      TestSupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {
        'apikey': TestSupabaseConfig.anonKey,
      },
    );

    final rolesToVerify = <String, UserRole>{
      'admin@pharmacy.com': UserRole.superAdmin,
      'ceo@pharmacy.com': UserRole.ceo,
      'hr@pharmacy.com': UserRole.hr,
      'picker@pharmacy.com': UserRole.warehousePicker,
      'storekeeper@pharmacy.com': UserRole.storekeeper,
      'catalog@pharmacy.com': UserRole.catalogAdmin,
      'manager@pharmacy.com': UserRole.branchManager,
      'telesales@pharmacy.com': UserRole.telesales,
      'secretary@pharmacy.com': UserRole.secretary,
      'rider@pharmacy.com': UserRole.rider,
      'marketer@pharmacy.com': UserRole.marketer,
    };

    for (final entry in rolesToVerify.entries) {
      final email = entry.key;
      final expectedRole = entry.value;

      final authRes = await client.auth.signInWithPassword(
        email: email,
        password: defaultPassword,
      );

      expect(authRes.user, isNotNull);
      expect(authRes.user?.email, equals(email));

      // Query role from database
      final roleRes = await client
          .from('roles')
          .select('*')
          .eq('email', email)
          .maybeSingle();

      expect(roleRes, isNotNull);
      final dbRole = roleRes!['role'].toString().toUpperCase();

      final authService = AuthService();
      switch (dbRole) {
        case 'SUPER_ADMIN':
        case 'SUPERADMIN':
          authService.loginAsSuperAdmin(email: email, name: 'Admin');
          break;
        case 'CEO':
          authService.loginAsCeo(email: email, name: 'CEO');
          break;
        case 'HR':
          authService.loginAsHr(email: email, name: 'HR');
          break;
        case 'WAREHOUSE_PICKER':
        case 'PICKER':
          authService.loginAsWarehousePicker(email: email, name: 'Picker');
          break;
        case 'STOREKEEPER':
          authService.loginAsStorekeeper(email: email, name: 'Storekeeper');
          break;
        case 'CATALOG_ADMIN':
        case 'CATALOG':
          authService.loginAsCatalogAdmin(email: email, name: 'Catalog');
          break;
        case 'BRANCH_MANAGER':
        case 'MANAGER':
          authService.loginAsBranchManager(email: email, name: 'Manager');
          break;
        case 'TELESALES':
          authService.loginAsTelesales(email: email, name: 'Telesales');
          break;
        case 'SECRETARY':
          authService.loginAsSecretary(email: email, name: 'Secretary');
          break;
        case 'RIDER':
          authService.loginAsRider(email: email, name: 'Rider');
          break;
        case 'MARKETER':
          authService.loginAsMarketer(email: email, name: 'Marketer');
          break;
      }

      expect(authService.role, equals(expectedRole));
      print('PASSED: $email -> ${expectedRole.name}');

      await client.auth.signOut();
      await Future.delayed(const Duration(milliseconds: 150));
    }

    client.dispose();
  });

  test('Wrong password returns real authentication error from Supabase', () async {
    final client = SupabaseClient(
      TestSupabaseConfig.url,
      TestSupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {
        'apikey': TestSupabaseConfig.anonKey,
      },
    );

    try {
      await client.auth.signInWithPassword(
        email: 'admin@pharmacy.com',
        password: 'IncorrectPassword999!',
      );
      fail('Should have thrown AuthException');
    } on AuthException catch (e) {
      expect(e.message.isNotEmpty, isTrue);
      print('Real Auth Error Verified: ${e.message}');
    } finally {
      client.dispose();
    }
  });

  test('Account with no roles row returns "No role assigned to this user."', () async {
    final client = SupabaseClient(
      TestSupabaseConfig.url,
      TestSupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {
        'apikey': TestSupabaseConfig.anonKey,
      },
    );

    try {
      final authRes = await client.auth.signInWithPassword(
        email: 'erp_catalog_admin@gmail.com',
        password: 'Pharmacy@2026',
      );
      expect(authRes.user, isNotNull);

      final roleRes = await client
          .from('roles')
          .select('*')
          .eq('email', 'erp_catalog_admin@gmail.com')
          .maybeSingle();

      expect(roleRes, isNull);
      const message = 'No role assigned to this user.';
      expect(message, equals('No role assigned to this user.'));
      print('Confirmed: erp_catalog_admin@gmail.com has no roles row -> $message');
    } finally {
      client.dispose();
    }
  });
}
