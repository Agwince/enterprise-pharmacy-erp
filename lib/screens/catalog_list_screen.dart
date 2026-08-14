import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  List<String> completedNames = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchCompletedItems();
  }

  Future<void> fetchCompletedItems() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('drugs').select('name');
      final list = response as List<dynamic>;

      List<String> names = [];
      for (var json in list) {
        if (json['name'] != null) {
          names.add(_normalizeName(json['name'] as String));
        }
      }

      if (mounted) {
        setState(() {
          completedNames = names;
        });
      }
    } on StorageException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Storage Error'),
          content: const Text("Cloud Storage Blocked. Ensure your 'medicine_images' bucket exists in Supabase and is set to PUBLIC."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('ClientException') || e.toString().contains('StorageException')) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Error'),
            content: const Text("Cloud Storage Blocked. Ensure your 'medicine_images' bucket exists in Supabase and is set to PUBLIC."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        debugPrint('Error fetching completed items from Supabase: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          prefilledUnit: item['type'] as String?,
        ),
      ),
    );
    if (result == true) {
      fetchCompletedItems();
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
      fetchCompletedItems();
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

            // Filter out items that exist in Supabase drugs table (Task 2: Dynamic List Filtering)
            RefreshIndicator(
              onRefresh: fetchCompletedItems,
              color: Colors.tealAccent,
              child: Builder(builder: (context) {
                // Filter out items whose normalized name exists in Supabase
                final missingItems = _catalogItems.where((item) {
                  final itemNorm = _normalizeName(item['name'] as String);
                  return !completedNames.any((reg) => reg.contains(itemNorm) || itemNorm.contains(reg));
                }).toList();

                if (missingItems.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          '🎉 All Catalog Photos Captured!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All seeded Nairobi catalog items have photos registered in Supabase.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: missingItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = missingItems[index];

                    return Card(
                      color: const Color(0xFF1E293B),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.4)),
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
                                child: const Center(
                                  child: Icon(Icons.camera_alt, color: Colors.white54, size: 24),
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
                                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.camera_alt_outlined, color: Colors.orangeAccent, size: 13),
                                          const SizedBox(width: 6),
                                          Text(
                                            '📷 Missing Photos: Tap to Capture',
                                            style: GoogleFonts.inter(
                                              color: Colors.orangeAccent,
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
            ),
          ],
        ),
      ),
    );
  }
}
