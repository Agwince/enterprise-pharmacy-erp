import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');
  bool _isLoading = false;

  void _handleStandardLogin() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (response.user != null) {
        final res = await Supabase.instance.client.from('roles').select('role').eq('email', _emailController.text.trim()).maybeSingle();
        if (res != null) {
          String dbRole = res['role'].toString().toUpperCase();
          switch (dbRole) {
            case 'TELESALES':
              AuthService().loginAsTelesales();
              break;
            case 'SECRETARY':
              AuthService().loginAsSecretary();
              break;
            case 'CEO':
              AuthService().loginAsCeo();
              break;
            case 'HR':
              AuthService().loginAsHr();
              break;
            case 'STOREKEEPER':
              AuthService().loginAsStorekeeper();
              break;
            case 'CATALOG_ADMIN':
              AuthService().loginAsCatalogAdmin();
              break;
            case 'BRANCH_MANAGER':
              AuthService().loginAsBranchManager();
              break;
            case 'SUPER_ADMIN':
              AuthService().loginAsSuperAdmin();
              break;
            case 'WAREHOUSE_PICKER':
              AuthService().loginAsWarehousePicker();
              break;
            case 'MARKETER':
              AuthService().loginAsMarketer();
              break;
            default:
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unknown role in database.')));
              break;
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No role assigned to this user.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: GlassContainer(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Branding Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amberAccent, Colors.cyanAccent],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_pharmacy_rounded,
                      color: Colors.black,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Multi-Tenant Enterprise ERP',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Wholesale B2B SaaS • Authentication Gateway',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),

                // Corporate Email Textfield
                Text(
                  'Corporate Email',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                    hintText: 'user@tenantdomain.com',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Password Textfield
                Text(
                  'Password',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54),
                    hintText: '••••••••',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Standard Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleStandardLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Sign In to Enterprise Workspace',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // Prominent Executive One-Click Launcher for CEO
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.tealAccent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.stars_rounded, color: Colors.tealAccent, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'One-Click CEO Executive Demo',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Instant access to Analytics, Fleet Map & Mobile Runner views',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => AuthService().loginAsCeo(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: const Color(0xFF0F172A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: Text(
                            'Launch Executive ERP Experience',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Pitch Demo Quick-Login Header
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'PITCH DEMO QUICK-LOGIN',
                        style: GoogleFonts.inter(
                          color: Colors.amberAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                  ],
                ),
                const SizedBox(height: 16),

                // Button 1: Super Admin (Platform Owner)
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsSuperAdmin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.shield_rounded, size: 18),
                  label: Text(
                    'Login as Super Admin (Platform Owner)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 2: Client CEO
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsCeo();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.purpleAccent,
                    side: const BorderSide(color: Colors.purpleAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                  label: Text(
                    'Login as Client CEO',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 3: Client HR
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsHr();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.badge_rounded, size: 18),
                  label: Text(
                    'Login as Client HR',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 4: Warehouse Picker
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsWarehousePicker();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.inventory_2_rounded, size: 18),
                  label: Text(
                    'Login as Warehouse Picker (Dispatch & Picking)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 5: Catalog Admin
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsCatalogAdmin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(
                    'Login as Catalog Admin (Register Pictures)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 6: Storekeeper (Real Barcode Scanner)
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsStorekeeper();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: Text(
                    'Login as Storekeeper (Stock Receiving)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 7: Branch Manager
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsBranchManager();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.tealAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.store_mall_directory_rounded, size: 18),
                  label: Text(
                    'Login as Branch Manager (Pharmacist)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 8: Telesales POS
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsTelesales();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.pinkAccent,
                    side: const BorderSide(color: Colors.pinkAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                  label: Text(
                    'Login as Telesales (POS)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 9: Secretary
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsSecretary();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.indigoAccent,
                    side: const BorderSide(color: Colors.indigoAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                  label: Text(
                    'Login as Secretary (Finance)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 10: Rider
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsRider();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.deepOrangeAccent,
                    side: const BorderSide(color: Colors.deepOrangeAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                  label: Text(
                    'Login as Rider (Dispatch)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),

                // Button 11: Marketer
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsMarketer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.limeAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.limeAccent,
                    side: const BorderSide(color: Colors.limeAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: Text(
                    'Login as Marketer (Field Sales)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
