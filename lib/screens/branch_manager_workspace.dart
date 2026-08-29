import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'branch_dashboard_screen.dart';
import 'kisumu_in_transit_screen.dart';
import 'location_manager_screen.dart';
import 'store_mapping_screen.dart';
import 'wholesale_catalog_screen.dart';
import 'ppb_compliance_screen.dart';

class BranchManagerWorkspace extends StatefulWidget {
  const BranchManagerWorkspace({super.key});

  @override
  State<BranchManagerWorkspace> createState() => _BranchManagerWorkspaceState();
}

class _BranchManagerWorkspaceState extends State<BranchManagerWorkspace> {
  int _selectedIndex = 0;

  Widget _buildContent() {
    switch (_selectedIndex) {
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

  Widget _buildSidebar(bool isDesktop) {
    return Container(
      width: 270,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.tealAccent, Colors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: Color(0xFF0F172A),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branch Manager',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Nairobi Central Branch',
                        style: GoogleFonts.inter(
                          color: Colors.tealAccent,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Navigation Items
          _buildNavItem(0, 'Branch Dashboard', Icons.dashboard_rounded, isDesktop),
          _buildNavItem(1, 'Kisumu In-Transit Tracker', Icons.local_shipping_rounded, isDesktop, badge: 'Live GPS'),
          _buildNavItem(2, 'PPB Compliance & Expiry', Icons.verified_user_rounded, isDesktop, badge: 'Grade A'),
          _buildNavItem(3, 'Live Catalog (782 SKUs)', Icons.inventory_2_rounded, isDesktop),
          _buildNavItem(4, 'Location Manager', Icons.location_city_rounded, isDesktop),
          _buildNavItem(5, 'Store Setup & Racks', Icons.map_rounded, isDesktop),

          const Spacer(),

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: OutlinedButton.icon(
              onPressed: () => AuthService().logout(),
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
              label: Text(
                'Logout',
                style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDesktop ? 'Branch Manager Workspace (Pharmacist)' : 'Branch Manager',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 16 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Nairobi Central • Decentralized Operations',
                    style: GoogleFonts.inter(
                      color: Colors.tealAccent,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: OutlinedButton.icon(
                onPressed: () => AuthService().logout(),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
                label: Text(
                  'Logout',
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () => AuthService().logout(),
            ),
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(isDesktop)),
      body: isDesktop
          ? Row(
              children: [
                _buildSidebar(isDesktop),
                Expanded(child: _buildContent()),
              ],
            )
          : _buildContent(),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (idx) => setState(() => _selectedIndex = idx),
                backgroundColor: const Color(0xFF1E293B),
                selectedItemColor: Colors.tealAccent,
                unselectedItemColor: Colors.white54,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 11,
                unselectedFontSize: 10,
                selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                  BottomNavigationBarItem(icon: Icon(Icons.local_shipping_rounded), label: 'Kisumu Transit'),
                  BottomNavigationBarItem(icon: Icon(Icons.verified_user_rounded), label: 'PPB Expiry'),
                  BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Catalog'),
                  BottomNavigationBarItem(icon: Icon(Icons.location_city_rounded), label: 'Locations'),
                  BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Store Map'),
                ],
              ),
            ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, bool isDesktop, {String? badge}) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 3.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? Colors.tealAccent.withValues(alpha: 0.15) : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? Colors.tealAccent : Colors.white70,
          size: 20,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.tealAccent : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          if (!isDesktop) Navigator.pop(context);
        },
      ),
    );
  }
}
