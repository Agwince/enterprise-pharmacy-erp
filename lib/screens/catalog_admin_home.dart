import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'receive_delivery_scanner.dart';
import 'register_product_screen.dart';
import 'catalog_list_screen.dart';

class CatalogAdminHome extends StatefulWidget {
  const CatalogAdminHome({super.key});

  @override
  State<CatalogAdminHome> createState() => _CatalogAdminHomeState();
}

class _CatalogAdminHomeState extends State<CatalogAdminHome> {
  int _currentIndex = 0;

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const CatalogListScreen(mode: IntakeMode.fullBox);
      case 1:
        return const CatalogListScreen(mode: IntakeMode.looseUnit);
      default:
        return const CatalogListScreen(mode: IntakeMode.fullBox);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Catalog Admin',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
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
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF1E293B),
          selectedItemColor: Colors.amberAccent,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded, color: Colors.amberAccent),
              label: 'Store Intake (Boxes)',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication_liquid_outlined),
              activeIcon: Icon(Icons.medication_liquid_rounded, color: Colors.amberAccent),
              label: 'Pharmacy Intake (Loose)',
            ),
          ],
        ),
      ),
    );
  }
}
