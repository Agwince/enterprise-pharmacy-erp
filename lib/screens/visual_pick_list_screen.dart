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
      'name': 'Amoxicillin Trihydrate 500mg',
      'qty': 'Pick: 15 Cartons',
      'location': '📍 GO TO: AISLE 1 - PALLET BAY A4',
      'image': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
    {
      'name': 'Paracetamol Extra 500mg/65mg',
      'qty': 'Pick: 28 Pallets',
      'location': '📍 GO TO: AISLE 2 - PALLET BAY B1',
      'image': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
    {
      'name': 'Ibuprofen Suspension 100mg/5ml',
      'qty': 'Pick: 8 Wholesale Crates',
      'location': '📍 GO TO: AISLE 3 - PALLET BAY C2',
      'image': 'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800&auto=format&fit=crop&q=80',
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
                  'Visual Pick List',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Generated from Invoice OCR',
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
          separatorBuilder: (context, index) => const SizedBox(height: 24),
          itemBuilder: (context, index) {
            final item = _extractedItems[index];
            return Container(
              decoration: BoxDecoration(
                color: item['checked'] ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item['checked'] ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
                  width: item['checked'] ? 2 : 1,
                ),
                boxShadow: item['checked'] ? [] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Large Image on Left
                  Container(
                    width: 140,
                    height: 140,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: item['image'],
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

                  // Middle Details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: GoogleFonts.inter(
                              color: item['checked'] ? Colors.white54 : Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              decoration: item['checked'] ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['qty'],
                            style: GoogleFonts.inter(
                              color: Colors.purpleAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item['checked'] ? Colors.greenAccent : Colors.transparent,
                          border: Border.all(color: item['checked'] ? Colors.greenAccent : Colors.white54, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: item['checked']
                            ? const Icon(Icons.check_rounded, color: Colors.black, size: 36)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
