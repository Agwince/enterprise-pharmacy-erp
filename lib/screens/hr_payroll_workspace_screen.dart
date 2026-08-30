import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/accounting_service.dart';
import '../services/payroll_service.dart';
import '../services/hr_leave_service.dart';
import '../widgets/leave_application_form.dart';

/// HR & Payroll Workspace — Sage People-class people management with full
/// Kenyan statutory payroll (KRA PAYE, NSSF Tier I/II, SHIF/SHA, Housing Levy).
/// Every employee, shift and payslip is a live Supabase record.
class HrPayrollWorkspaceScreen extends StatefulWidget {
  const HrPayrollWorkspaceScreen({super.key});

  @override
  State<HrPayrollWorkspaceScreen> createState() =>
      _HrPayrollWorkspaceScreenState();
}

class _HrPayrollWorkspaceScreenState extends State<HrPayrollWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  final PayrollService _pay = PayrollService();
  final AccountingService _acct = AccountingService();
  final HrLeaveService _leaveService = HrLeaveService();
  final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _compact = NumberFormat('#,##0', 'en_US');

  late TabController _tabs;
  bool _loading = true;
  bool _busy = false;

  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _runs = [];
  List<Map<String, dynamic>> _payslips = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  List<LeaveTypeConfig> _leaveTypeConfigs = [];

  DateTime _attendanceDay = DateTime.now();
  Map<String, dynamic>? _preview;
  String? _selectedRunId;
  String? _branchFilter;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  KenyaStatutoryParams _params = const KenyaStatutoryParams();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final staff = await _pay.fetchStaff(
        branchId: _branchFilter == 'ALL' ? null : _branchFilter);
    final branches = await _pay.fetchBranches();
    final runs = await _pay.fetchPayrollRuns();
    final shifts = await _pay.fetchShifts(_attendanceDay);
    final leaves = await _leaveService.fetchLeaveRequests();
    final leaveTypes = await _leaveService.fetchLeaveTypes();
    if (!mounted) return;
    setState(() {
      _staff = staff;
      _branches = branches;
      _runs = runs;
      _shifts = shifts;
      _leaveRequests = leaves;
      _leaveTypeConfigs = leaveTypes;
      _loading = false;
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? Colors.redAccent : Colors.purpleAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String get _periodLabel =>
      '$_year-${_month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final active = _staff
        .where((s) => (s['status'] ?? 'Active').toString() == 'Active')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1128),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.badge_rounded,
                  color: Colors.purpleAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'HR & Payroll Workspace',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: isDesktop ? 17 : 15,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Sage People-class • ${_staff.length} employees on file • $active active',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Employees'),
            Tab(text: 'Structure'),
            Tab(text: 'Attendance'),
            Tab(text: 'Leave Management'),
            Tab(text: 'Payroll Run'),
            Tab(text: 'Payslips'),
            Tab(text: 'Statutory & KRA'),
          ],
        ),
      ),
      body: _pay.schemaMissing
          ? _buildSchemaNotice()
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.purpleAccent))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildEmployees(isDesktop),
                    _buildStructure(isDesktop),
                    _buildAttendance(isDesktop),
                    _buildLeaveManagement(isDesktop),
                    _buildPayrollRun(isDesktop),
                    _buildPayslips(isDesktop),
                    _buildStatutory(isDesktop),
                  ],
                ),
    );
  }

  Widget _buildSchemaNotice() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.storage_rounded, color: Colors.purpleAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('HR & payroll schema not installed',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(
                  'The tables staff, attendance_shifts, payroll_runs and payslips do not exist '
                  'yet. Run the migration below in your Supabase SQL Editor, then refresh. '
                  'No demo employees will ever be shown in their place.',
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SelectableText(
                    'supabase/migrations/20260829_mediocare_finance_hr.sql',
                    style: TextStyle(
                        color: Colors.tealAccent,
                        fontFamily: 'monospace',
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Re-check database'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // EMPLOYEES
  // ==========================================================================
  Widget _buildEmployees(bool isDesktop) {
    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.purpleAccent,
      child: ListView(
        padding: EdgeInsets.all(isDesktop ? 24 : 14),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Employee Master',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
              ElevatedButton.icon(
                onPressed: () => _openStaffDialog(null),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Employee'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_staff.isEmpty)
            _empty('No employees on file. Add your real staff — nothing is pre-filled.')
          else
            ..._staff.map((s) => _employeeCard(s, isDesktop)),
        ],
      ),
    );
  }

  Widget _employeeCard(Map<String, dynamic> s, bool isDesktop) {
    final name = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
    final active = (s['status'] ?? 'Active').toString() == 'Active';
    final branch = _branches
        .firstWhere((b) => b['id'].toString() == s['branch_id']?.toString(),
            orElse: () => {'name': 'Unassigned'})['name']
        .toString();
    final gross = ((s['basic_salary'] as num?)?.toDouble() ?? 0.0) +
        ((s['house_allowance'] as num?)?.toDouble() ?? 0.0) +
        ((s['transport_allowance'] as num?)?.toDouble() ?? 0.0) +
        ((s['medical_allowance'] as num?)?.toDouble() ?? 0.0) +
        ((s['other_allowance'] as num?)?.toDouble() ?? 0.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 520;
        return Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment:
              wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.purpleAccent.withValues(alpha: 0.18),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.purpleAccent, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${s['job_title'] ?? '—'} • ${s['staff_no'] ?? 'no staff no'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(branch, Colors.cyanAccent),
                      _chip(s['department']?.toString() ?? '—', Colors.tealAccent),
                      _chip('KES ${_compact.format(gross)}/mth', Colors.greenAccent),
                    ],
                  ),
                ],
              ),
            ),
            if (!wide) const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                _chip(active ? 'Active' : s['status'].toString(),
                    active ? Colors.greenAccent : Colors.orangeAccent),
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      color: Colors.amberAccent, size: 18),
                  onPressed: () => _openStaffDialog(s),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: Icon(
                      active ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                      color: Colors.white54,
                      size: 18),
                  onPressed: () async {
                    await _pay.updateStaffStatus(
                        s['id'].toString(), active ? 'Suspended' : 'Active');
                    _snack('${s['first_name']} status updated');
                    await _load();
                  },
                  tooltip: active ? 'Suspend' : 'Reactivate',
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  void _openStaffDialog(Map<String, dynamic>? existing) {
    final e = existing;
    double d(String k) => (e?[k] as num?)?.toDouble() ?? 0.0;
    final ctrls = {
      'staff_no': TextEditingController(text: e?['staff_no']?.toString() ?? ''),
      'first_name': TextEditingController(text: e?['first_name']?.toString() ?? ''),
      'last_name': TextEditingController(text: e?['last_name']?.toString() ?? ''),
      'national_id': TextEditingController(text: e?['national_id']?.toString() ?? ''),
      'kra_pin': TextEditingController(text: e?['kra_pin']?.toString() ?? ''),
      'nssf_no': TextEditingController(text: e?['nssf_no']?.toString() ?? ''),
      'sha_no': TextEditingController(text: e?['sha_no']?.toString() ?? ''),
      'phone': TextEditingController(text: e?['phone']?.toString() ?? ''),
      'email': TextEditingController(text: e?['email']?.toString() ?? ''),
      'job_title': TextEditingController(text: e?['job_title']?.toString() ?? ''),
      'department': TextEditingController(text: e?['department']?.toString() ?? ''),
      'basic_salary': TextEditingController(text: e != null ? d('basic_salary').toStringAsFixed(0) : ''),
      'house_allowance':
          TextEditingController(text: e != null ? d('house_allowance').toStringAsFixed(0) : ''),
      'transport_allowance':
          TextEditingController(text: e != null ? d('transport_allowance').toStringAsFixed(0) : ''),
      'medical_allowance':
          TextEditingController(text: e != null ? d('medical_allowance').toStringAsFixed(0) : ''),
      'other_allowance':
          TextEditingController(text: e != null ? d('other_allowance').toStringAsFixed(0) : ''),
      'pension_contribution':
          TextEditingController(text: e != null ? d('pension_contribution').toStringAsFixed(0) : ''),
      'bank_name': TextEditingController(text: e?['bank_name']?.toString() ?? ''),
      'bank_branch': TextEditingController(text: e?['bank_branch']?.toString() ?? ''),
      'bank_account': TextEditingController(text: e?['bank_account']?.toString() ?? ''),
    };
    String branchId = e?['branch_id']?.toString() ??
        (_branches.isNotEmpty ? _branches.first['id'].toString() : '');
    String empType = e?['employment_type']?.toString() ?? 'Permanent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setS) {
        final basic = double.tryParse(ctrls['basic_salary']!.text) ?? 0.0;
        final house = double.tryParse(ctrls['house_allowance']!.text) ?? 0.0;
        final trans = double.tryParse(ctrls['transport_allowance']!.text) ?? 0.0;
        final med = double.tryParse(ctrls['medical_allowance']!.text) ?? 0.0;
        final other = double.tryParse(ctrls['other_allowance']!.text) ?? 0.0;
        final gross = basic + house + trans + med + other;
        final est = PayrollService.computePayslip(
            staff: {'basic_salary': basic, 'other_allowance': other}, params: _params);

        return AlertDialog(
          backgroundColor: const Color(0xFF132043),
          title: Text(e == null ? 'New Employee' : 'Edit Employee',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: _f(ctrls['staff_no']!, 'Staff No')),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['first_name']!, 'First Name')),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['last_name']!, 'Surname')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(ctrls['job_title']!, 'Job Title')),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['department']!, 'Department')),
              ]),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: branchId.isEmpty ? null : branchId,
                isExpanded: true,
                dropdownColor: const Color(0xFF132043),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                    labelText: 'Branch',
                    labelStyle: TextStyle(color: Colors.white54)),
                items: _branches
                    .map((b) => DropdownMenuItem<String>(
                        value: b['id'].toString(), child: Text(b['name'].toString())))
                    .toList(),
                onChanged: (v) => setS(() => branchId = v ?? ''),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: empType,
                isExpanded: true,
                dropdownColor: const Color(0xFF132043),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                    labelText: 'Employment Type',
                    labelStyle: TextStyle(color: Colors.white54)),
                items: const [
                  DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                  DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                  DropdownMenuItem(value: 'Casual', child: Text('Casual')),
                  DropdownMenuItem(value: 'Intern', child: Text('Intern')),
                ],
                onChanged: (v) => setS(() => empType = v ?? 'Permanent'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(ctrls['national_id']!, 'National ID')),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['kra_pin']!, 'KRA PIN')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(ctrls['nssf_no']!, 'NSSF No')),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['sha_no']!, 'SHA / SHIF No')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(ctrls['phone']!, 'Phone')),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['email']!, 'Email')),
              ]),
              const Divider(color: Colors.white12, height: 24),
              Text('Compensation (KES / month)',
                  style: GoogleFonts.inter(
                      color: Colors.purpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(ctrls['basic_salary']!, 'Basic', num: true)),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['house_allowance']!, 'House', num: true)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(ctrls['transport_allowance']!, 'Transport', num: true)),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['medical_allowance']!, 'Medical', num: true)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _f(ctrls['other_allowance']!, 'Other', num: true)),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['pension_contribution']!, 'Pension', num: true)),
              ]),
              const Divider(color: Colors.white12, height: 24),
              Row(children: [
                Expanded(child: _f(ctrls['bank_name']!, 'Bank')),
                const SizedBox(width: 8),
                Expanded(child: _f(ctrls['bank_branch']!, 'Bank Branch')),
              ]),
              const SizedBox(height: 10),
              _f(ctrls['bank_account']!, 'Bank Account No'),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gross Pay: KES ${_money.format(gross)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(
                      'Est. PAYE ${_money.format(est.paye)} • NSSF ${_money.format(est.nssfEmployee)} • '
                      'SHIF ${_money.format(est.shif)} • AHL ${_money.format(est.ahlEmployee)} • '
                      'Net ${_money.format(est.netPay)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.black),
              onPressed: () async {
                if (ctrls['first_name']!.text.trim().isEmpty) return;
                final payload = <String, dynamic>{
                  for (final k in ctrls.keys)
                    k: [
                      'basic_salary', 'house_allowance', 'transport_allowance',
                      'medical_allowance', 'other_allowance', 'pension_contribution'
                    ].contains(k)
                        ? (double.tryParse(ctrls[k]!.text) ?? 0.0)
                        : ctrls[k]!.text.trim(),
                  'branch_id': branchId,
                  'employment_type': empType,
                  if (e == null) 'status': 'Active',
                  if (e == null && ctrls['staff_no']!.text.trim().isEmpty)
                    'staff_no':
                        'MC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
                };
                try {
                  await _pay.saveStaff(payload, id: e?['id']?.toString());
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('Employee saved');
                  await _load();
                } catch (err) {
                  _snack('Save failed: $err', error: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  // ==========================================================================
  // STRUCTURE
  // ==========================================================================
  Widget _buildStructure(bool isDesktop) {
    final byDept = <String, List<Map<String, dynamic>>>{};
    final byBranch = <String, List<Map<String, dynamic>>>{};
    for (final s in _staff) {
      byDept.putIfAbsent(s['department']?.toString() ?? 'Unassigned', () => []).add(s);
      byBranch
          .putIfAbsent(
              _branches
                  .firstWhere(
                      (b) => b['id'].toString() == s['branch_id']?.toString(),
                      orElse: () => {'name': 'Unassigned'})['name']
                  .toString(),
              () => [])
          .add(s);
    }
    double monthlyGross = 0.0;
    for (final s in _staff) {
      monthlyGross += (((s['basic_salary'] as num?)?.toDouble() ?? 0.0) +
          ((s['house_allowance'] as num?)?.toDouble() ?? 0.0) +
          ((s['transport_allowance'] as num?)?.toDouble() ?? 0.0) +
          ((s['medical_allowance'] as num?)?.toDouble() ?? 0.0) +
          ((s['other_allowance'] as num?)?.toDouble() ?? 0.0));
    }

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi('Headcount', '${_staff.length}', Icons.groups_rounded,
                Colors.purpleAccent, subtitle: 'live staff table'),
            _kpi('Departments', '${byDept.length}', Icons.domain_rounded,
                Colors.cyanAccent, subtitle: 'derived from staff'),
            _kpi('Branches Covered', '${byBranch.length}', Icons.store_rounded,
                Colors.tealAccent, subtitle: 'derived from staff'),
            _kpi('Monthly Gross Cost', 'KES ${_compact.format(monthlyGross)}',
                Icons.payments_rounded, Colors.greenAccent,
                subtitle: 'basic + allowances'),
          ],
        ),
        const SizedBox(height: 16),
        _panel(
          title: 'By Branch',
          icon: Icons.store_rounded,
          accent: Colors.tealAccent,
          child: _structureList(byBranch, isDesktop),
        ),
        const SizedBox(height: 14),
        _panel(
          title: 'By Department',
          icon: Icons.domain_rounded,
          accent: Colors.cyanAccent,
          child: _structureList(byDept, isDesktop),
        ),
      ],
    );
  }

  Widget _structureList(Map<String, List<Map<String, dynamic>>> map, bool isDesktop) {
    if (map.isEmpty) {
      return Text('No employees captured yet.',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12));
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Column(
      children: entries.map((e) {
        final pct = _staff.isEmpty ? 0.0 : e.value.length / _staff.length;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(e.key,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${e.value.length} staff',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Colors.purpleAccent),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================================================
  // ATTENDANCE
  // ==========================================================================
  Widget _buildAttendance(bool isDesktop) {
    final dayLabel = DateFormat('EEE, dd MMM yyyy').format(_attendanceDay);
    final shiftByStaff = {
      for (final s in _shifts) s['staff_id'].toString(): s
    };

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
              onPressed: () async {
                setState(() =>
                    _attendanceDay = _attendanceDay.subtract(const Duration(days: 1)));
                _shifts = await _pay.fetchShifts(_attendanceDay);
                setState(() {});
              },
            ),
            Expanded(
              child: Text(dayLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              onPressed: () async {
                setState(() =>
                    _attendanceDay = _attendanceDay.add(const Duration(days: 1)));
                _shifts = await _pay.fetchShifts(_attendanceDay);
                setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_staff.isEmpty)
          _empty('Add employees first — attendance is recorded against real staff.')
        else
          ..._staff.where((s) => (s['status'] ?? 'Active') == 'Active').map((s) {
            final rec = shiftByStaff[s['id'].toString()];
            final status = rec?['status']?.toString() ?? 'Not recorded';
            final color = status == 'Present'
                ? Colors.greenAccent
                : status == 'Absent'
                    ? Colors.redAccent
                    : status == 'Leave'
                        ? Colors.blueAccent
                        : Colors.white54;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 460;
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: wide
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${s['first_name']} ${s['last_name']}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                            '${s['job_title'] ?? '—'} • In ${rec?['clock_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(rec!['clock_in'].toString())) : '—'}'
                            ' • Out ${rec?['clock_out'] != null ? DateFormat('HH:mm').format(DateTime.parse(rec!['clock_out'].toString())) : '—'}'
                            ' • OT ${(rec?['overtime_hours'] as num? ?? 0).toString()}h',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    SizedBox(width: wide ? 10 : 0, height: wide ? 0 : 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        _chip(status, color),
                        _actionBtn('In', Colors.greenAccent, () async {
                          await _pay.recordShift(
                            staffId: s['id'].toString(),
                            day: _attendanceDay,
                            status: 'Present',
                            branchId: s['branch_id']?.toString(),
                            clockIn: DateTime.now(),
                            clockOut: rec?['clock_out'] != null
                                ? DateTime.tryParse(rec!['clock_out'].toString())
                                : null,
                            overtimeHours:
                                (rec?['overtime_hours'] as num?)?.toDouble() ?? 0.0,
                          );
                          _shifts = await _pay.fetchShifts(_attendanceDay);
                          setState(() {});
                        }),
                        _actionBtn('Out', Colors.orangeAccent, () async {
                          await _pay.recordShift(
                            staffId: s['id'].toString(),
                            day: _attendanceDay,
                            status: 'Present',
                            branchId: s['branch_id']?.toString(),
                            clockIn: rec?['clock_in'] != null
                                ? DateTime.tryParse(rec!['clock_in'].toString())
                                : DateTime.now(),
                            clockOut: DateTime.now(),
                            overtimeHours:
                                (rec?['overtime_hours'] as num?)?.toDouble() ?? 0.0,
                          );
                          _shifts = await _pay.fetchShifts(_attendanceDay);
                          setState(() {});
                        }),
                        _actionBtn('Leave', Colors.blueAccent, () async {
                          await _pay.recordShift(
                            staffId: s['id'].toString(),
                            day: _attendanceDay,
                            status: 'Leave',
                            branchId: s['branch_id']?.toString(),
                          );
                          _shifts = await _pay.fetchShifts(_attendanceDay);
                          setState(() {});
                        }),
                        _actionBtn('Absent', Colors.redAccent, () async {
                          await _pay.recordShift(
                            staffId: s['id'].toString(),
                            day: _attendanceDay,
                            status: 'Absent',
                            branchId: s['branch_id']?.toString(),
                          );
                          _shifts = await _pay.fetchShifts(_attendanceDay);
                          setState(() {});
                        }),
                      ],
                    ),
                  ],
                );
              }),
            );
          }),
        const SizedBox(height: 10),
        Text(
          'Overtime hours booked in a month flow straight into that month\'s payroll computation.',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================================================
  // LEAVE MANAGEMENT & BALANCES
  // ==========================================================================
  Widget _buildLeaveManagement(bool isDesktop) {
    final pending = _leaveRequests.where((r) => r['status'] == 'Pending').length;
    final approved = _leaveRequests.where((r) => r['status'] == 'Approved').length;
    final unpaid = _leaveRequests.where((r) => r['leave_type'] == 'Unpaid' && r['status'] == 'Approved').length;

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        // Summary KPIs
        Row(
          children: [
            Expanded(
              child: _kpi(
                'Pending Review',
                '$pending',
                Icons.pending_actions_rounded,
                Colors.amberAccent,
                subtitle: 'Awaiting manager sign-off',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kpi(
                'Approved Leaves',
                '$approved',
                Icons.verified_rounded,
                Colors.tealAccent,
                subtitle: 'Active & scheduled leaves',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kpi(
                'Unpaid Leaves',
                '$unpaid',
                Icons.money_off_rounded,
                Colors.orangeAccent,
                subtitle: 'Feeds payroll deductions',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Action Toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Leave Applications & Balances',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: LeaveApplicationForm(
                        onSubmitted: _load,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('Apply for Leave'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Leave Requests Panel
        _panel(
          title: 'Leave Requests Queue (${_leaveRequests.length})',
          icon: Icons.assignment_outlined,
          accent: Colors.purpleAccent,
          child: _leaveRequests.isEmpty
              ? _empty('No leave requests submitted yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _leaveRequests.length,
                  separatorBuilder: (ctx, i) => const Divider(color: Colors.white10, height: 16),
                  itemBuilder: (context, index) {
                    final req = _leaveRequests[index];
                    final isPending = req['status'] == 'Pending';
                    final isApproved = req['status'] == 'Approved';

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    req['staff_name'] ?? 'Staff',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _chip(
                                    req['leave_type'] ?? 'Annual',
                                    req['leave_type'] == 'Unpaid'
                                        ? Colors.orangeAccent
                                        : Colors.tealAccent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${req['start_date']} ➔ ${req['end_date']} (${req['total_days']} days)',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              if (req['reason'] != null && req['reason'].toString().isNotEmpty)
                                Text(
                                  'Reason: ${req['reason']}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                              if (req['manager_comment'] != null && req['manager_comment'].toString().isNotEmpty)
                                Text(
                                  'Manager: ${req['manager_comment']}',
                                  style: TextStyle(
                                    color: isApproved ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: isPending
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
                                        tooltip: 'Approve Leave',
                                        onPressed: () => _showReviewModal(req, true),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
                                        tooltip: 'Reject Leave',
                                        onPressed: () => _showReviewModal(req, false),
                                      ),
                                    ],
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isApproved
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      req['status'] ?? 'Pending',
                                      style: TextStyle(
                                        color: isApproved ? Colors.greenAccent : Colors.redAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),

        // Leave Entitlements & Policy Schedule Panel
        _panel(
          title: 'Statutory Entitlements & Company Leave Policies (${_leaveTypeConfigs.length})',
          icon: Icons.rule_folder_outlined,
          accent: Colors.tealAccent,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _leaveTypeConfigs.length,
            separatorBuilder: (ctx, i) => const Divider(color: Colors.white10, height: 16),
            itemBuilder: (context, index) {
              final type = _leaveTypeConfigs[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              type.name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: type.isStatutory
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : Colors.purple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                type.isStatutory ? 'STATUTORY (KENYA LAW)' : 'COMPANY POLICY',
                                style: TextStyle(
                                  color: type.isStatutory ? Colors.lightBlueAccent : Colors.purpleAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (type.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            type.description!,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '${type.defaultDays} days',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.tealAccent, size: 20),
                        tooltip: 'Edit Entitlement Days',
                        onPressed: () => _showEditLeaveTypeModal(type),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditLeaveTypeModal(LeaveTypeConfig type) {
    final daysCtrl = TextEditingController(text: '${type.defaultDays}');
    final descCtrl = TextEditingController(text: type.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Edit Entitlement: ${type.name}',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.isStatutory
                    ? 'Kenya Statutory Standard: ${type.code == "SICK_FULL" || type.code == "SICK_HALF" ? "7 days full pay + 7 days half pay (Sec 30)" : "${type.defaultDays} days"}'
                    : 'Configurable Group Policy Benefit',
                style: TextStyle(
                  color: type.isStatutory ? Colors.lightBlueAccent : Colors.purpleAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Default Annual Days',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Policy Description / Statutory Citation',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final newDays = int.tryParse(daysCtrl.text.trim()) ?? type.defaultDays;
              final newDesc = descCtrl.text.trim();
              Navigator.pop(ctx);
              await _leaveService.updateLeaveType(type.id, defaultDays: newDays, description: newDesc);
              _load();
            },
            child: const Text('Save Entitlement'),
          ),
        ],
      ),
    );
  }

  void _showReviewModal(Map<String, dynamic> req, bool approve) {
    final commentCtrl = TextEditingController(text: approve ? 'Approved per leave policy' : 'Operational requirements');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          approve ? 'Approve Leave Request' : 'Reject Leave Request',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${req['staff_name']} • ${req['leave_type']} Leave (${req['total_days']} days)',
                style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Manager Comment / Approval Notes',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.greenAccent : Colors.redAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                await _leaveService.reviewLeaveRequest(
                  requestId: req['id'].toString(),
                  status: approve ? 'Approved' : 'Rejected',
                  managerComment: commentCtrl.text.trim(),
                  reviewer: 'HR Director',
                );
                _snack(approve ? 'Leave request approved & balance updated.' : 'Leave request rejected.');
                _load();
              } catch (e) {
                _snack('Error updating leave: $e', error: true);
                setState(() => _loading = false);
              }
            },
            child: Text(approve ? 'Confirm Approval' : 'Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PAYROLL RUN
  // ==========================================================================
  Widget _buildPayrollRun(bool isDesktop) {
    final months = List.generate(12, (i) {
      final d = DateTime(DateTime.now().year, DateTime.now().month - i);
      return {'year': d.year, 'month': d.month};
    });

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 560;
          return Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_periodLabel),
                  initialValue: _periodLabel,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF132043),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                      labelText: 'Payroll Period',
                      labelStyle: TextStyle(color: Colors.white54),
                      isDense: true),
                  items: months
                      .map((m) => DropdownMenuItem<String>(
                            value: '${m['year']}-${m['month'].toString().padLeft(2, '0')}',
                            child: Text(DateFormat('MMMM yyyy')
                                .format(DateTime(m['year']!, m['month']!))),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final parts = v.split('-');
                    setState(() {
                      _year = int.parse(parts[0]);
                      _month = int.parse(parts[1]);
                      _preview = null;
                    });
                  },
                ),
              ),
              SizedBox(width: wide ? 12 : 0, height: wide ? 0 : 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_branchFilter ?? 'ALL'),
                  initialValue: _branchFilter ?? 'ALL',
                  isExpanded: true,
                  dropdownColor: const Color(0xFF132043),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                      labelText: 'Branch Scope',
                      labelStyle: TextStyle(color: Colors.white54),
                      isDense: true),
                  items: [
                    const DropdownMenuItem<String>(
                        value: 'ALL', child: Text('All Branches (Group)')),
                    ..._branches.map((b) => DropdownMenuItem<String>(
                        value: b['id'].toString(),
                        child: Text(b['name'].toString(),
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) async {
                    setState(() {
                      _branchFilter = v == 'ALL' ? null : v;
                      _preview = null;
                    });
                    await _load();
                  },
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _computePreview,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.calculate_rounded, size: 18),
            label: const Text('Compute Payroll from Live Staff Data'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.black),
          ),
        ),
        const SizedBox(height: 16),
        if (_preview != null) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi('Headcount', '${_preview!['headcount']}', Icons.groups_rounded,
                  Colors.purpleAccent),
              _kpi('Gross Pay', 'KES ${_compact.format(_preview!['gross_total'])}',
                  Icons.payments_rounded, Colors.tealAccent),
              _kpi('PAYE', 'KES ${_compact.format(_preview!['paye_total'])}',
                  Icons.receipt_rounded, Colors.redAccent),
              _kpi('NSSF (EE+ER)',
                  'KES ${_compact.format((_preview!['nssf_employee_total'] as double) + (_preview!['nssf_employer_total'] as double))}',
                  Icons.shield_rounded, Colors.cyanAccent),
              _kpi('SHIF / SHA', 'KES ${_compact.format(_preview!['shif_total'])}',
                  Icons.health_and_safety_rounded, Colors.blueAccent),
              _kpi('Housing Levy',
                  'KES ${_compact.format((_preview!['ahl_employee_total'] as double) + (_preview!['ahl_employer_total'] as double))}',
                  Icons.home_work_rounded, Colors.orangeAccent),
              _kpi('Net Pay', 'KES ${_compact.format(_preview!['net_total'])}',
                  Icons.account_balance_wallet_rounded, Colors.greenAccent),
              _kpi('Total Employer Cost',
                  'KES ${_compact.format(_preview!['employer_cost_total'])}',
                  Icons.business_center_rounded, Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 14),
          _panel(
            title: 'Computed Payslips (${_preview!['headcount']})',
            icon: Icons.receipt_long_rounded,
            child: Column(
              children: [
                ...(_preview!['slips'] as List)
                    .cast<Map<String, dynamic>>()
                    .take(isDesktop ? 50 : 20)
                    .map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(p['staff_name'].toString(),
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        '${p['branch_name']} • Gross ${_compact.format(p['gross_pay'])} • '
                                        'PAYE ${_compact.format(p['paye'])}',
                                        style: const TextStyle(
                                            color: Colors.white54, fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Text(
                                  'KES ${_compact.format((p['net_pay'] as num).toDouble())}',
                                  style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        )),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _commitRun,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save Payroll Run to Supabase'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _panel(
          title: 'Saved Payroll Runs',
          icon: Icons.history_rounded,
          accent: Colors.cyanAccent,
          child: _runs.isEmpty
              ? Text('No payroll runs saved yet.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))
              : Column(
                  children: _runs.map((r) {
                    final status = r['status'].toString();
                    final color = status == 'Paid'
                        ? Colors.greenAccent
                        : status == 'Approved'
                            ? Colors.cyanAccent
                            : Colors.orangeAccent;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: LayoutBuilder(builder: (context, c) {
                        final wide = c.maxWidth >= 440;
                        return Flex(
                          direction: wide ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: wide
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(r['period_label'].toString(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  Text(
                                      '${r['headcount']} staff • Net KES ${_compact.format((r['net_total'] as num?)?.toDouble() ?? 0.0)}',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 10)),
                                ],
                              ),
                            ),
                            SizedBox(width: wide ? 10 : 0, height: wide ? 0 : 8),
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _chip(status, color),
                                if (status == 'Draft')
                                  _actionBtn('Approve', Colors.cyanAccent,
                                      () async {
                                    await _pay.setRunStatus(
                                        r['id'].toString(), 'Approved');
                                    await _load();
                                  }),
                                if (status == 'Approved') ...[
                                  _actionBtn('Mark Paid', Colors.greenAccent,
                                      () async {
                                    await _pay.setRunStatus(
                                        r['id'].toString(), 'Paid');
                                    await _load();
                                  }),
                                  _actionBtn('Post to GL', Colors.purpleAccent,
                                      () => _postPayrollToGl(r)),
                                ],
                                _actionBtn('View', Colors.white54, () async {
                                  final slips = await _pay
                                      .fetchPayslips(r['id'].toString());
                                  setState(() {
                                    _selectedRunId = r['id'].toString();
                                    _payslips = slips;
                                  });
                                  _tabs.animateTo(4);
                                }),
                              ],
                            ),
                          ],
                        );
                      }),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _computePreview() async {
    setState(() => _busy = true);
    final preview = await _pay.previewPayroll(
      year: _year,
      month: _month,
      staffList: _staff,
      params: _params,
    );
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _busy = false;
    });
    if ((preview['headcount'] as int) == 0) {
      _snack('No active employees to pay for this period', error: true);
    }
  }

  Future<void> _commitRun() async {
    if (_preview == null) return;
    setState(() => _busy = true);
    try {
      final id = await _pay.commitPayroll(
        year: _year,
        month: _month,
        preview: _preview!,
        branchId: _branchFilter,
      );
      _snack('Payroll run $_periodLabel saved');
      setState(() {
        _selectedRunId = id;
        _busy = false;
      });
      await _load();
      final slips = await _pay.fetchPayslips(id!);
      if (mounted) setState(() => _payslips = slips);
    } catch (e) {
      setState(() => _busy = false);
      _snack('Save failed: $e', error: true);
    }
  }

  Future<void> _postPayrollToGl(Map<String, dynamic> run) async {
    try {
      final lines = _pay.payrollJournalLines(run);
      await _acct.postJournal(
        date: DateTime.tryParse(run['period_end'].toString()) ?? DateTime.now(),
        memo: 'Payroll ${run['period_label']} — ${run['headcount']} employees',
        reference: 'PAY-${run['period_label']}',
        sourceModule: 'payroll',
        sourceId: run['id'].toString(),
        branchId: run['branch_id']?.toString(),
        lines: lines
            .map((l) => JournalLineDraft(
                  accountCode: l['account_code'].toString(),
                  debit: (l['debit'] as num).toDouble(),
                  credit: (l['credit'] as num).toDouble(),
                  lineMemo: l['line_memo']?.toString(),
                ))
            .toList(),
      );
      _snack('Payroll posted to the general ledger');
    } catch (e) {
      _snack('GL posting failed: $e', error: true);
    }
  }

  // ==========================================================================
  // PAYSLIPS
  // ==========================================================================
  Widget _buildPayslips(bool isDesktop) {
    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedRunId),
          initialValue: _selectedRunId,
          isExpanded: true,
          dropdownColor: const Color(0xFF132043),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
              labelText: 'Payroll Run',
              labelStyle: TextStyle(color: Colors.white54)),
          items: _runs
              .map((r) => DropdownMenuItem<String>(
                    value: r['id'].toString(),
                    child: Text(
                        '${r['period_label']} — ${r['headcount']} staff — ${r['status']}',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            final slips = await _pay.fetchPayslips(v);
            setState(() {
              _selectedRunId = v;
              _payslips = slips;
            });
          },
        ),
        const SizedBox(height: 14),
        if (_payslips.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Text('${_payslips.length} payslips',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              TextButton.icon(
                onPressed: () =>
                    _showCsv('Bank Pay-list (CSV)', _pay.bankPaylistCsv(_payslips)),
                icon: const Icon(Icons.account_balance_rounded, size: 16),
                label: const Text('Bank Pay-list'),
                style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
              ),
              TextButton.icon(
                onPressed: () => _showCsv(
                    'Payslip Register (CSV)', _pay.payslipRegisterCsv(_payslips)),
                icon: const Icon(Icons.table_chart_rounded, size: 16),
                label: const Text('Register'),
                style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (_selectedRunId == null)
          _empty('Select a payroll run to view its payslips.')
        else if (_payslips.isEmpty)
          _empty('No payslips stored for this run.')
        else
          ..._payslips.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () => _openPayslip(p),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p['staff_name'].toString(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                                '${p['job_title']} • ${p['branch_name']} • ${p['staff_no']}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              'KES ${_compact.format((p['net_pay'] as num?)?.toDouble() ?? 0.0)}',
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          Text(
                              'Gross ${_compact.format((p['gross_pay'] as num?)?.toDouble() ?? 0.0)}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 9)),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white24, size: 18),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  void _openPayslip(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132043),
        title: Row(children: [
          const Icon(Icons.receipt_long_rounded,
              color: Colors.purpleAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(p['staff_name'].toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _slipRow('Basic + Allowances', (p['gross_pay'] as num?)?.toDouble() ?? 0.0,
                Colors.white),
            _slipRow('Overtime', (p['overtime_pay'] as num?)?.toDouble() ?? 0.0,
                Colors.white70),
            const Divider(color: Colors.white12),
            _slipRow('NSSF (employee)', (p['nssf_employee'] as num?)?.toDouble() ?? 0.0,
                Colors.redAccent),
            _slipRow('SHIF / SHA', (p['shif'] as num?)?.toDouble() ?? 0.0,
                Colors.redAccent),
            _slipRow('Affordable Housing Levy',
                (p['ahl_employee'] as num?)?.toDouble() ?? 0.0, Colors.redAccent),
            _slipRow('Pension', (p['pension'] as num?)?.toDouble() ?? 0.0,
                Colors.redAccent),
            _slipRow('Taxable income', (p['taxable_income'] as num?)?.toDouble() ?? 0.0,
                Colors.white54),
            _slipRow('PAYE before relief',
                (p['paye_before_relief'] as num?)?.toDouble() ?? 0.0, Colors.white54),
            _slipRow('Personal relief',
                -((p['personal_relief'] as num?)?.toDouble() ?? 0.0), Colors.tealAccent),
            _slipRow('PAYE', (p['paye'] as num?)?.toDouble() ?? 0.0, Colors.redAccent),
            const Divider(color: Colors.white12),
            _slipRow('NET PAY', (p['net_pay'] as num?)?.toDouble() ?? 0.0,
                Colors.greenAccent,
                bold: true),
            const SizedBox(height: 10),
            Text(
              'Employer cost to company: KES ${_money.format((p['employer_cost'] as num?)?.toDouble() ?? 0.0)} '
              '(gross + NSSF ${_money.format((p['nssf_employer'] as num?)?.toDouble() ?? 0.0)} '
              '+ AHL ${_money.format((p['ahl_employer'] as num?)?.toDouble() ?? 0.0)} + NITA + WIBA)',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _slipRow(String label, double value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal),
                overflow: TextOverflow.ellipsis),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_money.format(value),
                style: TextStyle(
                    color: color,
                    fontSize: bold ? 14 : 12,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STATUTORY & KRA
  // ==========================================================================
  Widget _buildStatutory(bool isDesktop) {
    final run = _runs.firstWhere((r) => r['id'].toString() == _selectedRunId,
        orElse: () => _runs.isNotEmpty ? _runs.first : {});
    double n(String k) => (run[k] as num?)?.toDouble() ?? 0.0;

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        _panel(
          title: 'Statutory Parameters (editable)',
          icon: Icons.tune_rounded,
          accent: Colors.amberAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These are statutory rates, not data. Confirm them against the current '
                'KRA / NSSF / SHA gazette before approving a live payroll.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _paramChip('Personal relief', _params.personalReliefMonthly,
                      (v) => _params = _params.copyWith(personalReliefMonthly: v)),
                  _paramChip('NSSF rate %', _params.nssfRate * 100,
                      (v) => _params = _params.copyWith(nssfRate: v / 100)),
                  _paramChip('NSSF Tier I limit', _params.nssfTier1Limit,
                      (v) => _params = _params.copyWith(nssfTier1Limit: v)),
                  _paramChip('NSSF Tier II upper', _params.nssfTier2Upper,
                      (v) => _params = _params.copyWith(nssfTier2Upper: v)),
                  _paramChip('SHIF rate %', _params.shifRate * 100,
                      (v) => _params = _params.copyWith(shifRate: v / 100)),
                  _paramChip('SHIF minimum', _params.shifMinimum,
                      (v) => _params = _params.copyWith(shifMinimum: v)),
                  _paramChip('Housing levy %', _params.ahlRate * 100,
                      (v) => _params = _params.copyWith(ahlRate: v / 100)),
                  _paramChip('Pension cap', _params.pensionMonthlyCap,
                      (v) => _params = _params.copyWith(pensionMonthlyCap: v)),
                  _paramChip('NITA (employer)', _params.employerNita,
                      (v) => _params = _params.copyWith(employerNita: v)),
                  _paramChip('WIBA %', _params.employerWibaRate * 100,
                      (v) => _params = _params.copyWith(employerWibaRate: v / 100)),
                  _paramChip('Overtime ×', _params.overtimeMultiplier,
                      (v) => _params = _params.copyWith(overtimeMultiplier: v)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (run.isEmpty)
          _empty('Run and save a payroll to generate statutory returns.')
        else ...[
          _panel(
            title: 'Statutory Summary — ${run['period_label']}',
            icon: Icons.account_balance_rounded,
            accent: Colors.purpleAccent,
            child: Column(children: [
              _totalRow('PAYE to KRA (due 9th)', n('paye_total'), Colors.redAccent),
              const SizedBox(height: 8),
              _totalRow(
                  'NSSF total (EE ${_compact.format(n('nssf_employee_total'))} '
                  '+ ER ${_compact.format(n('nssf_employer_total'))})',
                  n('nssf_employee_total') + n('nssf_employer_total'),
                  Colors.cyanAccent),
              const SizedBox(height: 8),
              _totalRow('SHIF / SHA (due 9th)', n('shif_total'), Colors.blueAccent),
              const SizedBox(height: 8),
              _totalRow(
                  'Affordable Housing Levy (EE ${_compact.format(n('ahl_employee_total'))} '
                  '+ ER ${_compact.format(n('ahl_employer_total'))})',
                  n('ahl_employee_total') + n('ahl_employer_total'),
                  Colors.orangeAccent),
              const Divider(color: Colors.white12, height: 20),
              _totalRow('Net pay to employees (due last working day)',
                  n('net_total'), Colors.greenAccent),
              const SizedBox(height: 8),
              _totalRow('Total cost to employer', n('employer_cost_total'),
                  Colors.amberAccent),
            ]),
          ),
          const SizedBox(height: 14),
          _panel(
            title: 'Remittance Files',
            icon: Icons.file_download_rounded,
            accent: Colors.tealAccent,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _payslips.isEmpty
                      ? null
                      : () => _showCsv('KRA PAYE Schedule',
                          _pay.statutoryRemittanceCsv(_payslips, 'PAYE')),
                  icon: const Icon(Icons.receipt_rounded, size: 16),
                  label: const Text('KRA PAYE Schedule'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent)),
                ),
                OutlinedButton.icon(
                  onPressed: _payslips.isEmpty
                      ? null
                      : () => _showCsv('NSSF Return',
                          _pay.statutoryRemittanceCsv(_payslips, 'NSSF')),
                  icon: const Icon(Icons.shield_rounded, size: 16),
                  label: const Text('NSSF Return'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                      side: const BorderSide(color: Colors.cyanAccent)),
                ),
                OutlinedButton.icon(
                  onPressed: _payslips.isEmpty
                      ? null
                      : () => _showCsv('SHA / SHIF Return',
                          _pay.statutoryRemittanceCsv(_payslips, 'SHIF')),
                  icon: const Icon(Icons.health_and_safety_rounded, size: 16),
                  label: const Text('SHA / SHIF Return'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent)),
                ),
                OutlinedButton.icon(
                  onPressed: _payslips.isEmpty
                      ? null
                      : () => _showCsv('Housing Levy Return',
                          _pay.statutoryRemittanceCsv(_payslips, 'AHL')),
                  icon: const Icon(Icons.home_work_rounded, size: 16),
                  label: const Text('Housing Levy Return'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent)),
                ),
                OutlinedButton.icon(
                  onPressed: _staff.isEmpty
                      ? null
                      : () {
                          final activeStaff = _staff.firstWhere(
                            (s) => (s['status'] ?? 'Active') == 'Active',
                            orElse: () => _staff.first,
                          );
                          final p9Csv = _pay.exportP9Card(
                            staff: activeStaff,
                            payslipsForYear: _payslips,
                            year: _year,
                          );
                          _showCsv('KRA P9A Tax Deduction Card (${activeStaff['first_name']} ${activeStaff['last_name']})', p9Csv);
                        },
                  icon: const Icon(Icons.credit_card_rounded, size: 16),
                  label: const Text('KRA P9 Tax Card (CSV)'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purpleAccent,
                      side: const BorderSide(color: Colors.purpleAccent)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _panel(
          title: 'Compliance Calendar',
          icon: Icons.event_rounded,
          accent: Colors.cyanAccent,
          child: Column(children: [
            _calRow('9th', 'PAYE, NSSF, SHIF and Housing Levy remittances'),
            _calRow('20th', 'KRA VAT return (output less input)'),
            _calRow('30 June', 'KRA P9 issued to every employee'),
            _calRow('30 June', 'Annual P10 employer return'),
            _calRow('Year end', 'Close current-year earnings to retained earnings'),
          ]),
        ),
      ],
    );
  }

  Widget _calRow(String date, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(date,
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 10),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _paramChip(String label, double value, ValueChanged<double> onChanged) {
    final ctrl = TextEditingController(text: value.toStringAsFixed(2));
    return SizedBox(
      width: 150,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
          isDense: true,
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.amberAccent)),
        ),
        onSubmitted: (v) {
          final d = double.tryParse(v);
          if (d != null) {
            setState(() => onChanged(d));
          }
        },
      ),
    );
  }

  // ==========================================================================
  // Shared widgets
  // ==========================================================================
  Widget _kpi(String label, String value, IconData icon, Color color,
      {String? subtitle}) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0;
      return Container(
        width: w > 420 ? (w - 36) / 4 : (w > 260 ? (w - 12) / 2 : w),
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      );
    });
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
    Color accent = Colors.purpleAccent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, color: accent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('KES ${_money.format(value)}',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 9),
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _empty(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: Colors.white24, size: 38),
          const SizedBox(height: 10),
          Text(msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _f(TextEditingController c, String label, {bool num = false}) {
    return TextField(
      controller: c,
      keyboardType: num ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        isDense: true,
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.purpleAccent)),
      ),
    );
  }

  void _showCsv(String title, String csv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132043),
        title: Row(children: [
          const Icon(Icons.description_rounded, color: Colors.tealAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              csv.isEmpty ? '(nothing to export)' : csv,
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied to clipboard',
                    style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.teal,
                behavior: SnackBarBehavior.floating,
              ));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }
}
