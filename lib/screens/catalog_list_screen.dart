import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_product_screen.dart';

class CatalogListScreen extends StatefulWidget {
  const CatalogListScreen({super.key});

  @override
  State<CatalogListScreen> createState() => _CatalogListScreenState();
}

class _CatalogListScreenState extends State<CatalogListScreen> {
  static const List<Map<String, dynamic>> _catalogItems = [
    {'name': 'ABZ SUSPENSION 10ML', 'price': '41.00', 'type': 'Bottle'},
    {'name': 'KOFGON GREEN 60ML', 'price': '25.00', 'type': 'Bottle'},
    {'name': 'KOFGON GREEN 100ML', 'price': '33.00', 'type': 'Bottle'},
    {'name': 'PANADOL EXTRA 100S', 'price': '780.00', 'type': 'Strip/Blister'},
    {'name': 'AMOXICILLIN 500MG 100S', 'price': '295.00', 'type': 'Strip/Blister'},
    {'name': 'BRUFEN 400MG 100S', 'price': '130.00', 'type': 'Strip/Blister'},
  ];

  List<Map<String, dynamic>> _localRegisteredItems = [];

  @override
  void initState() {
    super.initState();
    _loadLocalCatalog();
  }

  Future<void> _loadLocalCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('local_drugs_catalog') ?? [];
    List<Map<String, dynamic>> parsed = [];
    for (String itemStr in saved) {
      try {
        final decoded = jsonDecode(itemStr) as Map<String, dynamic>;
        parsed.add(decoded);
      } catch (e) {
        debugPrint('Error decoding local drug item: $e');
      }
    }
    if (mounted) {
      setState(() {
        _localRegisteredItems = parsed;
      });
    }
  }

  void _openAttachPhotoForm(BuildContext context, Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterProductScreen(
          prefilledName: item['name'] as String,
          prefilledPrice: double.tryParse(item['price']?.toString() ?? '0.0'),
          prefilledSku: 'NRB-MED-${1000 + item['name'].hashCode % 8999}',
          prefilledUnit: (item['type'] ?? item['inner_unit_type']) as String?,
        ),
      ),
    );
    if (result == true) {
      _loadLocalCatalog();
    }
  }

  void _openBlankForm(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterProductScreen(),
      ),
    );
    if (result == true) {
      _loadLocalCatalog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nairobi Official Catalog Intake',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Select an item to attach photos or add unlisted drugs.',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBlankForm(context),
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('Register Unlisted Medicine', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_enhance_rounded, color: Colors.amberAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Missing Photos Queue',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap any item below to pre-fill the form and attach packaging photos.',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Seeded Price List (August 2026)',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Merged catalog list (Seeded + Registered Local Items)
            Builder(builder: (context) {
              final allItems = <Map<String, dynamic>>[];

              // Map local registered items into display format
              for (var local in _localRegisteredItems) {
                allItems.add({
                  'name': local['name'],
                  'price': local['unit_price']?.toString() ?? local['price']?.toString() ?? '0.00',
                  'type': local['inner_unit_type'] ?? 'Strip/Blister',
                  'box_image_url': local['image_url'],
                  'loose_image_url': local['inner_unit_image_url'],
                  'is_local': true,
                });
              }

              // Add seeded items if not already registered locally
              for (var seeded in _catalogItems) {
                final exists = allItems.any((i) => (i['name'] as String).toUpperCase() == (seeded['name'] as String).toUpperCase());
                if (!exists) {
                  allItems.add({
                    'name': seeded['name'],
                    'price': seeded['price'],
                    'type': seeded['type'],
                    'is_local': false,
                  });
                }
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  final String? boxBase64 = item['box_image_url'] as String?;
                  final bool hasPhotos = boxBase64 != null && boxBase64.isNotEmpty;

                  Uint8List? decodedBytes;
                  if (hasPhotos) {
                    try {
                      decodedBytes = base64Decode(boxBase64);
                    } catch (_) {}
                  }

                  return Card(
                    color: const Color(0xFF1E293B),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: hasPhotos
                            ? Colors.greenAccent.withValues(alpha: 0.5)
                            : Colors.orangeAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _openAttachPhotoForm(context, item),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: decodedBytes != null
                                    ? Image.memory(decodedBytes, fit: BoxFit.cover)
                                    : const Icon(Icons.medication_rounded, color: Colors.amberAccent, size: 28),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] as String,
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Price: KES ${item['price']} • Packaging: ${item['type']}',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: hasPhotos
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: hasPhotos
                                            ? Colors.greenAccent.withValues(alpha: 0.5)
                                            : Colors.orangeAccent.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hasPhotos ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                                          color: hasPhotos ? Colors.greenAccent : Colors.orangeAccent,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          hasPhotos ? '✓ Real Photos Attached (Local Device)' : '📷 Missing Photos: Tap to Capture',
                                          style: GoogleFonts.inter(
                                            color: hasPhotos ? Colors.greenAccent : Colors.orangeAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
