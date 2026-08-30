import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hr_leave_service.dart';

/// Kenya statutory parameters (2026). All editable from the payroll UI so the
/// numbers are never silently wrong — they are statutory constants, not data.
class KenyaStatutoryParams {
  final double personalReliefMonthly; // KES 2,400 (KRA)
  final double nssfRate; // 6% employee & 6% employer (NSSF Act 2013)
  final double nssfTier1Limit; // lower earnings limit
  final double nssfTier2Upper; // upper earnings limit
  final double shifRate; // 2.75% of gross (Social Health Insurance Fund)
  final double shifMinimum; // KES 300 floor
  final double ahlRate; // 1.5% employee + 1.5% employer (Affordable Housing Levy)
  final double pensionMonthlyCap; // KES 30,000 tax-deductible ceiling
  final double pensionPercentCap; // 30% of gross
  final double employerNita; // KES 50 / employee / month (employer only)
  final double employerWibaRate; // % of gross (employer only, risk rated)
  final double monthlyHours; // divisor for hourly rate / overtime
  final double overtimeMultiplier;

  const KenyaStatutoryParams({
    this.personalReliefMonthly = 2400.0,
    this.nssfRate = 0.06,
    this.nssfTier1Limit = 8000.0,
    this.nssfTier2Upper = 72000.0,
    this.shifRate = 0.0275,
    this.shifMinimum = 300.0,
    this.ahlRate = 0.015,
    this.pensionMonthlyCap = 30000.0,
    this.pensionPercentCap = 0.30,
    this.employerNita = 50.0,
    this.employerWibaRate = 0.005,
    this.monthlyHours = 208.0,
    this.overtimeMultiplier = 1.5,
  });

  KenyaStatutoryParams copyWith({
    double? personalReliefMonthly,
    double? nssfRate,
    double? nssfTier1Limit,
    double? nssfTier2Upper,
    double? shifRate,
    double? shifMinimum,
    double? ahlRate,
    double? pensionMonthlyCap,
    double? pensionPercentCap,
    double? employerNita,
    double? employerWibaRate,
    double? monthlyHours,
    double? overtimeMultiplier,
  }) =>
      KenyaStatutoryParams(
        personalReliefMonthly: personalReliefMonthly ?? this.personalReliefMonthly,
        nssfRate: nssfRate ?? this.nssfRate,
        nssfTier1Limit: nssfTier1Limit ?? this.nssfTier1Limit,
        nssfTier2Upper: nssfTier2Upper ?? this.nssfTier2Upper,
        shifRate: shifRate ?? this.shifRate,
        shifMinimum: shifMinimum ?? this.shifMinimum,
        ahlRate: ahlRate ?? this.ahlRate,
        pensionMonthlyCap: pensionMonthlyCap ?? this.pensionMonthlyCap,
        pensionPercentCap: pensionPercentCap ?? this.pensionPercentCap,
        employerNita: employerNita ?? this.employerNita,
        employerWibaRate: employerWibaRate ?? this.employerWibaRate,
        monthlyHours: monthlyHours ?? this.monthlyHours,
        overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      );
}

/// Result of a single employee's payroll computation.
class PayslipResult {
  final double grossPay;
  final double allowances;
  final double overtimePay;
  final int unpaidLeaveDays;
  final double unpaidLeaveDeduction;
  final double nssfEmployee;
  final double nssfEmployer;
  final double shif;
  final double ahlEmployee;
  final double ahlEmployer;
  final double pension;
  final double taxableIncome;
  final double payeBeforeRelief;
  final double personalRelief;
  final double paye;
  final double otherDeductions;
  final double totalDeductions;
  final double netPay;
  final double employerCost;

  const PayslipResult({
    required this.grossPay,
    required this.allowances,
    required this.overtimePay,
    this.unpaidLeaveDays = 0,
    this.unpaidLeaveDeduction = 0.0,
    required this.nssfEmployee,
    required this.nssfEmployer,
    required this.shif,
    required this.ahlEmployee,
    required this.ahlEmployer,
    required this.pension,
    required this.taxableIncome,
    required this.payeBeforeRelief,
    required this.personalRelief,
    required this.paye,
    required this.otherDeductions,
    required this.totalDeductions,
    required this.netPay,
    required this.employerCost,
  });

