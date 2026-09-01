@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacy_erp/config/supabase_config.dart';

void main() {
  const defaultPassword = 'Pharmacy@2026';
  late SupabaseClient adminClient;
  late SupabaseClient secretaryClient;
  late String nairobiBranchId;
  late String kisumuBranchId;

  setUpAll(() async {
    adminClient = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      headers: {'apikey': SupabaseConfig.anonKey},
    );

    // 1. Sign in as Admin with retry
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await adminClient.auth.signInWithPassword(
          email: 'admin@pharmacy.com',
          password: defaultPassword,
        );
        break;
      } catch (e) {
        if (attempt == 3) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // 2. Fetch Branches
    final branches = await adminClient.from('branches').select('id, code, name');
    final nairobi = branches.firstWhere((b) => b['code'] == 'NBO-01');
    final kisumu = branches.firstWhere((b) => b['code'] == 'KSM-02');
    nairobiBranchId = nairobi['id'].toString();
    kisumuBranchId = kisumu['id'].toString();
  });

  tearDownAll(() async {
    // Re-authenticate as admin to clean up
    await adminClient.auth.signInWithPassword(
      email: 'admin@pharmacy.com',
      password: defaultPassword,
    );

    // Delete any test rows
    await adminClient.from('insurance_claims').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await adminClient.from('eod_declarations').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await adminClient.from('branch_bank_deposits').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await adminClient.from('branch_supplier_invoices').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await adminClient.from('imprest_ledger').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await adminClient.from('branch_shift_handovers').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await adminClient.from('etims_invoices').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    await adminClient.from('mpesa_transactions').delete().neq('id', '00000000-0000-0000-0000-000000000000');

    // Reset secretary branch back to Nairobi
    await adminClient.from('staff').update({'branch_id': nairobiBranchId}).eq('email', 'secretary@pharmacy.com');

    adminClient.dispose();
  });

  group('Secretary Branch Scoping & RLS Enforcement', () {
    test('1. Confirm zero fabricated values exist in codebase (50000.0 or Branch Operations pre-fill)', () {
      final libDir = Directory('lib');
      final files = libDir.listSync(recursive: true).whereType<File>();
      final List<String> matchingFiles = [];

      for (final file in files) {
        if (file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          if (content.contains('50000.0') || content.contains("Branch Operations'")) {
            matchingFiles.add(file.path);
          }
        }
      }

      expect(matchingFiles, isEmpty, reason: 'Found fabricated values in: $matchingFiles');
    });

    test('2. Admin seeds Nairobi test records across secretary tables', () async {
      await adminClient.from('insurance_claims').insert({
        'branch_id': nairobiBranchId,
        'client_name': 'Nairobi Test Patient',
        'insurer': 'SHA Nairobi',
        'gross_amount': 4500.0,
        'claim_status': 'Submitted',
      });

      await adminClient.from('eod_declarations').insert({
        'branch_id': nairobiBranchId,
        'branch': 'Nairobi',
        'physical_cash': 10000.0,
        'mpesa_till_balance': 5000.0,
        'variance': 0.0,
      });

      await adminClient.from('branch_bank_deposits').insert({
        'branch_id': nairobiBranchId,
        'branch_name': 'Nairobi',
        'bank_name': 'Equity Bank',
        'slip_reference': 'DEP-NBO-001',
        'amount_deposited': 5000.0,
        'deposited_by': 'Admin',
      });

      await adminClient.from('branch_supplier_invoices').insert({
        'branch_id': nairobiBranchId,
        'branch_name': 'Nairobi',
        'supplier_name': 'Nairobi Meds Ltd',
        'invoice_number': 'INV-NBO-100',
        'grn_reference': 'GRN-NBO-100',
        'amount': 12000.0,
      });

      await adminClient.from('imprest_ledger').insert({
        'branch_id': nairobiBranchId,
        'branch': 'Nairobi',
        'description': 'Nairobi Branch Expense',
        'amount': 1500.0,
        'status': 'Pending Approval',
      });

      await adminClient.from('branch_shift_handovers').insert({
        'branch_id': nairobiBranchId,
        'branch_name': 'Nairobi',
        'outgoing_staff': 'Alice',
        'incoming_staff': 'Bob',
        'float_amount': 2000.0,
      });

      await adminClient.from('etims_invoices').insert({
        'branch_id': nairobiBranchId,
        'branch_name': 'Nairobi',
        'invoice_number': 'INV-ETIMS-NBO-001',
        'cu_invoice_number': 'CU-NBO-001',
        'cu_serial_number': 'SN-NBO-001',
        'kra_pin': 'P051234567Z',
        'trader_name': 'Enterprise Pharmacy',
        'date_time': '2026-09-01T00:00:00Z',
        'items': '[]',
        'local_integrity_hash': 'sha256-hash',
        'verification_url': 'https://itax.kra.go.ke',
      });

      await adminClient.from('mpesa_transactions').insert({
        'branch_id': nairobiBranchId,
        'transaction_code': 'MPESA-NBO-01',
        'amount': 2500.0,
      });
    });

    test('3. Assign secretary to Kisumu branch in staff table', () async {
      await adminClient.from('staff').update({'branch_id': kisumuBranchId}).eq('email', 'secretary@pharmacy.com');

      final secretaryStaff = await adminClient.from('staff').select().eq('email', 'secretary@pharmacy.com').single();
      expect(secretaryStaff['branch_id'], equals(kisumuBranchId));
    });

    test('4. Log in as Kisumu-assigned secretary and verify RLS prevents reading ANY Nairobi rows', () async {
      secretaryClient = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
        headers: {'apikey': SupabaseConfig.anonKey},
      );

      AuthResponse? authRes;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          authRes = await secretaryClient.auth.signInWithPassword(
            email: 'secretary@pharmacy.com',
            password: defaultPassword,
          );
          if (authRes.user != null) break;
        } catch (e) {
          if (attempt == 3) rethrow;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      expect(authRes?.user, isNotNull);

      // Verify that querying without filters as Kisumu secretary returns ZERO Nairobi rows due to RLS
      final claims = await secretaryClient.from('insurance_claims').select();
      expect(claims, isEmpty, reason: 'Kisumu secretary must see ZERO Nairobi insurance claims');

      final eod = await secretaryClient.from('eod_declarations').select();
      expect(eod, isEmpty, reason: 'Kisumu secretary must see ZERO Nairobi EOD declarations');

      final deposits = await secretaryClient.from('branch_bank_deposits').select();
      expect(deposits, isEmpty, reason: 'Kisumu secretary must see ZERO Nairobi bank deposits');

      final supplierInvoices = await secretaryClient.from('branch_supplier_invoices').select();
      expect(supplierInvoices, isEmpty, reason: 'Kisumu secretary must see ZERO Nairobi supplier invoices');

      final imprest = await secretaryClient.from('imprest_ledger').select();
      expect(imprest, isEmpty, reason: 'Kisumu secretary must see ZERO Nairobi imprest records');

      final handovers = await secretaryClient.from('branch_shift_handovers').select();
      expect(handovers, isEmpty, reason: 'Kisumu secretary must see ZERO Nairobi shift handovers');

      final etims = await secretaryClient.from('etims_invoices').select();
      expect(etims, isEmpty, reason: 'Kisumu secretary must see ZERO Nairobi eTIMS invoices');

      final mpesa = await secretaryClient.from('mpesa_transactions').select();
      expect(mpesa, isEmpty, reason: 'Kisumu secretary must see ZERO Nairobi M-Pesa transactions');

      secretaryClient.dispose();
    });

    test('5. Kisumu secretary logs a Kisumu claim and can only see their own branch claim', () async {
      final kisumuSecretary = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.anonKey,
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
        headers: {'apikey': SupabaseConfig.anonKey},
      );

      await kisumuSecretary.auth.signInWithPassword(
        email: 'secretary@pharmacy.com',
        password: defaultPassword,
      );

      // Insert claim for Kisumu
      await kisumuSecretary.from('insurance_claims').insert({
        'branch_id': kisumuBranchId,
        'client_name': 'Kisumu Patient',
        'insurer': 'SHA Kisumu',
        'gross_amount': 2200.0,
        'claim_status': 'Submitted',
      });

      final kisumuClaims = await kisumuSecretary.from('insurance_claims').select();
      expect(kisumuClaims.length, equals(1));
      expect(kisumuClaims.first['client_name'], equals('Kisumu Patient'));
      expect(kisumuClaims.first['branch_id'], equals(kisumuBranchId));

      kisumuSecretary.dispose();
    });
  });
}
