import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveTypeConfig {
  final String id;
  final String code;
  final String name;
  final int defaultDays;
  final bool isStatutory;
  final double payPercentage;
  final String? description;

  const LeaveTypeConfig({
    required this.id,
    required this.code,
    required this.name,
    required this.defaultDays,
    this.isStatutory = true,
    this.payPercentage = 100.0,
    this.description,
  });

  factory LeaveTypeConfig.fromJson(Map<String, dynamic> json) {
    return LeaveTypeConfig(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? 'OTHER',
      name: json['name']?.toString() ?? 'Leave',
      defaultDays: (json['default_days'] as num?)?.toInt() ?? 0,
      isStatutory: json['is_statutory'] == true,
      payPercentage: (json['pay_percentage'] as num?)?.toDouble() ?? 100.0,
      description: json['description']?.toString(),
    );
  }
}

class LeaveBalanceData {
  final String staffId;
  final int year;
  final int annualEntitlement;
  final int annualUsed;
  final int sickEntitlement;
  final int sickUsed;
  final int unpaidUsed;

  int get annualRemaining => (annualEntitlement - annualUsed).clamp(0, annualEntitlement);
  int get sickRemaining => (sickEntitlement - sickUsed).clamp(0, sickEntitlement);

  const LeaveBalanceData({
    required this.staffId,
    required this.year,
    this.annualEntitlement = 21,
    this.annualUsed = 0,
    this.sickEntitlement = 30, // 14 days statutory (7 full + 7 half) + 16 days company policy
    this.sickUsed = 0,
    this.unpaidUsed = 0,
  });

  factory LeaveBalanceData.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceData(
      staffId: json['staff_id'] as String,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      annualEntitlement: (json['annual_entitlement'] as num?)?.toInt() ?? 21,
      annualUsed: (json['annual_used'] as num?)?.toInt() ?? 0,
      sickEntitlement: (json['sick_entitlement'] as num?)?.toInt() ?? 30,
      sickUsed: (json['sick_used'] as num?)?.toInt() ?? 0,
      unpaidUsed: (json['unpaid_used'] as num?)?.toInt() ?? 0,
    );
  }
}

class HrLeaveService {
  final SupabaseClient _db = Supabase.instance.client;

