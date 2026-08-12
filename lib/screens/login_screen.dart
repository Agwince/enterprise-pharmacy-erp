import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'ceo@pharmacy.com');
  final _passwordController = TextEditingController(text: '••••••••');
  bool _isLoading = false;

  void _handleStandardLogin() async {
    setState(() => _isLoading = true);
    await AuthService().signInWithEmailPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.blueAccent, Colors.cyanAccent],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_pharmacy_rounded,
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enterprise Pharmacy ERP',
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
                  'Multi-Tenant SaaS Gateway • RBAC Enabled',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),

                // Email Input
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
                    hintText: 'user@pharmacy.com',
                    hintStyle: GoogleFonts.inter(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Input
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
                const SizedBox(height: 32),

                // Divider for Demo Quick Login
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
                const SizedBox(height: 20),

                // Quick Login Button 1: CEO
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsCeo();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.purpleAccent,
                    side: const BorderSide(color: Colors.purpleAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
                  label: Text(
                    'Login as CEO (Executive Role)',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Login Button 2: Storekeeper
                ElevatedButton.icon(
                  onPressed: () {
                    AuthService().loginAsStorekeeper();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.inventory_2_rounded, size: 20),
                  label: Text(
                    'Login as Storekeeper (Floor Role)',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