  Map<String, dynamic> toMap() => {
        'gross_pay': grossPay,
        'allowances': allowances,
        'overtime_pay': overtimePay,
        'unpaid_leave_days': unpaidLeaveDays,
        'unpaid_leave_deduction': unpaidLeaveDeduction,
        'nssf_employee': nssfEmployee,
        'nssf_employer': nssfEmployer,
        'shif': shif,
        'ahl_employee': ahlEmployee,
        'ahl_employer': ahlEmployer,
        'pension': pension,
        'taxable_income': taxableIncome,
        'paye_before_relief': payeBeforeRelief,
        'personal_relief': personalRelief,
        'paye': paye,
        'other_deductions': otherDeductions,
        'total_deductions': totalDeductions,
        'net_pay': netPay,
        'employer_cost': employerCost,
      };
}

/// HR & payroll engine (Sage People-class) — all reads/writes hit Supabase:
/// staff, attendance_shifts, payroll_runs, payslips.
class PayrollService {
  final SupabaseClient _db = Supabase.instance.client;

  bool _schemaMissing = false;
  bool get schemaMissing => _schemaMissing;

  String? _lastError;
  String? get lastError => _lastError;

  void _capture(Object e) {
    _lastError = e.toString();
    final msg = e.toString().toLowerCase();
    if (msg.contains('42p01') ||
        msg.contains('pgrst205') ||
        msg.contains('could not find the table') ||
        msg.contains('relation "public')) {
      _schemaMissing = true;
    }
    debugPrint('PayrollService: $e');
  }

  // --------------------------------------------------------------------------
  // Statutory maths
  // --------------------------------------------------------------------------
  /// KRA monthly PAYE bands (2026): 10 / 25 / 30 / 32.5 / 35 percent.
  static const List<List<num>> payeBands = [
    [24000, 0.10],
    [32333, 0.25],
    [500000, 0.30],
    [800000, 0.325],
    [double.infinity, 0.35],
  ];

  static double payeOnTaxable(double taxable) {
    double tax = 0;
    double remaining = taxable;
    double previousCap = 0;
    for (final band in payeBands) {
      final cap = band[0].toDouble();
      final rate = band[1].toDouble();
      final bandWidth = cap - previousCap;
      final slice = remaining > bandWidth ? bandWidth : remaining;
      if (slice <= 0) break;
      tax += slice * rate;
      remaining -= slice;
      previousCap = cap;
      if (remaining <= 0) break;
    }
    return tax;
  }

  /// NSSF: 6% on Tier I (first KES 8,000) + 6% on Tier II (up to KES 72,000).
  static double nssfContribution(double pensionablePay, KenyaStatutoryParams p) {
    if (pensionablePay <= 0) return 0;
    final tier1 = pensionablePay > p.nssfTier1Limit ? p.nssfTier1Limit : pensionablePay;
    final tier2Base = pensionablePay - tier1;
    final tier2Cap = p.nssfTier2Upper - p.nssfTier1Limit;
    final tier2 = tier2Base > tier2Cap ? tier2Cap : (tier2Base > 0 ? tier2Base : 0.0);
    return (tier1 + tier2) * p.nssfRate;
  }

  /// SHIF (SHA): 2.75% of gross, minimum KES 300, no ceiling.
  static double shifContribution(double gross, KenyaStatutoryParams p) {
    final raw = gross * p.shifRate;
    return raw < p.shifMinimum ? p.shifMinimum : raw;
  }

