@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacy_erp/config/supabase_config.dart';
import 'package:pharmacy_erp/services/branch_service.dart';

void main() {
  late SupabaseClient client;
  late BranchService branchService;

  setUpAll(() async {
    client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {
        'apikey': SupabaseConfig.anonKey,
      },
    );

    // Authenticate as Root Admin
    await client.auth.signInWithPassword(
      email: 'admin@pharmacy.com',
      password: 'Pharmacy@2026',
    );

    branchService = BranchService(db: client);
  });

  tearDownAll(() {
    client.dispose();
  });

  group('Branch Management & Super Admin Delete Protection Verification', () {

    test('STEP 1 & 2: Verify all 4 initial branches survived with new schema columns', () async {
      final branches = await branchService.getBranches();
      expect(branches.length, greaterThanOrEqualTo(4));

      final nbo = branches.firstWhere((b) => b['code'] == 'NBO-01');
      final ksm = branches.firstWhere((b) => b['code'] == 'KSM-02');
      final msa = branches.firstWhere((b) => b['code'] == 'MSA-03');
      final eld = branches.firstWhere((b) => b['code'] == 'ELD-04');

      expect(nbo['id'], equals('9bdf6137-8825-4bc2-8bbd-f128c975c7a5'));
      expect(ksm['id'], equals('1a94f380-a3a8-48de-86dc-88b1372a1ec1'));
      expect(msa['id'], equals('25807b6f-1a64-415a-95ae-3aa60759b9f6'));
      expect(eld['id'], equals('bf9c825f-6c66-4265-9d77-eb674370e31c'));

      expect(nbo['is_active'], equals(true));
      expect(nbo['is_pos_default'], equals(true));
      expect(nbo.containsKey('address'), isTrue);
      expect(nbo.containsKey('phone'), isTrue);
      expect(nbo.containsKey('manager_name'), isTrue);
      expect(nbo.containsKey('county'), isTrue);
      expect(nbo.containsKey('updated_at'), isTrue);
    });

    test('STEP 3: Proof Non-Admin/HR is blocked by Database RLS from deleting or modifying branches', () async {
      final nonAdminClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
        headers: {'apikey': SupabaseConfig.anonKey},
      );

      // Authenticate as non-admin user
      await nonAdminClient.auth.signInWithPassword(
        email: 'catalog@pharmacy.com',
        password: 'Pharmacy@2026',
      );

      // 1. Non-admin can read branches
      final readRes = await nonAdminClient.from('branches').select().limit(1);
      expect((readRes as List).isNotEmpty, isTrue);

      // 2. Non-admin attempting to delete a branch is rejected by RLS policy (0 rows affected, row persists)
      await nonAdminClient.from('branches').delete().eq('code', 'NBO-01');
      final nboCheck = await nonAdminClient.from('branches').select().eq('code', 'NBO-01').maybeSingle();
      expect(nboCheck, isNotNull);
      expect(nboCheck!['code'], equals('NBO-01'));

      // 3. Non-admin attempting to insert a branch is rejected by RLS
      bool insertFailed = false;
      try {
        await nonAdminClient.from('branches').insert({
          'code': 'UNAUTH-99',
          'name': 'Unauthorized Branch Attempt',
        });
      } catch (e) {
        insertFailed = true;
        print('RLS INSERT ERROR RECEIVED: $e');
      }
      expect(insertFailed, isTrue);

      nonAdminClient.dispose();
    });

    test('STEP 5: Deleting POS Default NBO-01 is strictly blocked by guard', () async {
      expect(
        () async => await branchService.deleteBranch('9bdf6137-8825-4bc2-8bbd-f128c975c7a5', 'NBO-01'),
        throwsA(predicate((e) => e.toString().contains('point-of-sale default branch'))),
      );
    });

    test('STEP 7 & 8: Full Branch Lifecycle Trace (Create -> Edit -> Deactivate -> Reactivate -> Delete)', () async {
      const testCode = 'KTL-99';

      // 1. Create
      final created = await branchService.createBranch(
        code: testCode,
        name: 'Kitale Test Wholesale Hub',
        county: 'Trans-Nzoia',
        address: 'CBD Highway Plaza',
        phone: '+254 711 999 000',
        managerName: 'Test Branch Manager',
        isActive: true,
        isPosDefault: false,
      );
      expect(created['code'], equals(testCode));
      expect(created['name'], equals('Kitale Test Wholesale Hub'));
      final String branchId = created['id'].toString();

      // Verify re-read from DB
      final read1 = await client.from('branches').select().eq('id', branchId).single();
      expect(read1['name'], equals('Kitale Test Wholesale Hub'));

      // 2. Edit
      final updated = await branchService.updateBranch(branchId, {
        'name': 'Kitale Regional Distribution Depot',
        'county': 'Trans-Nzoia West',
      });
      expect(updated['name'], equals('Kitale Regional Distribution Depot'));

      // Verify re-read from DB
      final read2 = await client.from('branches').select().eq('id', branchId).single();
      expect(read2['name'], equals('Kitale Regional Distribution Depot'));
      expect(read2['county'], equals('Trans-Nzoia West'));

      // 3. Deactivate
      final deactivated = await branchService.deactivateBranch(branchId);
      expect(deactivated['is_active'], isFalse);

      // Verify re-read from DB
      final read3 = await client.from('branches').select().eq('id', branchId).single();
      expect(read3['is_active'], isFalse);

      // 4. Reactivate
      final reactivated = await branchService.reactivateBranch(branchId);
      expect(reactivated['is_active'], isTrue);

      // Verify re-read from DB
      final read4 = await client.from('branches').select().eq('id', branchId).single();
      expect(read4['is_active'], isTrue);

      // 5. Delete (0 dependencies)
      await branchService.deleteBranch(branchId, testCode);

      // Verify re-read confirms row is deleted
      final read5 = await client.from('branches').select().eq('id', branchId).maybeSingle();
      expect(read5, isNull);

      // 6. Verify audit trail logs
      final auditLogs = await branchService.getAuditLogs(branchCode: testCode);
      expect(auditLogs.length, greaterThanOrEqualTo(4));
      final actions = auditLogs.map((l) => l['action']).toList();
      expect(actions, containsAll(['CREATED', 'EDITED', 'DEACTIVATED', 'REACTIVATED', 'DELETED']));
    });

    test('STEP 6: POS Branch Resolution returns active default', () async {
      final defaultBranch = await branchService.getDefaultPosBranch();
      expect(defaultBranch, isNotNull);
      expect(defaultBranch!['is_active'], equals(true));
      expect(defaultBranch['is_pos_default'], equals(true));
      expect(defaultBranch['code'], equals('NBO-01'));
    });
  });
}