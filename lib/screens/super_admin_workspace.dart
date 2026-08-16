import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class SuperAdminWorkspaceScreen extends StatefulWidget {
  const SuperAdminWorkspaceScreen({super.key});

  @override
  State<SuperAdminWorkspaceScreen> createState() => _SuperAdminWorkspaceScreenState();
}

class _SuperAdminWorkspaceScreenState extends State<SuperAdminWorkspaceScreen> {
  final List<Map<String, dynamic>> _tenants = [
    {
      'id': 'TNT-901',
      'name': 'Nairobi Mega-Wholesale',
      'tier': 'Enterprise SaaS (Unlimited)',
      'branches': 14,
      'mrr': '\$12,500/mo',
      'status': 'Active',
    },
  ];

  void _showProvisionTenantDialog() {
    final tenantNameController = TextEditingController();
    final adminEmailController = TextEditingController();
    String selectedTier = 'Enterprise SaaS (Standard)';

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
                      color: Colors.amberAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.domain_add_rounded, color: Colors.amberAccent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Provision New Enterprise Tenant Workspace',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enterprise Organization Name', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: tenantNameController,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'e.g. Mount Kenya Global Pharmaceuticals',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Initial CEO Admin Email', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: adminEmailController,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'ceo@mountkenyapharma.com',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Subscription Plan & Licensing Tier', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTier,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            style: GoogleFonts.inter(color: Colors.white),
                            items: const [
                              DropdownMenuItem(value: 'Enterprise SaaS (Unlimited)', child: Text('Enterprise SaaS (Unlimited - \$15,000/mo)')),
                              DropdownMenuItem(value: 'Enterprise SaaS (Standard)', child: Text('Enterprise SaaS (Standard - \$7,500/mo)')),
                              DropdownMenuItem(value: 'Enterprise SaaS (Custom)', child: Text('Enterprise SaaS (Custom Multi-Branch)')),
                              DropdownMenuItem(value: 'Growth Plan', child: Text('Growth Plan (\$3,500/mo)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedTier = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded, color: Colors.amberAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Platform Engine: Automatically generates isolated PostgreSQL RLS schema, dedicated Supabase tenant ID, and CEO credentials.',
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
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
                    if (tenantNameController.text.isNotEmpty) {
                      setState(() {
                        _tenants.insert(0, {
                          'id': 'TNT-${906 + _tenants.length}',
                          'name': tenantNameController.text,
                          'tier': selectedTier,
                          'branches': 1,
                          'mrr': '\$7,500/mo',
                          'status': 'Active',
                        });
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF10B981),
                          content: Text(
                            'Provisioned Tenant Workspace for "${tenantNameController.text}" with isolated RLS Schema!',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text('Provision Tenant Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTenantDialog(Map<String, dynamic> tenant, int index) {
    final mrrController = TextEditingController(text: tenant['mrr']);
    String selectedTier = tenant['tier'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Edit ${tenant['name']}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subscription Tier', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTier,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.inter(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'Enterprise SaaS (Unlimited)', child: Text('Enterprise SaaS (Unlimited)')),
                          DropdownMenuItem(value: 'Enterprise SaaS (Standard)', child: Text('Enterprise SaaS (Standard)')),
                          DropdownMenuItem(value: 'Enterprise SaaS (Custom)', child: Text('Enterprise SaaS (Custom Multi-Branch)')),
                          DropdownMenuItem(value: 'Growth Plan', child: Text('Growth Plan')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedTier = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Monthly MRR (Price)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: mrrController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _tenants[index]['tier'] = selectedTier;
                      _tenants[index]['mrr'] = mrrController.text;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: Text('Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> tenant, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text('Delete Tenant?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to permanently delete ${tenant['name']}? This action cannot be undone.', style: GoogleFonts.inter(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _tenants.removeAt(index);
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: Text('Delete Account', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
                gradient: const LinearGradient(colors: [Colors.amberAccent, Colors.orangeAccent]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDesktop ? 'Super Admin Platform Governance' : 'Super Admin',
                    style: GoogleFonts.inter(fontSize: isDesktop ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isDesktop ? 'B2B SaaS Multi-Tenant Platform Owner Dashboard' : 'Platform Owner',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: isDesktop
                ? OutlinedButton.icon(
                    onPressed: () {
                      AuthService().logout();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: Text('Logout Platform Control', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                : IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    onPressed: () => AuthService().logout(),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Overview Bar & Action Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
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
                                'Active B2B SaaS Enterprise Tenants',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_tenants.length} Managed Wholesale Networks • Total Platform MRR: \$48,800/mo',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _showProvisionTenantDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.domain_add_rounded, size: 20),
                          label: Text(
                            'Provision New Enterprise Tenant',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active B2B SaaS Enterprise Tenants',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_tenants.length} Managed Wholesale Networks • Total Platform MRR: \$48,800/mo',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showProvisionTenantDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.domain_add_rounded, size: 20),
                            label: Text(
                              'Provision New Tenant',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // Enterprise Tenants Table
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multi-Tenant Tenant Provisioning Registry',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text('Tenant ID', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Enterprise Company', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Subscription Tier', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Active Branches', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Monthly MRR', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Provision Status', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold))),
                      ],
                      rows: _tenants.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final Map<String, dynamic> t = entry.value;
                        final bool isPending = t['status'] == 'Pending Setup';

                        return DataRow(
                          cells: [
                            DataCell(Text(t['id'], style: GoogleFonts.inter(color: Colors.amberAccent, fontWeight: FontWeight.bold))),
                            DataCell(Text(t['name'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text(t['tier'], style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                            )),
                            DataCell(Text('${t['branches']} Branches', style: GoogleFonts.inter(color: Colors.white70))),
                            DataCell(Text(t['mrr'], style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPending ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                t['status'],
                                style: GoogleFonts.inter(
                                  color: isPending ? Colors.amber : const Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 20),
                                  onPressed: () => _showEditTenantDialog(t, index),
                                  tooltip: 'Edit Price & Tier',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () => _showDeleteConfirmation(t, index),
                                  tooltip: 'Delete Account',
                                ),
                              ],
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
}
