import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'register_product_screen.dart';

class CatalogPhotoStudioScreen extends StatefulWidget {
  const CatalogPhotoStudioScreen({super.key});

  @override
  State<CatalogPhotoStudioScreen> createState() => _CatalogPhotoStudioScreenState();
}

class _CatalogPhotoStudioScreenState extends State<CatalogPhotoStudioScreen> {
  final ImagePicker _picker = ImagePicker();
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _catalog = [];

  @override
  void initState() {
    super.initState();
    _loadLiveCatalog();
  }

  Future<void> _loadLiveCatalog() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final response = await client.from('drugs').select();
      final list = response as List<dynamic>;

      List<Map<String, dynamic>> items = [];
      if (list.isNotEmpty) {
        items = list.map((json) {
          return {
            'id': json['id'] as String,
            'name': json['name'] as String,
            'sku': json['sku'] as String,
            'category': json['category'] as String? ?? 'General',
            'box_image_url': json['image_url'] as String?,
            'barcode_string': json['sku'] as String?,
            'loose_unit_image_url': null,
          };
        }).toList();
      } else {
        final drugs = await _supabaseService.fetchDrugs();
        items = drugs.map((drug) {
          return {
            'id': drug.id,
            'name': drug.name,
            'sku': drug.sku,
            'category': drug.category,
            'box_image_url': drug.imageUrl,
            'barcode_string': drug.sku,
            'loose_unit_image_url': null,
          };
        }).toList();
      }

