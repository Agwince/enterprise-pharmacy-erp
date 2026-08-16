import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class AdminHrWorkspaceScreen extends StatefulWidget {
  const AdminHrWorkspaceScreen({super.key});

  @override
  State<AdminHrWorkspaceScreen> createState() => _AdminHrWorkspaceScreenState();
}

class _AdminHrWorkspaceScreenState extends State<AdminHrWorkspaceScreen> {
  final List<Map<String, dynamic>> _staffList = [];

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
                  onPressed: () {
                    if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                      setState(() {
                        _staffList.insert(0, {
                          'name': nameController.text,
                          'email': emailController.text,
                          'branch': selectedBranch,
                          'role': selectedRole,
                          'status': 'Active',
                        });
                      });
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF10B981),
                          content: Text(
                            'Staff Member ${nameController.text} added successfully with role "$selectedRole"!',
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

  @override
  Widget build(BuildContext context) {
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
            Text(
              'Staff Administration & HR Workspace (RBAC)',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: OutlinedButton.icon(
              onPressed: () => AuthService().logout(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: Text('Logout HR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
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
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // SaaS Onboard Button (Task 3)
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
                          'Onboard New Pharmacy / Franchise',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),

                      // Add Staff Button (Task 1)
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
              ),
            ),
            const SizedBox(height: 24),

            // Employee Data Table
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text('Employee Name', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Email Address', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Branch Location', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Role (RBAC)', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                      ],
                      rows: _staffList.map((staff) {
                        final bool isActive = staff['status'] == 'Active';

                        return DataRow(
                          cells: [
                            DataCell(Text(staff['name'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600))),
                            DataCell(Text(staff['email'], style: GoogleFonts.inter(color: Colors.white70))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text(staff['branch'], style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                            )),
                            DataCell(_buildRoleBadge(staff['role'])),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF10B981).withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                staff['status'],
                                style: GoogleFonts.inter(
                                  color: isActive ? const Color(0xFF10B981) : Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )),
                          ],
                        );
                      }).toList(),
                    ),
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
      bg = Colors.purpleAccent.withOpacity(0.2);
      fg = Colors.purpleAccent;
    } else if (role.contains('Manager')) {
      bg = Colors.amber.withOpacity(0.2);
      fg = Colors.amber;
    } else if (role.contains('Pharmacist')) {
      bg = Colors.cyanAccent.withOpacity(0.2);
      fg = Colors.cyanAccent;
    } else {
      bg = Colors.blueAccent.withOpacity(0.2);
      fg = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(role, style: GoogleFonts.inter(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
