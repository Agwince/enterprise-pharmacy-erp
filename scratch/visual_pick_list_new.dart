import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/drug.dart';
import '../services/supabase_service.dart';

class VisualPickListScreen extends StatefulWidget {
  final List<String>? searchTerms;
  final List<String>? missingItems;
  final Map<String, double>? requiredQuantities;

  const VisualPickListScreen({
    super.key,
    this.searchTerms,
    this.missingItems,
    this.requiredQuantities,
  });

  @override
  State<VisualPickListScreen> createState() => _VisualPickListScreenState();
}

class _VisualPickListScreenState extends State<VisualPickListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pickListItems = [];

  @override
  void initState() {
    super.initState();
    _loadPickList();
  }

  Future<void> _loadPickList() async {
    setState(() => _isLoading = true);

    try {
      List<Drug> allDrugs = await _supabaseService.fetchDrugs();
      List<String> terms = widget.searchTerms ?? [];
      
      bool isNoMatch = false;
      if (terms.isNotEmpty && terms.first == '__NO_MATCH__') {
        isNoMatch = true;
      }

      final matchedDrugs = isNoMatch
          ? <Drug>[]
          : terms.isEmpty
              ? allDrugs
              : allDrugs.where((drug) {
                  final upperName = drug.name.toUpperCase();
                  return terms.contains(upperName);
                }).toList();

      final List<Map<String, dynamic>> items = matchedDrugs.map((drug) {
        final isFractional = drug.name.contains('0.10') || drug.name.contains('10ML') || drug.name.contains('SUSP');
        double pickQty = widget.requiredQuantities?[drug.name.toUpperCase()] ?? (isFractional ? 0.10 : 1.0);
        
        final String innerUnitType = (drug.toJson()['inner_unit_type'] as String?) ??
            (drug.name.toUpperCase().contains('SUSP') || drug.name.toUpperCase().contains('LIQ') || drug.name.toUpperCase().contains('SYRUP')
                ? 'Bottle'
                : 'Strip/Blister');

        return {
          'id': drug.id,
          'sku': drug.sku,
          'name': drug.name,
          'pick_quantity': pickQty,
          'inner_unit_type': innerUnitType,
          'unit_label': 'Pick: $pickQty ${isFractional ? '(Loose $innerUnitType)' : '(Full Sealed Box)'}',
          'location': drug.binLocation, // Removed emoji for clean UI
          'box_image_url': drug.imageUrl,
          'loose_unit_image_url': drug.innerUnitImageUrl,
          'checked': false,
          'quantity_picked': pickQty.toInt() > 0 ? pickQty.toInt() : 1,
          'quantity_in_stock': drug.quantityInStock,
          'min_threshold': drug.minThreshold,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _pickListItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pick list: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = _pickListItems.length;
    int pickedItems = _pickListItems.where((i) => i['checked'] == true).length;
    double progress = totalItems == 0 ? 0.0 : pickedItems / totalItems;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Active Pick Route',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(progress == 1.0 ? Colors.greenAccent : Colors.tealAccent),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : RefreshIndicator(
              onRefresh: _loadPickList,
              color: Colors.tealAccent,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSummaryHeader(totalItems, pickedItems),
                  const SizedBox(height: 16),
                  
                  if (widget.missingItems != null && widget.missingItems!.isNotEmpty)
                    _buildMissingItemsAlert(),

                  if (_pickListItems.isEmpty)
                    _buildEmptyState()
                  else
                    ..._pickListItems.map((item) => _buildPickListItem(item)),
                ],
              ),
            ),
      bottomNavigationBar: _pickListItems.isNotEmpty ? _buildBottomActions(progress == 1.0) : null,
    );
  }

  Widget _buildSummaryHeader(int total, int picked) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Picking Progress',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '$picked / $total Items',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: picked == total && total > 0 ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.tealAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              picked == total && total > 0 ? Icons.check_circle : Icons.inventory_2_rounded,
              color: picked == total && total > 0 ? Colors.greenAccent : Colors.tealAccent,
              size: 28,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMissingItemsAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Unrecognized OCR Text',
                style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.missingItems!.map((item) => Padding(
            padding: const EdgeInsets.only(left: 28.0, top: 4),
            child: Text('• $item', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_rounded, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'No medicines matched.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Try scanning again with better lighting.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPickListItem(Map<String, dynamic> item) {
    bool isChecked = item['checked'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isChecked ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isChecked ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isChecked ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            item['checked'] = !item['checked'];
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Thumbnail
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  image: item['box_image_url'] != null
                      ? DecorationImage(
                          image: NetworkImage(item['box_image_url']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: item['box_image_url'] == null
                    ? const Icon(Icons.medication, color: Colors.grey)
                    : null,
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
                        color: isChecked ? Colors.white54 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Shelf: ${item['location']}',
                            style: GoogleFonts.inter(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['unit_label'],
                          style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        // Quick Quantity Editor
                        if (!isChecked)
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (item['quantity_picked'] > 1) item['quantity_picked']--;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                                  child: const Icon(Icons.remove, size: 16, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${item['quantity_picked']}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    item['quantity_picked']++;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Checkbox
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isChecked ? Colors.greenAccent : Colors.transparent,
                  border: Border.all(color: isChecked ? Colors.greenAccent : Colors.grey[600]!, width: 2),
                  shape: BoxShape.circle,
                ),
                child: isChecked ? const Icon(Icons.check, size: 18, color: Colors.black) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(bool isComplete) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isComplete
                ? () {
                    // Logic to process dispatch
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order Picked & Sent for Dispatch!'), backgroundColor: Colors.green),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isComplete ? Colors.greenAccent : Colors.grey[800],
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              isComplete ? 'Confirm & Send to Dispatch' : 'Complete All Picks to Proceed',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: isComplete ? Colors.black : Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
