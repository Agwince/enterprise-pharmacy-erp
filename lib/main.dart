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
import 'screens/stock_putaway_screen.dart';
import 'screens/branch_manager_home.dart';
import 'screens/storekeeper_home.dart';
import 'screens/catalog_admin_home.dart';
import 'screens/floor_worker_home.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Supabase Client
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      // Force clear any corrupted session token from localStorage
      // so the app correctly defaults to the working anonKey.
      await Supabase.instance.client.auth.signOut();
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
  } catch (e, stackTrace) {
    debugPrint('Fatal initialization error: $e\n$stackTrace');
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Warning',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The application encountered an initialization error:\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => runApp(const PharmacyErpApp()),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                    child: const Text('Proceed to App'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
            return const FloorWorkerHome();
          case UserRole.catalogAdmin:
            return const CatalogAdminHome();
          case UserRole.storekeeper:
            return const StorekeeperHome();
          case UserRole.branchManager:
            return const BranchManagerHome();
          case UserRole.none:
          default:
            return const LoginScreen();
        }
      },
    );
  }
}
