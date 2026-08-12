import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'invoice_scanner_screen.dart';

class WholesaleCatalogScreen extends StatefulWidget {
  const WholesaleCatalogScreen({super.key});

  @override
  State<WholesaleCatalogScreen> createState() => _WholesaleCatalogScreenState();
}

class _WholesaleCatalogScreenState extends State<WholesaleCatalogScreen> {
  final List<Map<String, dynamic>> _wholesaleItems = [
    {
      'sku': 'WHOLE-AMOX-500',
      'name': 'Amoxicillin Trihydrate 500mg (Bulk Cartons)',
      'genericName': 'Amoxicillin',
      'category': 'Antibiotic Wholesale',
      'pallets': 12,
      'cartons': 240,
      'boxesAvailable': '12,000 Boxes',
      'binLocation': 'AISLE 1 - PALLET BAY A4',
      'image': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
    },
    {
      'sku': 'WHOLE-PARA-1000',
      'name': 'Paracetamol Extra 500mg/65mg (Bulk Pallets)',
      'genericName': 'Paracetamol + Caffeine',
      'category': 'Analgesic Bulk',
      'pallets': 28,
      'cartons': 560,
      'boxesAvailable': '28,000 Boxes',
      'binLocation': 'AISLE 2 - PALLET BAY B1',
      'image': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80',
    },
    {
      'sku': 'WHOLE-IBU-400',
      'name': 'Ibuprofen Suspension 100mg/5ml (Wholesale Crate)',
      'genericName': 'Ibuprofen',
      'category': 'Pediatric Care',
      'pallets': 8,
      'cartons': 160,
      'boxesAvailable': '6,400 Bottles',
      'binLocation': 'AISLE 3 - PALLET BAY C2',
      'image': 'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800&auto=format&fit=crop&q=80',
    },
    {
      'sku': 'WHOLE-METF-850',
      'name': 'Metformin HCl 850mg (Master Pallet Stack)',
      'genericName': 'Metformin Hydrochloride',
      'category': 'Endocrinology Bulk',
      'pallets': 15,
      'cartons': 300,
      'boxesAvailable': '15,000 Boxes',
      'binLocation': 'AISLE 4 - PALLET BAY D5',
      'image': 'https://images.unsplash.com/photo-1585435557343-3b092031a831?w=800&auto=format&fit=crop&q=80',
    },
    {
      'sku': 'WHOLE-AZITH-250',
      'name': 'Azithromycin 250mg Film-Coated (Wholesale Pallet)',
      'genericName': 'Azithromycin Monohydrate',
      'category': 'Macrolide Antibiotics',
      'pallets': 6,
      'cartons': 120,
      'boxesAvailable': '4,800 Boxes',
      'binLocation': 'AISLE 1 - PALLET BAY A9',
      'image': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
    },
    {
      'sku': 'WHOLE-OMEP-20',
      'name': 'Omeprazole Delayed Release 20mg (Bulk Cartons)',
      'genericName': 'Omeprazole',
      'category': 'Gastrointestinal Bulk',
      'pallets': 19,
      'cartons': 380,
      'boxesAvailable': '19,000 Boxes',
      'binLocation': 'AISLE 5 - PALLET BAY E3',
      'image': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                color: Colors.cyanAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Colors.cyanAccent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wholesale Medicine Catalog & Picking Engine',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Warehouse Operations • Bulk Pallet & Box Inventory',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.w600),
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
              label: Text('Logout Picker', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0F172A)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.warehouse_rounded, size: 40, color: Colors.cyanAccent),
                  const SizedBox(height: 12),
                  Text('Floor Ops Workspace', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(AuthService().userName, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_rounded, color: Colors.cyanAccent),
              title: Text('Wholesale Catalog', style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              selected: true,
              selectedTileColor: Colors.cyanAccent.withValues(alpha: 0.1),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_rounded, color: Colors.white54),
              title: Text('Invoice Auto-Picker', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) => const InvoiceScannerScreen(),
                    transitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Metrics Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Master Stock Directory',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '88 Total Pallet Bays • 85,200 Boxes Ready for Allocation',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.cyanAccent),
                    ),
                    child: Text(
                      'Warehouse Picker Session Active',
                      style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Wholesale Inventory Grid
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 1200
                    ? 3
                    : constraints.maxWidth > 750
                        ? 2
                        : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: crossAxisSpacingForWidth(constraints.maxWidth),
                    mainAxisSpacing: 20,
                    mainAxisExtent: 440,
                  ),
                  itemCount: _wholesaleItems.length,
                  itemBuilder: (context, index) {
                    final item = _wholesaleItems[index];

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Task 3: Prominent High-Res CachedNetworkImage
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: item['image'],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: const Color(0xFF0F172A),
                                      child: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: const Color(0xFF0F172A),
                                      child: const Icon(Icons.medication_rounded, size: 50, color: Colors.cyanAccent),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        item['sku'],
                                        style: GoogleFonts.inter(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Card Data Points
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Generic: ${item['genericName']}',
                                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),

                                  // Location & Stock Badges
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          'LOCATION: ${item['binLocation']}',
                                          style: GoogleFonts.inter(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Stock Available:',
                                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                          ),
                                          Text(
                                            '${item['pallets']} Pallets (${item['boxesAvailable']})',
                                            style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Action Pick Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFF10B981),
                                            content: Text(
                                              'Allocated 1 Pallet (${item['sku']}) for Dispatch!',
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.cyanAccent,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.outbox_rounded, size: 18),
                                      label: Text('Allocate Pallet for Dispatch', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  double crossAxisSpacingForWidth(double width) {
    if (width > 1200) return 24;
    return 16;
  }
}
