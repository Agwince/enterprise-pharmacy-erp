import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/offline_sync_service.dart';
import 'screens/ceo_dashboard_screen.dart';
import 'screens/smart_replenishment_screen.dart';
import 'screens/breakdown_workspace_screen.dart';
import 'screens/pick_path_gps_screen.dart';

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
      home: const MainNavigationShell(),
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

  final List<Widget> _screens = const [
    CeoDashboardScreen(),
    SmartReplenishmentScreen(),
    BreakdownWorkspaceScreen(),
    PickPathGpsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              backgroundColor: const Color(0xFF1E293B),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: Colors.cyanAccent),
              selectedLabelStyle: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded, color: Colors.black, size: 28),
                    ),
                    const SizedBox(height: 8),
                    Text('PHARMA ERP', style: GoogleFonts.inter(fontWeight: FontWeight.black, fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: Text('CEO Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded),
                  label: Text('Replenishment'),
                ),
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
              ],
            ),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              backgroundColor: const Color(0xFF1E293B),
              indicatorColor: Colors.cyanAccent.withOpacity(0.2),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded, color: Colors.cyanAccent),
                  label: 'CEO',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded, color: Colors.cyanAccent),
                  label: 'Replenish',
                ),
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
              ],
            ),
    );
  }
}
