import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  int _page = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;
  Timer? _debounceTimer;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCatalog(page: 0);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchCatalog(page: 0, search: query);
    });
  }

  Future<void> _fetchCatalog({int page = 0, String? search}) async {
    if (page == 0) setState(() => _isLoading = true);

    try {
      final queryText = (search ?? _searchCtrl.text).trim();
      var query = Supabase.instance.client
          .from('drugs')
          .select('id, name, generic_name, barcode, target_shelf, price, quantity_in_stock, shelf_quantity, warehouse_quantity, category');

      if (queryText.isNotEmpty) {
        query = query.or('name.ilike.%$queryText%,barcode.ilike.%$queryText%,category.ilike.%$queryText%');
      }

      final offset = page * _pageSize;
      final res = await query
          .order('name')
          .range(offset, offset + _pageSize - 1);

      final list = (res as List).map((d) {
        final name = (d['name'] ?? '') as String;
        final totalQty = (d['quantity_in_stock'] as num?)?.toInt() ?? ((d['warehouse_quantity'] as num?)?.toInt() ?? 0);
        final pallets = (totalQty / 10).ceil();
        final boxes = totalQty;
        final category = (d['category'] ?? '').toString();

        return {
          'id': d['id'],
          'name': name,
          'genericName': d['generic_name'] ?? '',
          'sku': d['barcode'] ?? '',
          'category': category,
          'binLocation': d['target_shelf'] ?? '',
          'pallets': pallets,
          'boxesAvailable': '$boxes Units',
          'warehouseQty': totalQty,
          'price': (d['price'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          if (page == 0) {
            _wholesaleItems = list;
          } else {
            _wholesaleItems.addAll(list);
          }
          _page = page;
          _hasMore = list.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Wholesale catalog query note: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showItemDetail(Map<String, dynamic> item) async {
    String? fullImageUrl;
    bool loadingImage = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loadingImage) {
            // Lazy load high-res image ONLY on demand in modal
            Supabase.instance.client
                .from('drugs')
                .select('box_image_url, image_url')
                .eq('id', item['id'])
                .maybeSingle()
                .then((row) {
              if (ctx.mounted) {
                setDialogState(() {
                  fullImageUrl = (row?['box_image_url'] ?? row?['image_url'])?.toString();
                  loadingImage = false;
                });
              }
            }).catchError((_) {
              if (ctx.mounted) setDialogState(() => loadingImage = false);
            });
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(item['name'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: loadingImage
                        ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                        : fullImageUrl != null && fullImageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  fullImageUrl!,
                                  cacheWidth: 400,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.medication_rounded, size: 50, color: Colors.cyanAccent),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.inventory_2_rounded, size: 50, color: Colors.cyanAccent),
                              ),
                  ),
                  const SizedBox(height: 16),
                  Text('Generic Name: ${item['genericName']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('SKU / Barcode: ${item['sku']}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('Bin / Shelf: ${item['binLocation']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('Category: ${item['category']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('Bulk Warehouse Units: ${item['warehouseQty']} (${item['pallets']} Pallets)', style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.white54))),
            ],
          );
        },
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
                  'Warehouse Operations • High Efficiency Paginated View',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
            onPressed: () => _fetchCatalog(page: 0),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Search & Metrics Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search wholesale catalog by name, generic, barcode (300ms debounce)...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 20),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_wholesaleItems.length} Loaded Lines (Page ${_page + 1}) • Lightweight Tile Rendering',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Text('Egress Optimized < 2MB', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Wholesale Inventory Grid with Placeholders
            if (_isLoading)
              _buildSkeletonGrid()
            else if (_wholesaleItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                child: const Text('No medicines found matching query.', style: TextStyle(color: Colors.white54)),
              )
            else
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
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 220,
                    ),
                    itemCount: _wholesaleItems.length,
                    itemBuilder: (context, index) {
                      final item = _wholesaleItems[index];
                      final name = (item['name'] ?? 'Medicine').toString();
                      final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : 'RX';

                      return InkWell(
                        onTap: () => _showItemDetail(item),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.cyan.withValues(alpha: 0.3), Colors.blue.withValues(alpha: 0.15)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['genericName'],
                                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Shelf: ${item['binLocation']}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                    Text('${item['pallets']} Pallets', style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['sku'],
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${item['boxesAvailable']}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

            // Pagination Controls
            if (_hasMore && !_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: ElevatedButton.icon(
                    onPressed: () => _fetchCatalog(page: _page + 1),
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: const Text('Load Next 50 Items'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 200,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 12),
            Container(width: 140, height: 14, color: Colors.white10),
            const SizedBox(height: 8),
            Container(width: 90, height: 10, color: Colors.white10),
          ],
        ),
      ),
    );
  }
}
