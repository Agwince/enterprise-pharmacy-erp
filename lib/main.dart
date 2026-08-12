import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/offline_sync_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/super_admin_workspace.dart';
import 'screens/ceo_dashboard_screen.dart';
import 'screens/admin_hr_workspace_screen.dart';
import 'screens/invoice_scanner_screen.dart';
import 'screens/branch_manager_workspace.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Client
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization note: $e');
  }

  // Initialize Offline Caching Queue (Hive)
  try {
    await OfflineSyncService().initialize();
  } catch (e) {
    debugPrint('Offline sync initialization note: $e');
  }

  runApp(const PharmacyErpApp());
}

class PharmacyErpApp extends StatelessWidget {
  const PharmacyErpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enterprise Pharmacy ERP (Wholesale B2B SaaS)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.blueAccent,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const StrictAuthRoleRouter(),
    );
  }
}

class StrictAuthRoleRouter extends StatelessWidget {
  const StrictAuthRoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService(),
      builder: (context, _) {
        final auth = AuthService();

        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        // Strict Role Routing - Dedicated Workspaces (No Shared Global Sidebar)
        switch (auth.role) {
          case UserRole.superAdmin:
            return const SuperAdminWorkspaceScreen();
          case UserRole.ceo:
            return const CeoDashboardScreen();
          case UserRole.hr:
            return const AdminHrWorkspaceScreen();
          case UserRole.warehousePicker:
            return const InvoiceScannerScreen();
          case UserRole.branchManager:
            return const BranchManagerWorkspace();
          case UserRole.none:
          default:
            return const LoginScreen();
        }
      },
    );
  }
}
