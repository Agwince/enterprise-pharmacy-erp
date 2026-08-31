import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_erp/services/payroll_service.dart';

void main() {
  const params = KenyaStatutoryParams();

  group('Kenya Statutory Payroll Math (2026 / Pre-Tax s.15(2) ITA)', () {
    test('Benchmark 1: KES 100,000 Gross Pay', () {
      final staff = {
        'basic_salary': 100000.0,
        'house_allowance': 0.0,
        'transport_allowance': 0.0,
        'medical_allowance': 0.0,
        'other_allowance': 0.0,
        'pension_contribution': 0.0,
        'is_paye_applicable': true,
      };

      final r = PayrollService.computePayslip(staff: staff, params: params);

      expect(r.grossPay, equals(100000.00));
      expect(r.nssfEmployee, equals(6000.00));
      expect(r.shif, equals(2750.00));
      expect(r.ahlEmployee, equals(1500.00));
      expect(r.taxableIncome, equals(89750.00));
      expect(r.paye, equals(19308.35));
      expect(r.netPay, equals(70441.65));
      expect(r.nssfEmployer, equals(6000.00));
      expect(r.ahlEmployer, equals(1500.00));
      expect(r.nitaEmployer, equals(50.00));

      // Test Journal Generation
      final run = {
        'id': 'test-run-100k',
        'headcount': 1,
        'period_label': '2026-02',
        'gross_total': r.grossPay,
        'net_total': r.netPay,
        'paye_total': r.paye,
        'nssf_employee_total': r.nssfEmployee,
        'nssf_employer_total': r.nssfEmployer,
        'shif_total': r.shif,
        'ahl_employee_total': r.ahlEmployee,
        'ahl_employer_total': r.ahlEmployer,
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
    });

    test('Benchmark 2: KES 15,000 Gross Pay (SHIF Floor & Tier I/II)', () {
      final staff = {
        'basic_salary': 15000.0,
        'house_allowance': 0.0,
        'transport_allowance': 0.0,
        'medical_allowance': 0.0,
        'other_allowance': 0.0,
        'pension_contribution': 0.0,
        'is_paye_applicable': true,
      };

      final r = PayrollService.computePayslip(staff: staff, params: params);

      expect(r.grossPay, equals(15000.00));
      expect(r.nssfEmployee, equals(900.00));
      expect(r.shif, equals(412.50));
      expect(r.ahlEmployee, equals(225.00));
      expect(r.taxableIncome, equals(13462.50));
      expect(r.paye, equals(0.00));
      expect(r.netPay, equals(13462.50));
      expect(r.nssfEmployer, equals(900.00));
      expect(r.ahlEmployer, equals(225.00));
    });

    test('Benchmark 3: KES 750,000 Gross Pay (NSSF Cap & 32.5% Band)', () {
      final staff = {
        'basic_salary': 750000.0,
        'house_allowance': 0.0,
        'transport_allowance': 0.0,
        'medical_allowance': 0.0,
        'other_allowance': 0.0,
        'pension_contribution': 0.0,
        'is_paye_applicable': true,
      };

      final r = PayrollService.computePayslip(staff: staff, params: params);

      expect(r.grossPay, equals(750000.00));
      expect(r.nssfEmployee, equals(6480.00));
      expect(r.shif, equals(20625.00));
      expect(r.ahlEmployee, equals(11250.00));
      expect(r.taxableIncome, equals(711645.00));
      expect(r.paye, equals(211167.98));
      expect(r.netPay, equals(500477.02));
      expect(r.nssfEmployer, equals(6480.00));
      expect(r.ahlEmployer, equals(11250.00));
    });
  });
}
