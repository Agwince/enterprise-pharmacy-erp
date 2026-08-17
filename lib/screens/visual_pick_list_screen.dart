import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/drug.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import 'invoice_scanner_screen.dart';

class VisualPickListScreen extends StatefulWidget {
  final List<String>? searchTerms;

  const VisualPickListScreen({
    super.key,
    this.searchTerms = const [],
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
    _loadPickListFromSupabase();
  }

  Future<void> _loadPickListFromSupabase() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch from Supabase
      List<Drug> allDrugs = await _supabaseService.fetchDrugs();

      // Filter drugs based on OCR Search Terms if provided
      List<String> terms = widget.searchTerms ?? [];
      
      // Ensure terms are valid
      if (terms.isEmpty) {
        // We will just show an empty list instead of faking data
        terms = [];
      }

      final matchedDrugs = terms.isEmpty
          ? allDrugs
          : allDrugs.where((drug) {
              final upperName = drug.name.toUpperCase();
              return terms.any((term) => upperName.contains(term.toUpperCase()));
            }).toList();

      final List<Map<String, dynamic>> items = matchedDrugs.map((drug) {
        final isFractional = drug.name.contains('0.10') || drug.name.contains('10ML') || drug.name.contains('SUSP');
        final double pickQty = isFractional ? 0.10 : 1.0;
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
          'unit_label': isFractional
              ? 'Pick: 0.10 (1 Loose $innerUnitType)'
              : 'Pick: 1.0 (Full Sealed Box)',
          'location': '📍 ${drug.binLocation}',
          'box_image_url': drug.imageUrl,
          'loose_unit_image_url': drug.innerUnitImageUrl,
          'checked': false,
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
        setState(() {
          _pickListItems = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const InvoiceScannerScreen()),
            );
          },
        ),
        // Task 1: Clean AppBar without text overflow on mobile screens
        title: Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.task_alt_rounded, color: Colors.greenAccent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Visual Pick List',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Live Supabase OCR Search',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: OutlinedButton.icon(
              onPressed: () => AuthService().logout(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: const Icon(Icons.logout_rounded, size: 14),
              label: Text('Logout', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.greenAccent),
                    SizedBox(height: 16),
                    Text(
                      'Executing Supabase .ilike() Query...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : _pickListItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.search_off_rounded, color: Colors.white38, size: 48),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No matching items found in the database for this invoice.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadPickListFromSupabase,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text('Retry Query', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _pickListItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = _pickListItems[index];
                      final double qty = (item['pick_quantity'] as num).toDouble();
                      final bool isFractional = qty < 1.0;
                      final String imageUrl = isFractional ? item['loose_unit_image_url'] : item['box_image_url'];

                      // Task 1: Clean SaaS Card Aesthetics
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item['checked']
                                ? Colors.greenAccent.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Task 2: Dynamic Pastel Alert Banners using Inner Unit Type
                              if (isFractional)
                                Builder(
                                  builder: (context) {
                                    final unitType = (item['inner_unit_type'] as String? ?? 'Strip').toUpperCase();
                                    final displayUnit = unitType.contains('BOTTLE')
                                        ? 'BOTTLE'
                                        : (unitType.contains('TUBE')
                                            ? 'TUBE'
                                            : (unitType.contains('VIAL')
                                                ? 'VIAL'
                                                : (unitType.contains('PIECE') ? 'UNIT' : 'STRIP')));

                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '⚠️ OPEN BOX: PICK LOOSE $displayUnit (0.10 FRACTIONAL)',
                                              style: GoogleFonts.inter(
                                                color: Colors.amberAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'FULL SEALED BOX (1.0 WHOLE UNIT)',
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
                                  // Clean Image Box
                                  Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: const Color(0xFF0F172A),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Builder(builder: (context) {
                                            if (imageUrl == null || imageUrl.isEmpty) {
                                              return Container(
                                                color: Colors.grey[800],
                                                child: const Center(
                                                  child: Icon(Icons.camera_alt, size: 36, color: Colors.white54),
                                                ),
                                              );
                                            }

                                            // Check if imageUrl is a Base64 string
                                            if (!imageUrl.startsWith('http')) {
                                              try {
                                                final bytes = base64Decode(imageUrl);
                                                return Image.memory(bytes, fit: BoxFit.cover);
                                              } catch (_) {}
                                            }

                                            return CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: const Color(0xFF0F172A),
                                                child: const Center(child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2)),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: Colors.grey[800],
                                                child: const Icon(Icons.camera_alt, size: 36, color: Colors.white54),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isFractional ? 'LOOSE' : 'BOX',
                                            style: GoogleFonts.inter(
                                              color: isFractional ? Colors.amberAccent : Colors.tealAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(width: 14),

                                  // Crisp Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: GoogleFonts.inter(
                                            color: item['checked'] ? Colors.white54 : Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: item['checked'] ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['unit_label'],
                                          style: GoogleFonts.inter(
                                            color: isFractional ? Colors.amberAccent : Colors.tealAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                          ),
                                          child: Text(
                                            item['location'],
                                            style: GoogleFonts.inter(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Interactive Checkbox
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        item['checked'] = !item['checked'];
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: item['checked'] ? Colors.greenAccent : Colors.transparent,
                                          border: Border.all(
                                            color: item['checked'] ? Colors.greenAccent : Colors.white54,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: item['checked']
                                            ? const Icon(Icons.check_rounded, color: Colors.black, size: 24)
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
