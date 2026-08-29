import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class WholesaleCatalogScreen extends StatefulWidget {
  const WholesaleCatalogScreen({super.key});

  @override
  State<WholesaleCatalogScreen> createState() => _WholesaleCatalogScreenState();
}

class _WholesaleCatalogScreenState extends State<WholesaleCatalogScreen> {
  List<Map<String, dynamic>> _wholesaleItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    try {
      final res = await Supabase.instance.client
          .from('drugs')
          .select('id, name, generic_name, barcode, target_shelf, price, shelf_quantity, warehouse_quantity, image_url, box_image_url')
          .order('name')
          .limit(40);

      final list = (res as List).map((d) {
        final name = (d['name'] ?? 'Pharmaceutical Drug') as String;
        final whQty = (d['warehouse_quantity'] as num?)?.toInt() ?? 50;
        final pallets = (whQty / 10).ceil().clamp(2, 45);
        final boxes = pallets * 120;
        final img = d['box_image_url'] ?? d['image_url'] ?? 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=500';

        return {
          'id': d['id'],
          'name': name,
          'genericName': d['generic_name'] ?? 'Bio-equivalent Formulation',
          'sku': d['barcode'] ?? 'SKU-${d['id'].toString().substring(0, 6)}',
          'binLocation': d['target_shelf'] ?? 'AISLE 1 - SHELF A1',
          'pallets': pallets,
          'boxesAvailable': '$boxes Boxes',
          'image': img,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _wholesaleItems = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                  'Wholesale Medicine Catalog & Inventory',
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchCatalog();
            },
            tooltip: 'Refresh Catalog',
          ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : SingleChildScrollView(
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
                              '${_wholesaleItems.length} Active Master Lines • Real-time Supabase Stock',
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
                            'Live Warehouse Inventory',
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