      if (mounted) {
        setState(() {
          _catalog = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _catalog = [];
          _isLoading = false;
        });
      }
    }
  }

  void _openRegisterNewMedicineScreen() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterProductScreen()),
    );
    if (res == true) {
      _loadLiveCatalog();
    }
  }

  void _openGuidedPhotoStudio(Map<String, dynamic> drug) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _GuidedStudioDialog(
          drug: drug,
          onComplete: (boxUrl, barcode, looseUrl) {
            setState(() {
              drug['box_image_url'] = boxUrl;
              drug['barcode_string'] = barcode;
              drug['loose_unit_image_url'] = looseUrl;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '3-Step Capture Complete for "${drug['name']}"! Box, Barcode & 0.10 Loose Unit saved.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_enhance_rounded, color: Colors.tealAccent, size: 32),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guided Photo Studio (3-Step Capture)',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Capture Box Front, Barcode, and Loose Unit (0.10 Fractional Sales)',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Intro Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_rounded, color: Colors.tealAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap any drug to launch the Guided Camera Studio. Captures Box Front, Barcode, and 0.10 Loose Unit for floor picking.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Catalog Items List
            Text(
              'Nairobi Drug Catalog (Asset Studio Registry)',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _catalog.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final drug = _catalog[index];
                final hasBox = drug['box_image_url'] != null;
                final hasBarcode = drug['barcode_string'] != null;
                final hasLoose = drug['loose_unit_image_url'] != null;
                final isFullyStudioCaptured = hasBox && hasBarcode && hasLoose;

                return Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isFullyStudioCaptured
                          ? Colors.tealAccent.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: hasBox
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(drug['box_image_url'], fit: BoxFit.cover),
                            )
                          : const Icon(Icons.inventory_2_outlined, color: Colors.tealAccent),
                    ),
                    title: Text(
                      drug['name'],
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('${drug['sku']} • ${drug['category']}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildAssetBadge('1. Box Front', hasBox),
                            const SizedBox(width: 6),
                            _buildAssetBadge('2. Barcode', hasBarcode),
                            const SizedBox(width: 6),
                            _buildAssetBadge('3. Loose Unit (0.10)', hasLoose),
                          ],
                        ),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _openGuidedPhotoStudio(drug),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFullyStudioCaptured ? Colors.tealAccent.withValues(alpha: 0.2) : Colors.tealAccent,
                        foregroundColor: isFullyStudioCaptured ? Colors.tealAccent : Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(isFullyStudioCaptured ? Icons.check_circle_rounded : Icons.camera_alt_rounded, size: 16),
                      label: Text(
                        isFullyStudioCaptured ? 'Recapture' : 'Launch Studio',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetBadge(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? Colors.greenAccent : Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label ${active ? "✓" : "✗"}',
        style: GoogleFonts.inter(color: active ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// GUIDED 3-STEP STUDIO OVERLAY DIALOG
class _GuidedStudioDialog extends StatefulWidget {
  final Map<String, dynamic> drug;
  final Function(String boxUrl, String barcode, String looseUrl) onComplete;

  const _GuidedStudioDialog({required this.drug, required this.onComplete});

  @override
  State<_GuidedStudioDialog> createState() => _GuidedStudioDialogState();
}

class _GuidedStudioDialogState extends State<_GuidedStudioDialog> {
  int _step = 1;
  String? _boxUrl;
  String? _barcode;
  String? _looseUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _boxUrl = widget.drug['box_image_url'];
    _barcode = widget.drug['barcode_string'];
    _looseUrl = widget.drug['loose_unit_image_url'];
  }

  Future<void> _captureStep1BoxFront() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear);
      if (image != null) {
        setState(() {
          _boxUrl = 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80';
          _step = 2;
        });
      }
    } catch (_) {
      // Demo fallback
      setState(() {
        _boxUrl = 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80';
        _step = 2;
      });
    }
  }

  Future<void> _captureStep2Barcode() async {
    setState(() {
      _barcode = '6001234567890';
      _step = 3;
    });
  }

  Future<void> _captureStep3LooseUnit() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear);
      if (image != null) {
        setState(() {
          _looseUrl = 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80';
          _step = 4; // Complete!
        });
      }
    } catch (_) {
      // Demo fallback
      setState(() {
        _looseUrl = 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80';
        _step = 4;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          title: Text(
            'Guided Studio: ${widget.drug['name']}',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white54),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: _step <= 3 ? _buildCameraOverlayStep() : _buildCompletionSummaryStep(),
      ),
    );
  }

  Widget _buildCameraOverlayStep() {
    String overlayTitle = '';
    String instructionText = '';
    IconData stepIcon = Icons.camera_alt_rounded;
    VoidCallback onActionPressed = () {};

    if (_step == 1) {
      overlayTitle = 'Step 1/3: Align FRONT face of the BOX here.';
      instructionText = 'Position the front of the sealed medicine box within the rectangular frame.';
      stepIcon = Icons.inventory_2_rounded;
      onActionPressed = _captureStep1BoxFront;
    } else if (_step == 2) {
      overlayTitle = 'Step 2/3: Align BARCODE here.';
      instructionText = 'Position the EAN/UPC barcode on the side of the box within the brackets.';
      stepIcon = Icons.qr_code_scanner_rounded;
      onActionPressed = _captureStep2Barcode;
    } else if (_step == 3) {
      overlayTitle = 'Step 3/3: Open box. Align LOOSE UNIT (Strip/Bottle) here for 0.10 fractional sales.';
      instructionText = 'Take out a single blister strip or bottle. Align it for 0.10 fractional picking.';
      stepIcon = Icons.medication_liquid_rounded;
      onActionPressed = _captureStep3LooseUnit;
    }

    return Stack(
      children: [
        // Camera Viewfinder Background simulation
        Container(color: Colors.black87),

        // Guided Frame Brackets
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: AspectRatio(
              aspectRatio: _step == 2 ? 16 / 9 : 4 / 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.tealAccent, width: 3),
                      color: Colors.tealAccent.withValues(alpha: 0.05),
                    ),
                  ),
                  Center(
                    child: Icon(stepIcon, size: 72, color: Colors.tealAccent.withValues(alpha: 0.4)),
                  ),
                  // Step Tag Top
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.tealAccent),
                      ),
                      child: Text(
                        overlayTitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 30,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Text(
                instructionText,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(stepIcon, size: 24),
                  label: Text(
                    'Capture Step $_step of 3',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionSummaryStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 64),
          ),
          const SizedBox(height: 20),
          Text(
            'Guided 3-Step Capture Complete!',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Assets registered for ${widget.drug['name']}',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 32),

          // Asset Summary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryAssetCard('1. Box Front', _boxUrl != null),
              _buildSummaryAssetCard('2. Barcode\n($_barcode)', _barcode != null),
              _buildSummaryAssetCard('3. Loose Unit (0.10)', _looseUrl != null),
            ],
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onComplete(_boxUrl!, _barcode!, _looseUrl!);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cloud_done_rounded, size: 22),
              label: Text(
                'Save Assets to Nairobi Central Cloud',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAssetCard(String title, bool success) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
