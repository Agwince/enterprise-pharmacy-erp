import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'register_product_screen.dart';

enum IntakeMode { fullBox, looseUnit, both }

class CatalogListScreen extends StatefulWidget {
  final IntakeMode mode;

  const CatalogListScreen({super.key, this.mode = IntakeMode.both});

  @override
  State<CatalogListScreen> createState() => _CatalogListScreenState();
}

class _CatalogListScreenState extends State<CatalogListScreen> {
  List<Map<String, dynamic>> _allDrugs = [];
  List<Map<String, dynamic>> _missingPhotoDrugs = [];
  List<Map<String, dynamic>> _completedDrugs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDrugs();
  }

  Future<void> _loadDrugs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('drugs')
          .select('id, name, price, inner_unit_type, box_image_url, image_url')
          .order('name', ascending: true);
      final list = (response as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final missing = <Map<String, dynamic>>[];
      final completed = <Map<String, dynamic>>[];

      for (final drug in list) {
        bool hasImage = false;
        
        if (widget.mode == IntakeMode.fullBox) {
          hasImage = drug['box_image_url'] != null && (drug['box_image_url'] as String).isNotEmpty;
        } else if (widget.mode == IntakeMode.looseUnit) {
          hasImage = drug['image_url'] != null && (drug['image_url'] as String).isNotEmpty;
        } else {
          hasImage = (drug['box_image_url'] != null && (drug['box_image_url'] as String).isNotEmpty) ||
                     (drug['image_url'] != null && (drug['image_url'] as String).isNotEmpty);
        }

        if (hasImage) {
          completed.add(drug);
        } else {
          missing.add(drug);
        }
      }

      if (mounted) {
        setState(() {
          _allDrugs = list;
          _missingPhotoDrugs = missing;
          _completedDrugs = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load medicines: $e';
        });
      }
    }
  }

  void _openAttachPhotoForm(BuildContext context, Map<String, dynamic> drug) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterProductScreen(
          prefilledName: drug['name'] as String,
          prefilledPrice: double.tryParse(drug['price']?.toString() ?? '0.0'),
          prefilledUnit: drug['inner_unit_type'] as String?,
        ),
      ),
    );
    if (result == true) {
      _loadDrugs();
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
      _loadDrugs();
    }
  }

  List<Map<String, dynamic>> _getFilteredMissing() {
    if (_searchQuery.isEmpty) return _missingPhotoDrugs;
    final q = _searchQuery.toUpperCase();
    return _missingPhotoDrugs
        .where((d) => (d['name'] as String).toUpperCase().contains(q))
        .toList();
  }

  List<Map<String, dynamic>> _getFilteredCompleted() {
    if (_searchQuery.isEmpty) return _completedDrugs;
    final q = _searchQuery.toUpperCase();
    return _completedDrugs
        .where((d) => (d['name'] as String).toUpperCase().contains(q))
        .toList();
  }

  void _showEditDrugDialog(Map<String, dynamic> drug) {
    final priceController = TextEditingController(text: drug['price']?.toString() ?? '');
    final nameController = TextEditingController(text: drug['name'] as String);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Medicine', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Medicine Name', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Text('Price (KES)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: priceController,
                style: GoogleFonts.inter(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final newPrice = double.tryParse(priceController.text) ?? 0.0;
                  await Supabase.instance.client
                      .from('drugs')
                      .update({'name': nameController.text, 'price': newPrice})
                      .eq('id', drug['id']);
                  if (mounted) Navigator.pop(context);
                  _loadDrugs();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.save_rounded, size: 16),
              label: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDrugDialog(Map<String, dynamic> drug) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text('Delete Medicine?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to permanently delete ${drug['name']}?', style: GoogleFonts.inter(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('drugs')
                      .delete()
                      .eq('id', drug['id']);
                  if (mounted) Navigator.pop(context);
                  _loadDrugs();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMissing = _getFilteredMissing();
    final filteredCompleted = _getFilteredCompleted();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBlankForm(context),
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('Register New Medicine from Scratch', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(_errorMessage, style: GoogleFonts.inter(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDrugs,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDrugs,
                  color: Colors.tealAccent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Header
                        Container(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.mode == IntakeMode.fullBox 
                                    ? 'Store Intake (Full Boxes)' 
                                    : widget.mode == IntakeMode.looseUnit 
                                        ? 'Pharmacy Intake (Loose Units)' 
                                        : 'Nairobi August 2026 Price List Catalog',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.mode == IntakeMode.fullBox 
                                    ? 'Tap items to attach photos of FULL BOXES for the warehouse.'
                                    : widget.mode == IntakeMode.looseUnit
                                        ? 'Tap items to attach photos of LOOSE UNITS for the pharmacy shelves.'
                                        : 'Tap unphotographed items to attach pictures or register new stock.',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        // Stats banner
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
                                      '${_allDrugs.length} Medicines in Catalog',
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_completedDrugs.length} with photos  •  ${_missingPhotoDrugs.length} need photos',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Search bar
                        TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: GoogleFonts.inter(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search medicines...',
                            hintStyle: GoogleFonts.inter(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search, color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section header
                        Text(
                          'Step 1: Select Item from Official Nairobi Catalog',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),

                        // Missing photos list - HORIZONTAL scrolling cards
                        if (filteredMissing.isEmpty && _missingPhotoDrugs.isEmpty)
                          Container(
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
                                  'All medicines have photos registered.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: filteredMissing.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final drug = filteredMissing[index];
                                final name = drug['name'] as String;
                                final price = drug['price']?.toString() ?? '0';

                                return SizedBox(
                                  width: 200,
                                  child: Card(
                                    color: const Color(0xFF1E293B),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _openAttachPhotoForm(context, drug),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F172A),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.camera_alt, color: Colors.white54, size: 20),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'KES $price',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.greenAccent,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const Spacer(),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 16),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _showEditDrugDialog(drug),
                                                ),
                                                const SizedBox(width: 12),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 16),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _showDeleteDrugDialog(drug),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.camera_alt_outlined, color: Colors.orangeAccent, size: 11),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Missing Photos',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.orangeAccent,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 32),

                        // Completed items section header
                        Text(
                          'Step 2: Completed Catalog Items',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),

                        // Completed items list
                        if (filteredCompleted.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'No completed items yet.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredCompleted.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final drug = filteredCompleted[index];
                              final name = drug['name'] as String;
                              final price = drug['price']?.toString() ?? '0';
                              final imageUrl = drug['box_image_url'] as String?;

                              return Card(
                                color: const Color(0xFF1E293B),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.2)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(8),
                                          image: imageUrl != null && imageUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(imageUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: imageUrl == null || imageUrl.isEmpty
                                            ? const Icon(Icons.medication, color: Colors.white38)
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'KES $price',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 20),
                                            onPressed: () => _showEditDrugDialog(drug),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                                            onPressed: () => _showDeleteDrugDialog(drug),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 80), // extra padding at bottom
                      ],
                    ),
                  ),
                ),
    );
  }
}
