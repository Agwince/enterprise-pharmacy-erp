import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'invoice_scanner_screen.dart';
import 'visual_pick_list_screen.dart';

class FloorWorkerHome extends StatefulWidget {
  const FloorWorkerHome({super.key});

  @override
  State<FloorWorkerHome> createState() => _FloorWorkerHomeState();
}

class _FloorWorkerHomeState extends State<FloorWorkerHome> {
  int _currentIndex = 0;

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const InvoiceScannerScreen();
      case 1:
        return const VisualPickListScreen();
      default:
        return const InvoiceScannerScreen();
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
          selectedItemColor: Colors.greenAccent,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.document_scanner_rounded),
              activeIcon: Icon(Icons.document_scanner_rounded, color: Colors.greenAccent),
              label: 'Invoice Scanner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              activeIcon: Icon(Icons.map_rounded, color: Colors.greenAccent),
              label: 'Visual Pick List',
            ),
          ],
        ),
      ),
    );
  }
}