  /// Full computation for one employee for one month.
  static PayslipResult computePayslip({
    required Map<String, dynamic> staff,
    required KenyaStatutoryParams params,
    double overtimeHours = 0,
    int unpaidLeaveDays = 0,
    double otherDeductions = 0,
  }) {
    double n(String k) => (staff[k] as num?)?.toDouble() ?? 0.0;

    final basic = n('basic_salary');
    final house = n('house_allowance');
    final transport = n('transport_allowance');
    final medical = n('medical_allowance');
    final otherAllow = n('other_allowance');
    final allowances = house + transport + medical + otherAllow;

    final hourlyRate = params.monthlyHours > 0 ? basic / params.monthlyHours : 0.0;
    final overtimePay = overtimeHours * hourlyRate * params.overtimeMultiplier;

    // Unpaid leave deduction (daily rate = basic / 30)
    final unpaidLeaveDeduction = unpaidLeaveDays > 0 ? (basic / 30.0) * unpaidLeaveDays : 0.0;

    // Earned gross before deduction
    final earnedGross = basic + allowances + overtimePay;
    final adjustedGross = (earnedGross - unpaidLeaveDeduction).clamp(0.0, 99999999.0);

    final nssfEmp = nssfContribution(adjustedGross, params);
    final nssfEr = nssfContribution(adjustedGross, params);
    final shif = shifContribution(adjustedGross, params);
    final ahlEmp = adjustedGross * params.ahlRate;
    final ahlEr = adjustedGross * params.ahlRate;

    final declaredPension = n('pension_contribution');
    final allowablePension = [
      declaredPension,
      adjustedGross * params.pensionPercentCap,
      params.pensionMonthlyCap,
    ].reduce((a, b) => a < b ? a : b);

    final taxable = adjustedGross - nssfEmp - allowablePension;
    final payeBeforeRelief = payeOnTaxable(taxable > 0 ? taxable : 0.0);
    final relief = (staff['is_paye_applicable'] == false) ? 0.0 : params.personalReliefMonthly;
    final paye = (payeBeforeRelief - relief) > 0 ? (payeBeforeRelief - relief) : 0.0;

    final totalDeductions = nssfEmp + shif + ahlEmp + declaredPension + paye + unpaidLeaveDeduction + otherDeductions;
    final net = (earnedGross - totalDeductions).clamp(0.0, 99999999.0);
    final employerCost = adjustedGross + nssfEr + ahlEr + params.employerNita + (adjustedGross * params.employerWibaRate);

    return PayslipResult(
      grossPay: earnedGross,
      allowances: allowances,
      overtimePay: overtimePay,
      unpaidLeaveDays: unpaidLeaveDays,
      unpaidLeaveDeduction: unpaidLeaveDeduction,
      nssfEmployee: nssfEmp,
      nssfEmployer: nssfEr,
      shif: shif,
      ahlEmployee: ahlEmp,
      ahlEmployer: ahlEr,
      pension: declaredPension,
      taxableIncome: taxable > 0 ? taxable : 0.0,
      payeBeforeRelief: payeBeforeRelief,
      personalRelief: relief,
      paye: paye,
      otherDeductions: otherDeductions,
      totalDeductions: totalDeductions,
      netPay: net,
      employerCost: employerCost,
    );
  }

