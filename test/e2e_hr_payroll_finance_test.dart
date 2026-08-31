import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_erp/services/accounting_service.dart';
import 'package:pharmacy_erp/services/payroll_service.dart';

void main() {
  const params = KenyaStatutoryParams();

  group('STEP 3 & STEP 6: Statutory Payroll Calibration & Double-Entry Balance', () {
    test('100k Salary: Exact Statutory Derivation and 107,550.00 Journal Balance', () {
      final staff = {
        'basic_salary': 100000.0,
        'house_allowance': 0.0,
        'transport_allowance': 0.0,
        'medical_allowance': 0.0,
        'other_allowance': 0.0,
        'pension_contribution': 0.0,
        'is_paye_applicable': true,
      };

      final p = PayrollService.computePayslip(staff: staff, params: params);

      // Pre-tax statutory deductions (Tax Laws Amendment Act 2024 s.15(2))
      expect(p.grossPay, equals(100000.00));
      expect(p.nssfEmployee, equals(6000.00)); // NSSF Phase IV (6% of 9k + 6% of 91k)
      expect(p.shif, equals(2750.00)); // 2.75%
      expect(p.ahlEmployee, equals(1500.00)); // 1.5%
      expect(p.taxableIncome, equals(89750.00)); // 100,000 - 6,000 - 2,750 - 1,500
      expect(p.paye, equals(19308.35)); // Exact PAYE after 2,400 monthly personal relief
      expect(p.netPay, equals(70441.65)); // 100,000 - 6,000 - 2,750 - 1,500 - 19,308.35
      expect(p.nssfEmployer, equals(6000.00));
      expect(p.ahlEmployer, equals(1500.00));
      expect(p.nitaEmployer, equals(50.00));

      // Automated Payroll Journal posted to General Ledger
      final run = {
        'id': 'run-2026-02-100k',
        'headcount': 1,
        'period_label': '2026-02',
        'gross_total': p.grossPay,
        'net_total': p.netPay,
        'paye_total': p.paye,
        'nssf_employee_total': p.nssfEmployee,
        'nssf_employer_total': p.nssfEmployer,
        'shif_total': p.shif,
        'ahl_employee_total': p.ahlEmployee,
        'ahl_employer_total': p.ahlEmployer,
      };

      final payroll = PayrollService();
      final lines = payroll.payrollJournalLines(run);

      double totalDebit = 0.0;
      double totalCredit = 0.0;
      for (final l in lines) {
        totalDebit += (l['debit'] as num).toDouble();
        totalCredit += (l['credit'] as num).toDouble();
      }

      totalDebit = (totalDebit * 100).round() / 100.0;
      totalCredit = (totalCredit * 100).round() / 100.0;

      expect(totalDebit, equals(107550.00));
      expect(totalCredit, equals(107550.00));
      expect(totalDebit, equals(totalCredit));

      // Verify specific line accounts
      expect(lines.firstWhere((l) => l['account_code'] == '6000')['debit'], equals(100000.00));
      expect(lines.firstWhere((l) => l['account_code'] == '6010')['debit'], equals(7550.00));
      expect(lines.firstWhere((l) => l['account_code'] == '2200')['credit'], equals(19308.35));
      expect(lines.firstWhere((l) => l['account_code'] == '2210')['credit'], equals(12000.00));
      expect(lines.firstWhere((l) => l['account_code'] == '2220')['credit'], equals(2750.00));
      expect(lines.firstWhere((l) => l['account_code'] == '2230')['credit'], equals(3000.00));
      expect(lines.firstWhere((l) => l['account_code'] == '2240')['credit'], equals(50.00));
      expect(lines.firstWhere((l) => l['account_code'] == '2300')['credit'], equals(70441.65));
    });

    test('15k Salary: Minimum SHIF Floor & Tier I/II NSSF', () {
      final staff = {
        'basic_salary': 15000.0,
        'house_allowance': 0.0,
        'transport_allowance': 0.0,
        'medical_allowance': 0.0,
        'other_allowance': 0.0,
        'pension_contribution': 0.0,
        'is_paye_applicable': true,
      };

      final p = PayrollService.computePayslip(staff: staff, params: params);

      expect(p.grossPay, equals(15000.00));
      expect(p.nssfEmployee, equals(900.00));
      expect(p.shif, equals(412.50));
      expect(p.ahlEmployee, equals(225.00));
      expect(p.taxableIncome, equals(13462.50));
      expect(p.paye, equals(0.00));
      expect(p.netPay, equals(13462.50));
      expect(p.nssfEmployer, equals(900.00));
      expect(p.ahlEmployer, equals(225.00));
    });

    test('750k Salary: NSSF Cap & 32.5% Tax Band', () {
      final staff = {
        'basic_salary': 750000.0,
        'house_allowance': 0.0,
        'transport_allowance': 0.0,
        'medical_allowance': 0.0,
        'other_allowance': 0.0,
        'pension_contribution': 0.0,
        'is_paye_applicable': true,
      };

      final p = PayrollService.computePayslip(staff: staff, params: params);

      expect(p.grossPay, equals(750000.00));
      expect(p.nssfEmployee, equals(6480.00)); // Capped at Phase IV max (540 + 5940)
      expect(p.shif, equals(20625.00));
      expect(p.ahlEmployee, equals(11250.00));
      expect(p.taxableIncome, equals(711645.00));
      expect(p.paye, equals(211167.98));
      expect(p.netPay, equals(500477.02));
      expect(p.nssfEmployer, equals(6480.00));
      expect(p.ahlEmployer, equals(11250.00));
    });

    test('Unpaid Leave: Configurable Divisor (e.g. 30 days basis)', () {
      final staff = {
        'basic_salary': 60000.0,
        'house_allowance': 0.0,
        'transport_allowance': 0.0,
        'medical_allowance': 0.0,
        'other_allowance': 0.0,
        'pension_contribution': 0.0,
        'is_paye_applicable': true,
      };

      // 3 days unpaid leave with default 30 days divisor = KES 6,000 deduction
      final p = PayrollService.computePayslip(
        staff: staff,
        params: params,
        unpaidLeaveDays: 3,
      );

      expect(p.unpaidLeaveDays, equals(3));
      expect(p.unpaidLeaveDeduction, equals(6000.00));
      expect(p.grossPay, equals(60000.00));
    });
  });

  group('STEP 5: General Ledger Accounting Equation', () {
    test('Signed Balance and Balance Sheet Reconciles', () {
      final assetRow = {'code': '1010', 'type': 'asset', 'debit': 150000.0, 'credit': 50000.0};
      final liabRow = {'code': '2000', 'type': 'liability', 'debit': 20000.0, 'credit': 80000.0};
      final equityRow = {'code': '3000', 'type': 'equity', 'debit': 0.0, 'credit': 40000.0};

      expect(AccountingService.signedBalance(assetRow), equals(100000.0));
      expect(AccountingService.signedBalance(liabRow), equals(60000.0));
      expect(AccountingService.signedBalance(equityRow), equals(40000.0));

      final assets = AccountingService.signedBalance(assetRow);
      final liabilities = AccountingService.signedBalance(liabRow);
      final equity = AccountingService.signedBalance(equityRow);

      expect(assets, equals(liabilities + equity));
    });
  });
}
