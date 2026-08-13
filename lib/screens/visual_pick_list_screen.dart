import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'invoice_scanner_screen.dart';

class VisualPickListScreen extends StatefulWidget {
  const VisualPickListScreen({super.key});

  @override
  State<VisualPickListScreen> createState() => _VisualPickListScreenState();
}

class _VisualPickListScreenState extends State<VisualPickListScreen> {
  final List<Map<String, dynamic>> _extractedItems = [
    {
      'name': 'AMOXICILLIN 500MG 100\'S',
      'pick_quantity': 0.10,
      'unit_label': 'Pick: 0.10 (1 Loose Blister Strip of 10 Caps)',
      'location': '📍 LOCATION: AISLE 1 - SHELF B2',
      'box_image_url': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80',
      'loose_unit_image_url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
    {
      'name': 'PANADOL EXTRA 100\'S',
      'pick_quantity': 1.0,
      'unit_label': 'Pick: 1.0 (Full Sealed Box of 100)',
      'location': '📍 LOCATION: AISLE 1 - SHELF A1',
      'box_image_url': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80',
      'loose_unit_image_url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
    {
      'name': 'ABZ SUSPENSION 10ML',
      'pick_quantity': 0.50,
      'unit_label': 'Pick: 0.50 (1 Loose Bottle 10ml)',
      'location': '📍 LOCATION: AISLE 1 - SHELF B2',
      'box_image_url': 'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800&auto=format&fit=crop&q=80',
      'loose_unit_image_url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
    {
      'name': 'FLUGONE EXP 60MLS',
      'pick_quantity': 15.0,
      'unit_label': 'Pick: 15.0 (Wholesale Master Crate)',
      'location': '📍 LOCATION: AISLE 3 - SHELF C1',
      'box_image_url': 'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800&auto=format&fit=crop&q=80',
      'loose_unit_image_url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const InvoiceScannerScreen()),
            );
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.task_alt_rounded, color: Colors.greenAccent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visual Pick List (Fractional 0.10 Engine)',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Generated from Invoice OCR • Whole Box vs Loose Unit Mode',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w600),
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
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _extractedItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final item = _extractedItems[index];
            final double qty = (item['pick_quantity'] as num).toDouble();
            final bool isFractional = qty < 1.0;
            final String imageUrl = isFractional ? item['loose_unit_image_url'] : item['box_image_url'];

            return Container(
              decoration: BoxDecoration(
                color: item['checked'] ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item['checked']
                      ? Colors.greenAccent.withValues(alpha: 0.5)
                      : (isFractional ? Colors.orangeAccent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08)),
                  width: item['checked'] || isFractional ? 2 : 1,
                ),
                boxShadow: item['checked'] ? [] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FRACTIONAL VS WHOLE UNIT WARNING TAG
                    if (isFractional)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orangeAccent, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ OPEN BOX: PICK LOOSE STRIPS/UNITS (0.10 FRACTIONAL)',
                                style: GoogleFonts.inter(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_rounded, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '📦 FULL SEALED BOX (1.0 WHOLE UNIT)',
                              style: GoogleFonts.inter(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      children: [
                        // Dynamic Image on Left (Swaps between Box & Loose Unit)
                        Stack(
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF0F172A),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: const Color(0xFF0F172A),
                                    child: const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: const Color(0xFF0F172A),
                                    child: const Icon(Icons.medication_rounded, size: 40, color: Colors.purpleAccent),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isFractional ? '💊 LOOSE UNIT' : '📦 BOX',
                                  style: GoogleFonts.inter(
                                    color: isFractional ? Colors.orangeAccent : Colors.cyanAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 16),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: GoogleFonts.inter(
                                  color: item['checked'] ? Colors.white54 : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: item['checked'] ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['unit_label'],
                                style: GoogleFonts.inter(
                                  color: isFractional ? Colors.orangeAccent : Colors.purpleAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  item['location'],
                                  style: GoogleFonts.inter(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Interactive Checkbox on Right
                        InkWell(
                          onTap: () {
                            setState(() {
                              item['checked'] = !item['checked'];
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: item['checked'] ? Colors.greenAccent : Colors.transparent,
                                border: Border.all(color: item['checked'] ? Colors.greenAccent : Colors.white54, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: item['checked']
                                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 32)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
