import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'branch_dashboard_screen.dart';
import 'kisumu_in_transit_screen.dart';
import 'location_manager_screen.dart';
import 'store_mapping_screen.dart';
import 'wholesale_catalog_screen.dart';
import 'ppb_compliance_screen.dart';

class BranchManagerHome extends StatefulWidget {
  const BranchManagerHome({super.key});

  @override
  State<BranchManagerHome> createState() => _BranchManagerHomeState();
}

class _BranchManagerHomeState extends State<BranchManagerHome> {
  int _currentIndex = 0;

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const BranchDashboardScreen();
      case 1:
        return const KisumuInTransitScreen();
      case 2:
        return const PpbComplianceScreen();
      case 3:
        return const WholesaleCatalogScreen();
      case 4:
        return const LocationManagerScreen();
      case 5:
        return const StoreMappingScreen();
      default:
        return const BranchDashboardScreen();
    }
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
                color: Colors.tealAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.store_rounded, color: Colors.tealAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branch Manager Workspace',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Nairobi Central • Decentralized Operations',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                ),
              ],
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
              label: Text('Logout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: const Color(0xFF1E293B),
          selectedItemColor: Colors.tealAccent,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              activeIcon: Icon(Icons.dashboard_rounded, color: Colors.tealAccent),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_rounded),
              activeIcon: Icon(Icons.local_shipping_rounded, color: Colors.tealAccent),
              label: 'Kisumu Transit',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.verified_user_rounded),
              activeIcon: Icon(Icons.verified_user_rounded, color: Colors.tealAccent),
              label: 'PPB Expiry',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded),
              activeIcon: Icon(Icons.inventory_2_rounded, color: Colors.tealAccent),
              label: 'Catalog',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_city_rounded),
              activeIcon: Icon(Icons.location_city_rounded, color: Colors.tealAccent),
              label: 'Locations',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              activeIcon: Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent),
              label: 'Map Store',
            ),
          ],
        ),
      ),
    );
  }
}
