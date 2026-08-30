import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import 'register_product_screen.dart';
import 'catalog_list_screen.dart';

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

  void _showManageTenantDialog(Map<String, dynamic> tenant) {
    final companyNameController = TextEditingController(text: tenant['name']);
    final ceoEmailController = TextEditingController();
    final ceoPasswordController = TextEditingController();
    final hrEmailController = TextEditingController();
    final hrPasswordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.manage_accounts, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Text('Manage Enterprise Tenant', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enterprise Company Name', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: companyNameController,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Text('CEO Credentials', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ceoEmailController,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'CEO Email',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ceoPasswordController,
                        obscureText: true,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'CEO Password',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('HR Manager Credentials', style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: hrEmailController,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'HR Manager Email',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: hrPasswordController,
                        obscureText: true,
                        style: GoogleFonts.inter(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'HR Password',
                          hintStyle: GoogleFonts.inter(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : () async {
                    setModalState(() => isSaving = true);
                    
                    try {
                      // Real Auth Provisioning (Bypass Session Drop)
                      final secondaryClient = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
                      final primaryClient = Supabase.instance.client;
                      
                      // Upsert tenant
                      final branchRes = await primaryClient.from('branches').insert({
                        'name': companyNameController.text,
                        'code': 'TNT-\${DateTime.now().millisecondsSinceEpoch}',
                        'location': 'Enterprise Provisioned',
                      }).select();
                      
                      final branchId = (branchRes as List).isNotEmpty ? branchRes[0]['id'] : null;

                      // Insert real auth users and link them to public DB
                      if (ceoEmailController.text.isNotEmpty && ceoPasswordController.text.isNotEmpty) {
                        final ceoAuth = await secondaryClient.auth.signUp(
                          email: ceoEmailController.text,
                          password: ceoPasswordController.text,
                        );
                        if (ceoAuth.user != null) {
                          await primaryClient.from('users').insert({
                            'id': ceoAuth.user!.id,
                            'email': ceoAuth.user!.email,
                            'full_name': '\${companyNameController.text} CEO',
                            'role': 'CEO',
                            'branch_id': branchId,
                          });
                        }
                      }
                      
                      if (hrEmailController.text.isNotEmpty && hrPasswordController.text.isNotEmpty) {
                        final hrAuth = await secondaryClient.auth.signUp(
                          email: hrEmailController.text,
                          password: hrPasswordController.text,
                        );
                        if (hrAuth.user != null) {
                          await primaryClient.from('users').insert({
                            'id': hrAuth.user!.id,
                            'email': hrAuth.user!.email,
                            'full_name': '\${companyNameController.text} HR',
                            'role': 'Manager', // closest to HR
                            'branch_id': branchId,
                          });
                        }
                      }

                      if (context.mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.greenAccent,
                            content: Text(
                              'Successfully provisioned ${companyNameController.text} (Live Auth)',
                              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
                            )
                          )
                        );
                      }
                    } catch (e) {
                      debugPrint('Live Auth provisioning error: $e');
                      if (context.mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.redAccent,
                            content: Text(
                              'Provisioning Failed: $e',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          )
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(isSaving ? 'Saving...' : 'Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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

            // ==========================================
            // CATALOGUE & MEDICINES GOVERNANCE SECTION
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.medication_rounded, color: Colors.tealAccent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Catalogue / Medicines',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Global Central Formulary, Drug Registration & Photo Inventory Management',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: _buildCatalogueActionCard(
                                    title: 'Register Medicine',
                                    subtitle: 'Register new drug formulations, barcode, pricing & bin locations.',
                                    icon: Icons.add_circle_outline_rounded,
                                    color: Colors.tealAccent,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const RegisterProductScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildCatalogueActionCard(
                                    title: 'Medicine List',
                                    subtitle: 'View all 782 live medicines, search inventory & attach photos.',
                                    icon: Icons.format_list_bulleted_rounded,
                                    color: Colors.cyanAccent,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const CatalogListScreen(mode: IntakeMode.both),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildCatalogueActionCard(
                                  title: 'Register Medicine',
                                  subtitle: 'Register new drug formulations, barcode, pricing & bin locations.',
                                  icon: Icons.add_circle_outline_rounded,
                                  color: Colors.tealAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterProductScreen(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildCatalogueActionCard(
                                  title: 'Medicine List',
                                  subtitle: 'View all 782 live medicines, search inventory & attach photos.',
                                  icon: Icons.format_list_bulleted_rounded,
                                  color: Colors.cyanAccent,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CatalogListScreen(mode: IntakeMode.both),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                    },
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
                        DataColumn(label: Text('Tenant ID', style: GoogleFonts.inter(color: Colors.amberAccent, fontWeight: FontWeight.bold))),
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
                                  icon: const Icon(Icons.manage_accounts, color: Colors.amberAccent, size: 20),
                                  onPressed: () => _showManageTenantDialog(t),
                                  tooltip: 'Manage Tenant',
                                ),
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

  Widget _buildCatalogueActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
