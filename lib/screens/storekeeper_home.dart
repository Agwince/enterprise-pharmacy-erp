import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'stock_putaway_screen.dart';
import 'register_product_screen.dart';
import 'catalog_list_screen.dart';

class StorekeeperHome extends StatefulWidget {
  const StorekeeperHome({super.key});

  @override
  State<StorekeeperHome> createState() => _StorekeeperHomeState();
}

class _StorekeeperHomeState extends State<StorekeeperHome> {
  int _currentIndex = 0;

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const StockPutawayScreen();
      case 1:
        return const CatalogListScreen();
      default:
        return const StockPutawayScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
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
          selectedItemColor: Colors.amberAccent,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              activeIcon: Icon(Icons.qr_code_scanner_rounded, color: Colors.amberAccent),
              label: 'Intake Putaway',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline_rounded),
              activeIcon: Icon(Icons.add_circle_outline_rounded, color: Colors.amberAccent),
              label: 'Register Product',
            ),
          ],
        ),
      ),
    );
  }
}
