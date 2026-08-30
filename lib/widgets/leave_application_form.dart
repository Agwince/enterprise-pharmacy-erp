import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/hr_leave_service.dart';

class LeaveApplicationForm extends StatefulWidget {
  final VoidCallback? onSubmitted;
  const LeaveApplicationForm({super.key, this.onSubmitted});

  @override
  State<LeaveApplicationForm> createState() => _LeaveApplicationFormState();
}

class _LeaveApplicationFormState extends State<LeaveApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final HrLeaveService _leaveService = HrLeaveService();

  List<Map<String, dynamic>> _staffList = [];
  String? _selectedStaffId;
  String _selectedLeaveType = 'Annual';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _isLoadingStaff = true;
  bool _isSubmitting = false;
  LeaveBalanceData? _currentBalance;

  final List<String> _leaveTypes = [
    'Annual',
    'Sick',
    'Maternity',
    'Paternity',
    'Compassionate',
    'Unpaid',
  ];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final res = await Supabase.instance.client.from('staff').select().order('first_name');
      final list = List<Map<String, dynamic>>.from(res as List);
      if (mounted) {
        setState(() {
          _staffList = list;
          if (_staffList.isNotEmpty) {
            _selectedStaffId = _staffList.first['id'].toString();
            _loadBalance(_selectedStaffId!);
          }
          _isLoadingStaff = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

  Future<void> _loadBalance(String staffId) async {
    final bal = await _leaveService.fetchStaffLeaveBalance(staffId);
    if (mounted) {
      setState(() => _currentBalance = bal);
    }
  }

  int _calculateDays() {
    if (_startDate == null || _endDate == null) return 1;
    final diff = _endDate!.difference(_startDate!).inDays + 1;
    return diff > 0 ? diff : 1;
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitLeave() async {
    if (!_formKey.currentState!.validate() || _selectedStaffId == null || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select start/end dates.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final staff = _staffList.firstWhere((s) => s['id'].toString() == _selectedStaffId);
      final days = _calculateDays();

      await _leaveService.applyLeave(
        staffId: staff['id'].toString(),
        staffName: '${staff['first_name']} ${staff['last_name']}',
        staffNo: staff['staff_no']?.toString(),
        department: staff['department']?.toString() ?? 'Pharmacy Operations',
        leaveType: _selectedLeaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        totalDays: days,
        reason: _reasonController.text.trim().isEmpty ? 'Personal leave' : _reasonController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Leave application for ${staff['first_name']} submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSubmitted?.call();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _calculateDays();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: _isLoadingStaff
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Apply for Staff Leave', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Staff Selector
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF0F172A),
                    initialValue: _selectedStaffId,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Select Employee',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: _staffList.map((s) {
                      return DropdownMenuItem<String>(
                        value: s['id'].toString(),
                        child: Text('${s['first_name']} ${s['last_name']} (${s['staff_no'] ?? 'STAFF'})'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedStaffId = v);
                        _loadBalance(v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Leave Balances Live Card
                  if (_currentBalance != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Annual Remaining', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              Text('${_currentBalance!.annualRemaining} / 21 days', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Sick Remaining', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              Text('${_currentBalance!.sickRemaining} / 30 days', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Unpaid Used (Deducted)', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              Text('${_currentBalance!.unpaidUsed} days', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Leave Type Selector
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF0F172A),
                    initialValue: _selectedLeaveType,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Leave Type',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: _leaveTypes.map((t) {
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Text(t == 'Unpaid' ? 'Unpaid Leave (Feeds Payroll Deduction)' : '$t Leave'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedLeaveType = v ?? _selectedLeaveType),
                  ),
                  const SizedBox(height: 12),

                  // Date range picker
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _selectDate(context, true),
                          icon: const Icon(Icons.calendar_today, size: 16, color: Colors.tealAccent),
                          label: Text(_startDate == null ? 'Start Date' : DateFormat('yyyy-MM-dd').format(_startDate!), style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => _selectDate(context, false),
                          icon: const Icon(Icons.calendar_today, size: 16, color: Colors.tealAccent),
                          label: Text(_endDate == null ? 'End Date' : DateFormat('yyyy-MM-dd').format(_endDate!), style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  if (_startDate != null && _endDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Duration: $days working day(s)', style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 12),

                  // Reason
                  TextFormField(
                    controller: _reasonController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Reason for Leave / Handover Notes',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submitLeave,
                      icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.send, size: 18),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Application', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