  // --------------------------------------------------------------------------
  // Staff master
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchStaff({String? branchId}) async {
    try {
      var q = _db.from('staff').select();
      if (branchId != null && branchId.isNotEmpty) q = q.eq('branch_id', branchId);
      final res = await q.order('staff_no');
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchBranches() async {
    try {
      final res = await _db.from('branches').select().order('name');
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  Future<void> saveStaff(Map<String, dynamic> payload, {String? id}) async {
    try {
      if (id == null) {
        await _db.from('staff').insert(payload);
      } else {
        await _db.from('staff').update(payload).eq('id', id);
      }
    } catch (e) {
      _capture(e);
      rethrow;
    }
  }

  Future<void> updateStaffStatus(String id, String status) async {
    await _db.from('staff').update({'status': status}).eq('id', id);
  }

  // --------------------------------------------------------------------------
  // Attendance & shifts
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchShifts(DateTime day) async {
    try {
      final iso = DateTime(day.year, day.month, day.day).toIso8601String().substring(0, 10);
      final res = await _db
          .from('attendance_shifts')
          .select()
          .eq('shift_date', iso)
          .order('created_at');
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  Future<void> recordShift({
    required String staffId,
    required DateTime day,
    required String status,
    String? branchId,
    String shiftName = 'Day',
    DateTime? clockIn,
    DateTime? clockOut,
    double overtimeHours = 0,
    String? notes,
  }) async {
    double hours = 0;
    if (clockIn != null && clockOut != null) {
      hours = clockOut.difference(clockIn).inMinutes / 60.0;
    }
    final payload = {
      'staff_id': staffId,
      'branch_id': branchId,
      'shift_date': DateTime(day.year, day.month, day.day).toIso8601String().substring(0, 10),
      'shift_name': shiftName,
      'status': status,
      'overtime_hours': overtimeHours,
      if (clockIn != null) 'clock_in': clockIn.toIso8601String(),
      if (clockOut != null) 'clock_out': clockOut.toIso8601String(),
      'hours_worked': double.parse(hours.toStringAsFixed(2)),
      'notes': ?notes,
    };
    await _db
        .from('attendance_shifts')
        .upsert(payload, onConflict: 'staff_id,shift_date');
  }

  /// Overtime hours booked against an employee in a given month.
  Future<Map<String, double>> overtimeForMonth(int year, int month) async {
    final Map<String, double> map = {};
    try {
      final from = DateTime(year, month, 1).toIso8601String().substring(0, 10);
      final to = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);
      final res = await _db
          .from('attendance_shifts')
          .select('staff_id, overtime_hours')
          .gte('shift_date', from)
          .lte('shift_date', to);
      for (final r in (res as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = m['staff_id'].toString();
        map[id] = (map[id] ?? 0.0) + ((m['overtime_hours'] as num?)?.toDouble() ?? 0.0);
      }
    } catch (e) {
      _capture(e);
    }
    return map;
  }

  // --------------------------------------------------------------------------
  // Payroll runs
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchPayrollRuns() async {
    try {
      final res = await _db
          .from('payroll_runs')
          .select()
          .order('period_start', ascending: false);
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPayslips(String runId) async {
    try {
      final res = await _db
          .from('payslips')
          .select()
          .eq('payroll_run_id', runId)
          .order('staff_name');
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  /// Computes a full payroll for the month (no writes).
  Future<Map<String, dynamic>> previewPayroll({
    required int year,
    required int month,
    required List<Map<String, dynamic>> staffList,
    required KenyaStatutoryParams params,
  }) async {
    final overtime = await overtimeForMonth(year, month);
    final periodStart = DateTime(year, month, 1);
    final periodEnd = DateTime(year, month + 1, 0);
    final hrLeave = HrLeaveService();

    final List<Map<String, dynamic>> slips = [];
    final branchNames = {for (final b in await fetchBranches()) b['id'].toString(): b['name'].toString()};

    double tGross = 0, tPaye = 0, tNssfE = 0, tNssfR = 0, tShif = 0,
        tAhlE = 0, tAhlR = 0, tNet = 0, tCost = 0;

    for (final s in staffList) {
      if ((s['status'] ?? 'Active').toString() != 'Active') continue;
      final staffId = s['id'].toString();
      final unpaidDays = await hrLeave.fetchUnpaidLeaveDaysForPeriod(
        staffId: staffId,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

      final res = computePayslip(
        staff: s,
        params: params,
        overtimeHours: overtime[staffId] ?? 0.0,
        unpaidLeaveDays: unpaidDays,
      );
      final branchId = s['branch_id']?.toString();
      slips.add({
        'staff_id': staffId,
        'staff_no': s['staff_no'] ?? '',
        'staff_name': '${s['first_name']} ${s['last_name']}',
        'job_title': s['job_title'] ?? '',
        'branch_name': branchNames[branchId] ?? 'Unassigned',
        ...res.toMap(),
      });
      tGross += res.grossPay;
      tPaye += res.paye;
      tNssfE += res.nssfEmployee;
      tNssfR += res.nssfEmployer;
      tShif += res.shif;
      tAhlE += res.ahlEmployee;
      tAhlR += res.ahlEmployer;
      tNet += res.netPay;
      tCost += res.employerCost;
    }

    return {
      'slips': slips,
      'headcount': slips.length,
      'gross_total': tGross,
      'paye_total': tPaye,
      'nssf_employee_total': tNssfE,
      'nssf_employer_total': tNssfR,
      'shif_total': tShif,
      'ahl_employee_total': tAhlE,
      'ahl_employer_total': tAhlR,
      'net_total': tNet,
      'employer_cost_total': tCost,
    };
  }

  /// Writes a payroll run + its payslips to Supabase.
  Future<String?> commitPayroll({
    required int year,
    required int month,
    required Map<String, dynamic> preview,
    String? branchId,
    String approvedBy = 'Payroll Officer',
  }) async {
    try {
      final start = DateTime(year, month, 1).toIso8601String().substring(0, 10);
      final end = DateTime(year, month + 1, 0).toIso8601String().substring(0, 10);
      final label = '$year-${month.toString().padLeft(2, '0')}';

      // Re-running a period replaces the draft rather than duplicating it.
      await _db
          .from('payroll_runs')
          .delete()
          .eq('period_start', start)
          .eq('status', 'Draft');

      final runInsert = await _db.from('payroll_runs').insert({
        'period_start': start,
        'period_end': end,
        'period_label': label,
        'branch_id': branchId,
        'status': 'Draft',
        'headcount': preview['headcount'],
        'gross_total': preview['gross_total'],
        'paye_total': preview['paye_total'],
        'nssf_employee_total': preview['nssf_employee_total'],
        'nssf_employer_total': preview['nssf_employer_total'],
        'shif_total': preview['shif_total'],
        'ahl_employee_total': preview['ahl_employee_total'],
        'ahl_employer_total': preview['ahl_employer_total'],
        'net_total': preview['net_total'],
        'employer_cost_total': preview['employer_cost_total'],
        'approved_by': approvedBy,
      }).select();

      final runId = (runInsert as List).first['id'].toString();
      final slips = (preview['slips'] as List).cast<Map<String, dynamic>>();
      await _db.from('payslips').insert(slips.map((s) => {...s, 'payroll_run_id': runId}).toList());
      return runId;
    } catch (e) {
      _capture(e);
      rethrow;
    }
  }

  Future<void> setRunStatus(String runId, String status) async {
    await _db.from('payroll_runs').update({
      'status': status,
      if (status == 'Approved') 'approved_at': DateTime.now().toIso8601String(),
      if (status == 'Paid') 'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', runId);
  }

  // --------------------------------------------------------------------------
  // Payroll journals -> GL (real double entry: gross expense vs statutory
  // liabilities, then net to bank/accrual)
  // --------------------------------------------------------------------------
  List<Map<String, dynamic>> payrollJournalLines(Map<String, dynamic> run) {
    double n(String k) => (run[k] as num?)?.toDouble() ?? 0.0;
    final gross = n('gross_total');
    final net = n('net_total');
    final paye = n('paye_total');
    final nssfE = n('nssf_employee_total');
    final nssfR = n('nssf_employer_total');
    final shif = n('shif_total');
    final ahlE = n('ahl_employee_total');
    final ahlR = n('ahl_employer_total');

    return [
      {'account_code': '6000', 'debit': gross, 'credit': 0.0, 'line_memo': 'Gross salaries & wages'},
      {'account_code': '6010', 'debit': nssfR + ahlR, 'credit': 0.0, 'line_memo': 'Employer statutory contributions'},
      {'account_code': '2200', 'debit': 0.0, 'credit': paye, 'line_memo': 'PAYE withheld (KRA)'},
      {'account_code': '2210', 'debit': 0.0, 'credit': nssfE + nssfR, 'line_memo': 'NSSF employee + employer'},
      {'account_code': '2220', 'debit': 0.0, 'credit': shif, 'line_memo': 'SHIF / SHA contributions'},
      {'account_code': '2230', 'debit': 0.0, 'credit': ahlE + ahlR, 'line_memo': 'Affordable Housing Levy'},
      {'account_code': '2300', 'debit': 0.0, 'credit': net, 'line_memo': 'Net pay due to employees'},
    ];
  }

  // --------------------------------------------------------------------------
  // Exports & Statutory P9 Tax Deduction Cards
  // --------------------------------------------------------------------------
  String _csv(List<String> headers, List<List<dynamic>> rows) {
    final buf = StringBuffer();
    buf.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));
    for (final r in rows) {
      buf.writeln(r.map((c) => '"${c.toString().replaceAll('"', '""')}"').join(','));
    }
    return buf.toString();
  }

  String bankPaylistCsv(List<Map<String, dynamic>> slips) => _csv(
        ['StaffNo', 'Employee', 'Bank', 'Branch', 'AccountNo', 'NetPay (KES)'],
        slips
            .map((s) => [
                  s['staff_no'] ?? '',
                  s['staff_name'] ?? '',
                  s['bank_name'] ?? '',
                  s['bank_branch'] ?? '',
                  s['bank_account'] ?? '',
                  ((s['net_pay'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
                ])
            .toList(),
      );

  String payslipRegisterCsv(List<Map<String, dynamic>> slips) => _csv(
        [
          'StaffNo', 'Employee', 'JobTitle', 'Branch', 'Gross', 'Allowances',
          'Overtime', 'UnpaidLeaveDays', 'UnpaidLeaveDeduction',
          'NSSF(EE)', 'NSSF(ER)', 'SHIF', 'AHL(EE)', 'AHL(ER)',
          'Pension', 'Taxable', 'PAYE', 'Relief', 'NetPay', 'EmployerCost'
        ],
        slips
            .map((s) => [
                  s['staff_no'], s['staff_name'], s['job_title'], s['branch_name'],
                  for (final k in [
                    'gross_pay', 'allowances', 'overtime_pay', 'unpaid_leave_days', 'unpaid_leave_deduction',
                    'nssf_employee', 'nssf_employer', 'shif', 'ahl_employee', 'ahl_employer',
                    'pension', 'taxable_income', 'paye', 'personal_relief',
                    'net_pay', 'employer_cost'
                  ])
                    ((s[k] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
                ])
            .toList(),
      );

  String statutoryRemittanceCsv(List<Map<String, dynamic>> slips, String body) {
    final rows = slips
        .map((s) => [
              s['staff_no'] ?? '',
              s['staff_name'] ?? '',
              s['national_id'] ?? s['nssf_no'] ?? '',
              ((s[body == 'PAYE' ? 'paye' : body == 'NSSF' ? 'nssf_employee' : body == 'SHIF' ? 'shif' : 'ahl_employee'] as num?)?.toDouble() ?? 0.0)
                  .toStringAsFixed(2),
            ])
        .toList();
    return _csv(['StaffNo', 'Employee', 'MembershipNo', '$body (KES)'], rows);
  }

  /// Generates a standard KRA P9A Tax Deduction Card CSV for a staff member
  String exportP9Card({
    required Map<String, dynamic> staff,
    required List<Map<String, dynamic>> payslipsForYear,
    required int year,
  }) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final rows = <List<dynamic>>[];
    double totalBasic = 0, totalGross = 0, totalNssf = 0, totalTaxable = 0, totalTaxCharged = 0, totalRelief = 0, totalPaye = 0;

    for (int m = 1; m <= 12; m++) {
      final monthName = months[m - 1];
      final monthKey = '$year-${m.toString().padLeft(2, '0')}';
      final slip = payslipsForYear.firstWhere(
        (p) => p['period_label'] == monthKey || (p['payroll_run']?['period_label'] == monthKey),
        orElse: () => <String, dynamic>{},
      );

      double n(String k) => (slip[k] as num?)?.toDouble() ?? 0.0;

      final gross = n('gross_pay');
      final allowances = n('allowances');
      final basic = (gross - allowances).clamp(0.0, gross);
      final nssf = n('nssf_employee');
      final taxable = n('taxable_income');
      final taxCharged = n('paye_before_relief');
      final relief = n('personal_relief');
      final paye = n('paye');

      totalBasic += basic;
      totalGross += gross;
      totalNssf += nssf;
      totalTaxable += taxable;
      totalTaxCharged += taxCharged;
      totalRelief += relief;
      totalPaye += paye;

      rows.add([
        monthName,
        basic.toStringAsFixed(2),
        allowances.toStringAsFixed(2),
        '0.00',
        gross.toStringAsFixed(2),
        (basic * 0.30).toStringAsFixed(2),
        nssf.toStringAsFixed(2),
        '30000.00',
        nssf.toStringAsFixed(2),
        taxable.toStringAsFixed(2),
        taxCharged.toStringAsFixed(2),
        relief.toStringAsFixed(2),
        '0.00',
        paye.toStringAsFixed(2),
      ]);
    }

    rows.add([
      'TOTALS',
      totalBasic.toStringAsFixed(2),
      (totalGross - totalBasic).toStringAsFixed(2),
      '0.00',
      totalGross.toStringAsFixed(2),
      (totalBasic * 0.30).toStringAsFixed(2),
      totalNssf.toStringAsFixed(2),
      '360000.00',
      totalNssf.toStringAsFixed(2),
      totalTaxable.toStringAsFixed(2),
      totalTaxCharged.toStringAsFixed(2),
      totalRelief.toStringAsFixed(2),
      '0.00',
      totalPaye.toStringAsFixed(2),
    ]);

    final headers = [
      'Month', 'Basic Salary (A)', 'Benefits/Allowances (B)', 'Quarters (C)',
      'Total Gross (D)', 'Defined Contrib 30% (E1)', 'Actual NSSF (E2)',
      'Fixed Cap (E3)', 'Retirement Deductions (G)', 'Net Taxable Pay (H)',
      'Tax Charged (J)', 'Personal Relief (K)', 'Insurance Relief (L)',
      'PAYE Tax (P)'
    ];

    final employeeHeader = '''
"KENYA REVENUE AUTHORITY - DOMESTIC TAXES DEPARTMENT"
"P9A TAX DEDUCTION CARD - YEAR $year"
"Employer Name: Mediocare Pharmacy Group Kenya"
"Employer PIN: P051234567Z"
"Employee Name: ${staff['first_name']} ${staff['last_name']}"
"Employee PIN: ${staff['kra_pin'] ?? 'N/A'}"
"Employee Staff No: ${staff['staff_no'] ?? 'N/A'}"
''';

    return employeeHeader + _csv(headers, rows);
  }
}
