import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/offline_sync_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/ceo_dashboard_screen.dart';
import 'screens/smart_replenishment_screen.dart';
import 'screens/breakdown_workspace_screen.dart';
import 'screens/pick_path_gps_screen.dart';
import 'screens/admin_hr_workspace_screen.dart';

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
      title: 'Enterprise Pharmacy ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.blueAccent,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const RootAppShell(),
    );
  }
}

class RootAppShell extends StatelessWidget {
  const RootAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService(),
      builder: (context, _) {
        if (!AuthService().isAuthenticated) {
          return const LoginScreen();
        }
        return const MainNavigationShell();
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset selection on role change
    _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final isCeo = auth.role == UserRole.ceo;

    // Strict Role-Based Access Control Filtering Rules
    final List<Widget> roleScreens = isCeo
        ? const [
            CeoDashboardScreen(),
            AdminHrWorkspaceScreen(),
          ]
        : const [
            BreakdownWorkspaceScreen(),
            PickPathGpsScreen(),
          ];

    final List<NavigationRailDestination> railDestinations = isCeo
        ? const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: Text('CEO Dashboard'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge_rounded),
              label: Text('Admin & HR'),
            ),
          ]
        : const [
            NavigationRailDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded),
              label: Text('Breakdown'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.navigation_outlined),
              selectedIcon: Icon(Icons.navigation_rounded),
              label: Text('Pick GPS'),
            ),
          ];

    final List<NavigationDestination> barDestinations = isCeo
        ? const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded, color: Colors.cyanAccent),
              label: 'CEO',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge_rounded, color: Colors.cyanAccent),
              label: 'Admin',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded, color: Colors.cyanAccent),
              label: 'Intake',
            ),
            NavigationDestination(
              icon: Icon(Icons.navigation_outlined),
              selectedIcon: Icon(Icons.navigation_rounded, color: Colors.cyanAccent),
              label: 'Pick GPS',
            ),
          ];

    // Ensure index bounds safety
    final safeIndex = _selectedIndex >= roleScreens.length ? 0 : _selectedIndex;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              backgroundColor: const Color(0xFF1E293B),
              selectedIndex: safeIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: Colors.cyanAccent),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCeo
                              ? [Colors.purpleAccent, Colors.blueAccent]
                              : [Colors.cyanAccent, Colors.tealAccent],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCeo ? Icons.admin_panel_settings : Icons.storefront_rounded,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCeo ? 'EXECUTIVE' : 'FLOOR OPS',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        color: isCeo ? Colors.purpleAccent : Colors.cyanAccent,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: IconButton(
                      tooltip: 'Logout / Switch Role',
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      onPressed: () {
                        setState(() => _selectedIndex = 0);
                        auth.logout();
                      },
                    ),
                  ),
                ),
              ),
              destinations: railDestinations,
            ),
          Expanded(
            child: Stack(
              children: [
                roleScreens[safeIndex],

                // Role Indicator Header Strip
                Positioned(
                  top: 16,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCeo ? Colors.purpleAccent.withValues(alpha: 0.4) : Colors.cyanAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_circle_rounded,
                          size: 16,
                          color: isCeo ? Colors.purpleAccent : Colors.cyanAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          auth.userName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () {
                            setState(() => _selectedIndex = 0);
                            auth.logout();
                          },
                          child: const Icon(Icons.logout_rounded, size: 14, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              backgroundColor: const Color(0xFF1E293B),
              indicatorColor: isCeo ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.cyanAccent.withValues(alpha: 0.2),
              selectedIndex: safeIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: barDestinations,
            ),
    );
  }
}
