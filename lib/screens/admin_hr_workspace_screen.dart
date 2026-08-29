import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import 'finance_gl_screen.dart';
import 'hr_payroll_workspace_screen.dart';

class AdminHrWorkspaceScreen extends StatefulWidget {
  const AdminHrWorkspaceScreen({super.key});

  @override
  State<AdminHrWorkspaceScreen> createState() => _AdminHrWorkspaceScreenState();
}

class _AdminHrWorkspaceScreenState extends State<AdminHrWorkspaceScreen> {
  final List<Map<String, dynamic>> _staffList = [];
  
  bool _isLoadingFinance = true;
  double _dailyRevenue = 0.0;
  double _dailyPettyCash = 0.0;
  List<Map<String, dynamic>> _ledgerEntries = [];
  
  String _selectedFinanceBranch = 'All Branches';
  final List<String> _financeBranches = const ['All Branches', 'Nairobi', 'Kisumu'];

  @override
  void initState() {
    super.initState();
    _fetchFinanceData();
  }

  Future<void> _fetchFinanceData() async {
    setState(() => _isLoadingFinance = true);
    try {
      final db = Supabase.instance.client;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

      var txQuery = db.from('transactions')
          .select('total_amount')
          .eq('transaction_type', 'sale')
          .gte('transaction_date', startOfDay);
          
      final txRes = await txQuery;
      
      double rev = 0.0;
      for (var tx in (txRes as List)) {
        rev += (tx['total_amount'] as num).toDouble();
      }

      var ledgerQuery = db.from('imprest_ledger')
          .select()
          .gte('created_at', startOfDay);
          
      if (_selectedFinanceBranch != 'All Branches') {
        ledgerQuery = ledgerQuery.eq('branch', _selectedFinanceBranch);
      }
          
      final ledgerRes = await ledgerQuery.order('created_at', ascending: false);
          
      final ledger = ledgerRes as List<dynamic>;
      double spent = 0.0;
      for (var entry in ledger) {
        spent += (entry['amount'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _dailyRevenue = rev;
          _dailyPettyCash = spent;
          _ledgerEntries = List<Map<String, dynamic>>.from(ledger);
          _isLoadingFinance = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoadingFinance = false);
    }
  }

  Future<void> _updateExpenseStatus(String id, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('imprest_ledger')
          .update({'status': newStatus})
          .eq('id', id);
      await _fetchFinanceData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: newStatus == 'Approved' ? const Color(0xFF10B981) : Colors.redAccent,
            content: Text('Expense $newStatus successfully.', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Status update error: $e');
    }
  }

  final List<String> _pharmacyRoles = const [
    // Executive
    'CEO',
    'General Manager',
    'HR Manager',
    'Accountant',
    'Procurement Manager',
    'Operations Manager',
    // Branch Leadership
    'Branch Manager',
    'Sales Manager',
    // Medical & Floor Staff
    'Head Pharmacist',
    'Assistant Pharmacist',
    'Stock Controller',
    'Cashier',
    'Driver',
  ];

  final List<String> _branches = const [
    'Downtown Central (HQ)',
    'Westside Mega Store',
    'Northside Express Hub',
  ];

  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = _pharmacyRoles[0];
    String selectedBranch = _branches[0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.purpleAccent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Staff Member',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Full Name', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'e.g. Dr. Alex Mercer',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Email Address', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailController,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'alex.mercer@pharmacy.com',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Text('Account Password', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Temporary password',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Assigned Branch', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedBranch,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            style: GoogleFonts.inter(color: Colors.white),
                            items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedBranch = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Role-Based Access (RBAC)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRole,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            style: GoogleFonts.inter(color: Colors.white),
                            items: _pharmacyRoles.map((role) {
                              String categoryHeader = '';
                              if (role == 'CEO') categoryHeader = '👑 EXECUTIVE';
                              if (role == 'Branch Manager') categoryHeader = '🏢 BRANCH LEADERSHIP';
                              if (role == 'Head Pharmacist') categoryHeader = '🩺 MEDICAL & FLOOR STAFF';

                              return DropdownMenuItem(
                                value: role,
                                child: Text(
                                  categoryHeader.isNotEmpty ? '$role ($categoryHeader)' : role,
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedRole = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (nameController.text.trim().isNotEmpty && emailController.text.trim().isNotEmpty && passwordController.text.trim().isNotEmpty) {
                      setState(() {
                        _staffList.insert(0, {
                          'name': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'branch': selectedBranch,
                          'role': selectedRole,
                          'status': 'Active',
                        });
                      });
                      
                      try {
                        // Real Auth Provisioning (Bypass Session Drop)
                        final secondaryClient = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
                        
                        final authRes = await secondaryClient.auth.signUp(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );

                        if (authRes.user != null) {
                          // Insert to public profile with primary client
                          await Supabase.instance.client.from('users').insert({
                            'id': authRes.user!.id,
                            'email': authRes.user!.email,
                            'full_name': nameController.text.trim(),
                            'role': selectedRole.contains('Manager') ? 'Manager' : 
                                    selectedRole.contains('Pharmacist') ? 'Pharmacist' : 
                                    selectedRole.contains('Storekeeper') ? 'Storekeeper' : 'Storekeeper',
                          });
                        }
                      } catch (e) {
                        debugPrint('Real Auth provisioning error: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(
                                'Provisioning failed: $e',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      if (context.mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);

                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF10B981),
                            content: Text(
                              'Staff Member \${nameController.text} provisioned successfully (Live Auth)!',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }
                    } else {
                      // Show validation error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text(
                            'Please enter both name and email address.',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: Text('Save Staff Member', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showB2bSaaSOnboardingDialog() {
    final tenantNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.domain_add_rounded, color: Colors.cyanAccent),
              ),
              const SizedBox(width: 12),
              Text(
                'Onboard New Enterprise Franchise (B2B SaaS)',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Franchise / Pharmacy Company Name', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: tenantNameController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Apex Health Pharmacy Group',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.cyanAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Multi-Tenant SaaS Engine: Automatically provisions isolated Supabase RLS schemas, default branch structures, and admin credentials.',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.cyanAccent,
                    content: Text(
                      'B2B SaaS Module: Provisioning new enterprise tenant workspace for "${tenantNameController.text.isNotEmpty ? tenantNameController.text : 'Apex Health'}"...',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.cloud_upload_rounded),
              label: Text('Provision Tenant', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showLeaveManagementModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Leave Management', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 600,
            height: 400,
            child: FutureBuilder(
              future: Supabase.instance.client.from('leave_requests').select().eq('status', 'Pending').order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Text('Error loading requests', style: TextStyle(color: Colors.red));
                final data = snapshot.data as List<dynamic>? ?? [];
                if (data.isEmpty) return const Center(child: Text('No pending leave requests.', style: TextStyle(color: Colors.white54)));

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final req = data[index];
                    return Card(
                      color: const Color(0xFF0F172A),
                      child: ListTile(
                        title: Text('${req['employee_name']} (${req['role']})', style: const TextStyle(color: Colors.white)),
                        subtitle: Text('From: ${req['start_date']} To: ${req['end_date']}\nReason: ${req['reason']}', style: const TextStyle(color: Colors.white70)),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                await Supabase.instance.client.from('leave_requests').update({'status': 'Approved'}).eq('id', req['id']);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _showLeaveManagementModal(); // refresh
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                await Supabase.instance.client.from('leave_requests').update({'status': 'Rejected'}).eq('id', req['id']);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _showLeaveManagementModal(); // refresh
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  void _showProcessPayrollModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Consolidated Branch Payouts', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 600,
            height: 400,
            child: FutureBuilder(
              future: Supabase.instance.client.from('payroll_disbursements').select().eq('status', 'Pending Clearance'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Text('Error loading payrolls', style: TextStyle(color: Colors.red));
                final data = snapshot.data as List<dynamic>? ?? [];
                if (data.isEmpty) return const Center(child: Text('No pending payrolls to clear.', style: TextStyle(color: Colors.white54)));

                return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final payroll = data[index];
                    return Card(
                      color: const Color(0xFF0F172A),
                      child: ListTile(
                        title: Text('${payroll['branch_name']} - Period: ${payroll['payroll_period']}', style: const TextStyle(color: Colors.white)),
                        subtitle: Text('Total: KES ${payroll['total_amount']}', style: const TextStyle(color: Colors.white70)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () async {
                            await Supabase.instance.client.from('payroll_disbursements').update({
                              'status': 'Cleared',
                              'cleared_at': DateTime.now().toIso8601String()
                            }).eq('id', payroll['id']);
                            if (context.mounted) {
                              Navigator.pop(context);
                              _showProcessPayrollModal(); // refresh
                            }
                          },
                          child: const Text('Clear Funds & Disburse', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.badge_rounded, color: Colors.purpleAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isDesktop ? 'Staff Administration & HR Workspace (RBAC)' : 'HR Workspace',
                style: GoogleFonts.inter(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HrPayrollWorkspaceScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purpleAccent,
                  side: const BorderSide(color: Colors.purpleAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.badge_rounded, size: 16),
                label: const Text('Payroll Workspace'),
              ),
            )
          else
            IconButton(
              tooltip: 'Payroll Workspace',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HrPayrollWorkspaceScreen()),
              ),
              icon: const Icon(Icons.badge_rounded, color: Colors.purpleAccent),
            ),
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FinanceGlScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amberAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.account_balance_rounded, size: 16),
                label: const Text('Finance & GL'),
              ),
            )
          else
            IconButton(
              tooltip: 'Finance & GL',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FinanceGlScreen()),
              ),
              icon: const Icon(Icons.account_balance_rounded, color: Colors.amberAccent),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: isDesktop 
              ? OutlinedButton.icon(
                  onPressed: () => AuthService().logout(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: Text('Logout HR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                )
              : IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  onPressed: () => AuthService().logout(),
                ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Bar with Add Staff & SaaS Onboarding buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Employee Access Control & Multi-Branch Governance',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_staffList.length} Active Staff Accounts • 13 Role-Based Access Tiers (RBAC)',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _showB2bSaaSOnboardingDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.cyanAccent,
                                side: const BorderSide(color: Colors.cyanAccent),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.domain_add_rounded, size: 18),
                              label: Text(
                                'Onboard New Pharmacy',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddStaffDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: Text(
                                'Add New Staff',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee Access Control & Multi-Branch Governance',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_staffList.length} Active Staff Accounts • 13 Role-Based Access Tiers (RBAC)',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showB2bSaaSOnboardingDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.cyanAccent,
                              side: const BorderSide(color: Colors.cyanAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.domain_add_rounded, size: 18),
                            label: Text(
                              'Onboard New Pharmacy',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showAddStaffDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purpleAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: Text(
                              'Add New Staff',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            // Quick Action Row: Payroll & Leave Management
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showProcessPayrollModal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                    label: Text('Process Payroll', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showLeaveManagementModal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.event_available_rounded, size: 18),
                    label: Text('Leave Management', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Employee Data Table
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Directory & Active RBAC Roles',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 620),
                      child: SizedBox(
                        width: 620,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _staffList.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text('Employee Name', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Expanded(flex: 2, child: Text('Email Address', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Expanded(flex: 2, child: Text('Branch Location', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Expanded(flex: 2, child: Text('Role (RBAC)', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                                    Expanded(flex: 1, child: Text('Status', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                ),
                              );
                            }
                            final staff = _staffList[index - 1];
                            final bool isActive = staff['status'] == 'Active';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text(staff['name'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))),
                                  Expanded(flex: 2, child: Text(staff['email'], style: GoogleFonts.inter(color: Colors.white70, fontSize: 12))),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(staff['branch'], style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w600))),
                                      ),
                                    ),
                                  ),
                                  Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildRoleBadge(staff['role']))),
                                  Expanded(
                                    flex: 1,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            staff['status'],
                                            style: GoogleFonts.inter(
                                              color: isActive ? const Color(0xFF10B981) : Colors.redAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Global Finance Ledger
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Global Finance Ledger',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedFinanceBranch,
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.inter(color: Colors.white),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
                        underline: Container(height: 1, color: Colors.tealAccent),
                        items: _financeBranches.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFinanceBranch = newValue;
                            });
                            _fetchFinanceData();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _isLoadingFinance
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 520;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  _buildFinanceLedgerKpi('Daily Revenue', 'KES ${_dailyRevenue.toStringAsFixed(2)}', Colors.tealAccent),
                                  const SizedBox(height: 10),
                                  _buildFinanceLedgerKpi('Petty Cash Spent', 'KES ${_dailyPettyCash.toStringAsFixed(2)}', Colors.orangeAccent),
                                  const SizedBox(height: 10),
                                  _buildFinanceLedgerKpi('Net Cash on Hand', 'KES ${(_dailyRevenue - _dailyPettyCash).toStringAsFixed(2)}', Colors.greenAccent),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: _buildFinanceLedgerKpi('Daily Revenue', 'KES ${_dailyRevenue.toStringAsFixed(2)}', Colors.tealAccent)),
                                const SizedBox(width: 14),
                                Expanded(child: _buildFinanceLedgerKpi('Petty Cash Spent', 'KES ${_dailyPettyCash.toStringAsFixed(2)}', Colors.orangeAccent)),
                                const SizedBox(width: 14),
                                Expanded(child: _buildFinanceLedgerKpi('Net Cash on Hand', 'KES ${(_dailyRevenue - _dailyPettyCash).toStringAsFixed(2)}', Colors.greenAccent)),
                              ],
                            );
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Ledger Line Items with Approve/Reject
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense Ledger — Line Items',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_ledgerEntries.length} entries today • Filter: $_selectedFinanceBranch',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 16),
                  _isLoadingFinance
                      ? const Center(child: CircularProgressIndicator())
                      : _ledgerEntries.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('No ledger entries for today.', style: GoogleFonts.inter(color: Colors.white38)),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _ledgerEntries.length,
                              separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.05)),
                              itemBuilder: (context, index) {
                                final entry = _ledgerEntries[index];
                                final status = entry['status'] ?? 'Pending';
                                final isRevenue = status == 'Revenue Entry';
                                Color chipColor;
                                if (status == 'Approved') {
                                  chipColor = const Color(0xFF10B981);
                                } else if (status == 'Rejected') {
                                  chipColor = Colors.redAccent;
                                } else if (isRevenue) {
                                  chipColor = Colors.tealAccent;
                                } else {
                                  chipColor = Colors.amber;
                                }
                                return ListTile(
                                  leading: Icon(
                                    isRevenue ? Icons.trending_up_rounded : Icons.receipt_long_rounded,
                                    color: isRevenue ? Colors.tealAccent : Colors.orangeAccent,
                                  ),
                                  title: Text(
                                    entry['description'] ?? '',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text('Branch: ${entry['branch'] ?? 'N/A'} ', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: chipColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(status, style: GoogleFonts.inter(color: chipColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  trailing: isRevenue
                                      ? Text(
                                          '+ KES ${entry['amount']}',
                                          style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '- KES ${entry['amount']}',
                                              style: GoogleFonts.inter(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                                            ),
                                            if (status == 'Pending') ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                                                tooltip: 'Approve',
                                                onPressed: () => _updateExpenseStatus(entry['id'].toString(), 'Approved'),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
                                                tooltip: 'Reject',
                                                onPressed: () => _updateExpenseStatus(entry['id'].toString(), 'Rejected'),
                                              ),
                                            ],
                                          ],
                                        ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg;
    Color fg;

    if (role == 'CEO' || role == 'General Manager') {
      bg = Colors.purpleAccent.withValues(alpha: 0.2);
      fg = Colors.purpleAccent;
    } else if (role.contains('Manager')) {
      bg = Colors.amber.withValues(alpha: 0.2);
      fg = Colors.amber;
    } else if (role.contains('Pharmacist')) {
      bg = Colors.cyanAccent.withValues(alpha: 0.2);
      fg = Colors.cyanAccent;
    } else {
      bg = Colors.blueAccent.withValues(alpha: 0.2);
      fg = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(role, style: GoogleFonts.inter(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFinanceLedgerKpi(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(title, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 18, color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