  /// Fetch all leave types and entitlements
  Future<List<LeaveTypeConfig>> fetchLeaveTypes() async {
    try {
      final res = await _db.from('leave_types').select().order('is_statutory', ascending: false);
      return (res as List).map((r) => LeaveTypeConfig.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      debugPrint('HrLeaveService.fetchLeaveTypes note: $e');
      return const [
        LeaveTypeConfig(
          id: '1',
          code: 'ANNUAL',
          name: 'Annual Leave',
          defaultDays: 21,
          isStatutory: true,
          description: 'Statutory minimum under Employment Act 2007 (21 working days with full pay)',
        ),
        LeaveTypeConfig(
          id: '2',
          code: 'SICK_FULL',
          name: 'Sick Leave (Full Pay)',
          defaultDays: 7,
          isStatutory: true,
          description: 'Statutory sick leave under Employment Act 2007 Section 30 (7 consecutive days on full pay)',
        ),
        LeaveTypeConfig(
          id: '3',
          code: 'SICK_HALF',
          name: 'Sick Leave (Half Pay)',
          defaultDays: 7,
          isStatutory: true,
          payPercentage: 50.0,
          description: 'Statutory sick leave under Employment Act 2007 Section 30 (7 consecutive days on half pay)',
        ),
        LeaveTypeConfig(
          id: '4',
          code: 'SICK_POLICY',
          name: 'Extended Sick Leave (Company Policy)',
          defaultDays: 16,
          isStatutory: false,
          description: 'Configurable company policy extending paid sick days beyond statutory minimum',
        ),
        LeaveTypeConfig(
          id: '5',
          code: 'MATERNITY',
          name: 'Maternity Leave',
          defaultDays: 90,
          isStatutory: true,
          description: 'Statutory maternity entitlement under Employment Act 2007 (3 calendar months fully paid)',
        ),
        LeaveTypeConfig(
          id: '6',
          code: 'PATERNITY',
          name: 'Paternity Leave',
          defaultDays: 14,
          isStatutory: true,
          description: 'Statutory paternity entitlement under Employment Act 2007 (2 weeks fully paid)',
        ),
        LeaveTypeConfig(
          id: '7',
          code: 'COMPASSIONATE',
          name: 'Compassionate Leave',
          defaultDays: 5,
          isStatutory: false,
          description: 'Configurable company policy for bereavement and immediate family emergencies',
        ),
        LeaveTypeConfig(
          id: '8',
          code: 'UNPAID',
          name: 'Unpaid Leave',
          defaultDays: 0,
          isStatutory: false,
          payPercentage: 0.0,
          description: 'Authorized unpaid leave that automatically feeds daily rate payroll deductions',
        ),
      ];
    }
  }

  /// Update leave type days / policy (Editable by HR)
  Future<void> updateLeaveType(String id, {required int defaultDays, String? description}) async {
    try {
      await _db.from('leave_types').update({
        'default_days': defaultDays,
        'description': ?description,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint('HrLeaveService.updateLeaveType note: $e');
    }
  }

  /// Fetch leave requests
  Future<List<Map<String, dynamic>>> fetchLeaveRequests({
    String? status,
    String? staffId,
  }) async {
    try {
      var query = _db.from('leave_requests').select();
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (staffId != null && staffId.isNotEmpty) {
        query = query.eq('staff_id', staffId);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      debugPrint('HrLeaveService.fetchLeaveRequests note: $e');
      return [];
    }
  }

  /// Get or initialize leave balance for a staff member
  Future<LeaveBalanceData> fetchStaffLeaveBalance(String staffId, {int? year}) async {
    final currentYear = year ?? DateTime.now().year;
    try {
      final res = await _db
          .from('leave_balances')
          .select()
          .eq('staff_id', staffId)
          .eq('year', currentYear)
          .maybeSingle();

      if (res != null) {
        return LeaveBalanceData.fromJson(Map<String, dynamic>.from(res));
      }

      // Compute from approved leave requests if balance row not yet created
      final approvedLeaves = await _db
          .from('leave_requests')
          .select('leave_type, total_days, start_date')
          .eq('staff_id', staffId)
          .eq('status', 'Approved');

      int annualDays = 0;
      int sickDays = 0;
      int unpaidDays = 0;

      for (var l in (approvedLeaves as List)) {
        final type = l['leave_type']?.toString();
        final days = (l['total_days'] as num?)?.toInt() ?? 0;
        final start = l['start_date'] != null ? DateTime.tryParse(l['start_date'].toString()) : null;
        if (start != null && start.year == currentYear) {
          if (type != null && type.contains('Annual')) annualDays += days;
          if (type != null && type.contains('Sick')) sickDays += days;
          if (type != null && type.contains('Unpaid')) unpaidDays += days;
        }
      }

      final initialBalance = {
        'staff_id': staffId,
        'year': currentYear,
        'annual_entitlement': 21,
        'annual_used': annualDays,
        'sick_entitlement': 30, // 14 statutory + 16 company policy
        'sick_used': sickDays,
        'unpaid_used': unpaidDays,
      };

      try {
        await _db.from('leave_balances').upsert(initialBalance);
      } catch (_) {}

      return LeaveBalanceData.fromJson(initialBalance);
    } catch (e) {
      debugPrint('fetchStaffLeaveBalance note: $e');
      return LeaveBalanceData(staffId: staffId, year: currentYear);
    }
  }

  /// Apply for leave
  Future<void> applyLeave({
    required String staffId,
    required String staffName,
    String? staffNo,
    String? department,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required int totalDays,
    String? reason,
  }) async {
    final payload = {
      'staff_id': staffId,
      'staff_name': staffName,
      'staff_no': staffNo,
      'department': department ?? 'Pharmacy Operations',
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate.toIso8601String().substring(0, 10),
      'total_days': totalDays,
      'reason': reason,
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    await _db.from('leave_requests').insert(payload);
  }

  /// Approve or reject leave request with manager comment & decrement balance
  Future<void> reviewLeaveRequest({
    required String requestId,
    required String status, // 'Approved' | 'Rejected'
    required String managerComment,
    required String reviewer,
  }) async {
    final leave = await _db.from('leave_requests').select().eq('id', requestId).maybeSingle();
    if (leave == null) return;

    await _db.from('leave_requests').update({
      'status': status,
      'manager_comment': managerComment,
      'reviewed_by': reviewer,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    // If approved, update leave balance
    if (status == 'Approved') {
      final staffId = leave['staff_id'] as String?;
      final leaveType = leave['leave_type'] as String?;
      final days = (leave['total_days'] as num?)?.toInt() ?? 0;
      final startDate = leave['start_date'] != null ? DateTime.tryParse(leave['start_date'].toString()) : DateTime.now();
      final year = startDate?.year ?? DateTime.now().year;

      if (staffId != null && days > 0) {
        final bal = await fetchStaffLeaveBalance(staffId, year: year);
        int newAnnualUsed = bal.annualUsed;
        int newSickUsed = bal.sickUsed;
        int newUnpaidUsed = bal.unpaidUsed;

        if (leaveType != null && leaveType.contains('Annual')) newAnnualUsed += days;
        if (leaveType != null && leaveType.contains('Sick')) newSickUsed += days;
        if (leaveType != null && leaveType.contains('Unpaid')) newUnpaidUsed += days;

        await _db.from('leave_balances').upsert({
          'staff_id': staffId,
          'year': year,
          'annual_entitlement': bal.annualEntitlement,
          'annual_used': newAnnualUsed,
          'sick_entitlement': bal.sickEntitlement,
          'sick_used': newSickUsed,
          'unpaid_used': newUnpaidUsed,
        });
      }
    }
  }

  /// Fetch approved unpaid leave days for a staff member within payroll period
  Future<int> fetchUnpaidLeaveDaysForPeriod({
    required String staffId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final res = await _db
          .from('leave_requests')
          .select('total_days, start_date, end_date')
          .eq('staff_id', staffId)
          .ilike('leave_type', '%Unpaid%')
          .eq('status', 'Approved')
          .gte('start_date', periodStart.toIso8601String().substring(0, 10))
          .lte('start_date', periodEnd.toIso8601String().substring(0, 10));

      int totalUnpaid = 0;
      for (var row in (res as List)) {
        totalUnpaid += (row['total_days'] as num?)?.toInt() ?? 0;
      }
      return totalUnpaid;
    } catch (e) {
      debugPrint('fetchUnpaidLeaveDaysForPeriod note: $e');
      return 0;
    }
  }
}
