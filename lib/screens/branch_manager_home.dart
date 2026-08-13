import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'branch_dashboard_screen.dart';
import 'location_manager_screen.dart';
import 'catalog_photo_studio.dart';
import 'store_mapping_screen.dart';

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
        return const LocationManagerScreen();
      case 2:
        return _buildLocalInventoryView();
      case 3:
        return const CatalogPhotoStudioScreen();
      case 4:
        return const StoreMappingScreen();
      default:
        return const BranchDashboardScreen();
    }
  }

  Widget _buildLocalInventoryView() {
    final mockInventory = [
      {'sku': 'SKU-1001', 'name': 'Amoxicillin 500mg', 'location': 'Aisle 1 - Shelf A', 'stock': '50 Cartons', 'status': 'Optimal'},
      {'sku': 'SKU-1002', 'name': 'Paracetamol 500mg', 'location': 'Aisle 1 - Shelf A', 'stock': '120 Cartons', 'status': 'Optimal'},
      {'sku': 'SKU-1003', 'name': 'Ibuprofen 400mg', 'location': 'Aisle 1 - Shelf B', 'stock': '35 Cartons', 'status': 'Optimal'},
      {'sku': 'SKU-1004', 'name': 'Azithromycin 250mg', 'location': 'Aisle 2 - Shelf A', 'stock': '25 Cartons', 'status': 'Low Stock'},
      {'sku': 'SKU-1005', 'name': 'Insulin Glargine', 'location': 'Aisle 3 - Shelf A', 'stock': '15 Vials', 'status': 'Critical Cold'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Branch Inventory',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nairobi Central Branch • Stock Control',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '5 SKUs Live',
                    style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: mockInventory.length,
                separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                itemBuilder: (context, index) {
                  final item = mockInventory[index];
                  final isLow = item['status'] == 'Low Stock';
                  final isCold = item['status'] == 'Critical Cold';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCold ? Icons.ac_unit_rounded : Icons.inventory_2_rounded,
                        color: isCold ? Colors.cyanAccent : (isLow ? Colors.orangeAccent : Colors.tealAccent),
                      ),
                    ),
                    title: Text(
                      item['name']!,
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      '${item['sku']} • ${item['location']}',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item['stock']!,
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['status']!,
                          style: GoogleFonts.inter(
                            color: isCold ? Colors.cyanAccent : (isLow ? Colors.orangeAccent : Colors.tealAccent),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              activeIcon: Icon(Icons.dashboard_rounded, color: Colors.tealAccent),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_city_rounded),
              activeIcon: Icon(Icons.location_city_rounded, color: Colors.tealAccent),
              label: 'Locations',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_rounded),
              activeIcon: Icon(Icons.inventory_2_rounded, color: Colors.tealAccent),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_enhance_rounded),
              activeIcon: Icon(Icons.camera_enhance_rounded, color: Colors.tealAccent),
              label: 'Photo Studio',
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
