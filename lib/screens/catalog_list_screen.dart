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
    await prefs.reload(); // Force reload from disk/memory
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

  String _normalizeName(String raw) {
    return raw
        .toUpperCase()
        .replaceAll("'", "")
        .replaceAll("S", "")
        .replaceAll(" ", "")
        .replaceAll("-", "")
        .replaceAll(".", "");
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
    // Task 1: Force complete state reload and UI rebuild whenever returning
    _loadLocalCatalog();
  }

  void _openBlankForm(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterProductScreen(),
      ),
    );
    // Task 1: Force complete state reload and UI rebuild whenever returning
    _loadLocalCatalog();
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

            // Merged catalog list (Seeded + Registered Local Items with Name-matching)
            RefreshIndicator(
              onRefresh: _loadLocalCatalog,
              color: Colors.tealAccent,
              child: Builder(builder: (context) {
                final allItems = <Map<String, dynamic>>[];

                // Build merged list prioritizing matching local entries
                for (var seeded in _catalogItems) {
                  final seededNorm = _normalizeName(seeded['name'] as String);
                  final localMatch = _localRegisteredItems.firstWhere(
                    (loc) => _normalizeName(loc['name'] as String).contains(seededNorm) || seededNorm.contains(_normalizeName(loc['name'] as String)),
                    orElse: () => <String, dynamic>{},
                  );

                  if (localMatch.isNotEmpty) {
                    allItems.add({
                      'name': seeded['name'],
                      'price': seeded['price'],
                      'type': seeded['type'],
                      'box_image_url': localMatch['image_url'],
                      'loose_image_url': localMatch['inner_unit_image_url'],
                      'has_photos': (localMatch['image_url'] != null && (localMatch['image_url'] as String).isNotEmpty) ||
                          (localMatch['inner_unit_image_url'] != null && (localMatch['inner_unit_image_url'] as String).isNotEmpty),
                    });
                  } else {
                    allItems.add({
                      'name': seeded['name'],
                      'price': seeded['price'],
                      'type': seeded['type'],
                      'box_image_url': null,
                      'loose_image_url': null,
                      'has_photos': false,
                    });
                  }
                }

                // Append any newly registered unlisted local items that aren't in seeded list
                for (var local in _localRegisteredItems) {
                  final localNorm = _normalizeName(local['name'] as String);
                  final isSeeded = _catalogItems.any((s) {
                    final sNorm = _normalizeName(s['name'] as String);
                    return sNorm.contains(localNorm) || localNorm.contains(sNorm);
                  });
                  if (!isSeeded) {
                    allItems.add({
                      'name': local['name'],
                      'price': local['unit_price']?.toString() ?? local['price']?.toString() ?? '0.00',
                      'type': local['inner_unit_type'] ?? 'Strip/Blister',
                      'box_image_url': local['image_url'],
                      'loose_image_url': local['inner_unit_image_url'],
                      'has_photos': (local['image_url'] != null && (local['image_url'] as String).isNotEmpty) ||
                          (local['inner_unit_image_url'] != null && (local['inner_unit_image_url'] as String).isNotEmpty),
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
                    final bool hasPhotos = item['has_photos'] == true;
                    final String? boxBase64 = item['box_image_url'] as String?;

                    Uint8List? decodedBytes;
                    if (hasPhotos && boxBase64 != null && boxBase64.isNotEmpty) {
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
                              ? Colors.greenAccent.withValues(alpha: 0.6)
                              : Colors.orangeAccent.withValues(alpha: 0.4),
                          width: hasPhotos ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openAttachPhotoForm(context, item),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Task 2: Thumbnail Rendering
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: hasPhotos ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.white10,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: decodedBytes != null
                                      ? Image.memory(decodedBytes, fit: BoxFit.cover)
                                      : const Center(
                                          child: Icon(Icons.camera_alt, color: Colors.white54, size: 24),
                                        ),
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
                                    // Task 2: Subtitle update for captured vs missing
                                    Text(
                                      hasPhotos
                                          ? 'Photos Attached: Ready for Putaway'
                                          : 'Price: KES ${item['price']} • Packaging: ${item['type']}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: hasPhotos ? Colors.tealAccent : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Task 2: Action / Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                            hasPhotos ? '✅ Photo Captured' : '📷 Missing Photos: Tap to Capture',
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
                              Icon(
                                hasPhotos ? Icons.check_circle_outline_rounded : Icons.chevron_right_rounded,
                                color: hasPhotos ? Colors.greenAccent : Colors.white38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
