import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'branch_dashboard_screen.dart';
import 'location_manager_screen.dart';
import 'store_mapping_screen.dart';
import 'wholesale_catalog_screen.dart';

class BranchManagerWorkspace extends StatefulWidget {
  const BranchManagerWorkspace({Key? key}) : super(key: key);

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
        return const WholesaleCatalogScreen();
      case 2:
        return const LocationManagerScreen();
      case 3:
        return const StoreMappingScreen();
      default:
        return const BranchDashboardScreen();
    }
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
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
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branch Manager',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Nairobi Central Branch',
                        style: GoogleFonts.inter(
                          color: Colors.tealAccent,
                          fontSize: 12,
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
          const SizedBox(height: 16),
          // Navigation Items
          _buildNavItem(0, 'Branch Dashboard', Icons.dashboard_rounded),
          _buildNavItem(1, 'Local Inventory', Icons.inventory_2_rounded),
          _buildNavItem(2, 'Location Manager', Icons.location_city_rounded),
          _buildNavItem(3, 'Store Setup', Icons.map_rounded),
          const Spacer(),
          // Logout Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: OutlinedButton.icon(
              onPressed: () {
                AuthService().logout();
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              label: Text(
                'Logout',
                style: GoogleFonts.inter(color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(double.infinity, 48),
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
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: isDesktop 
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.store_rounded, color: Colors.tealAccent, size: 20),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Branch Manager Workspace',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Nairobi Central • Decentralized Operations',
                      style: GoogleFonts.inter(
                        color: Colors.tealAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Text(
              'Branch Manager',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
        actions: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 12, bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  AuthService().logout();
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                label: Text(
                  'Logout',
                  style: GoogleFonts.inter(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () {
                AuthService().logout();
              },
            ),
        ],
      ),
      drawer: isDesktop ? null : Drawer(
        child: _buildSidebar(),
      ),
      body: isDesktop 
          ? Row(
              children: [
                _buildSidebar(),
                Expanded(child: _buildContent()),
              ],
            )
          : _buildContent(),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: isSelected ? Colors.tealAccent.withOpacity(0.15) : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? Colors.tealAccent : Colors.white70,
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.tealAccent : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
