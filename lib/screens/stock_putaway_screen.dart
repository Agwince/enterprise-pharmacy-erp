import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/drug.dart';
import '../services/auth_service.dart';

class StockPutawayScreen extends StatefulWidget {
  const StockPutawayScreen({super.key});

  @override
  State<StockPutawayScreen> createState() => _StockPutawayScreenState();
}

class _StockPutawayScreenState extends State<StockPutawayScreen> {
  final ImagePicker _picker = ImagePicker();

  // Nairobi Catalog Sample Seed Data
  final List<Drug> _nairobiCatalog = [
    Drug(
      id: 'nrb-001',
      sku: 'NRB-ABZ-10ML',
      name: 'ABZ SUSPENSION 10ML',
      genericName: 'Albendazole 400mg/10ml',
      category: 'Anthelmintic',
      unit: 'Bottle 10ml',
      binLocation: 'AISLE 1 - SHELF B2',
      unitPrice: 120.00,
      costPrice: 75.00,
      minThreshold: 20,
      maxThreshold: 200,
      imageUrl: null, // Relies on placeholder!
      createdAt: DateTime.now(),
    ),
    Drug(
      id: 'nrb-002',
      sku: 'NRB-PAN-100S',
      name: 'PANADOL EXTRA 100\'S',
      genericName: 'Paracetamol + Caffeine',
      category: 'Analgesics',
      unit: 'Box of 100',
      binLocation: 'AISLE 1 - SHELF A1',
      unitPrice: 850.00,
      costPrice: 520.00,
      minThreshold: 50,
      maxThreshold: 500,
      imageUrl: null, // Relies on placeholder!
      createdAt: DateTime.now(),
    ),
    Drug(
      id: 'nrb-003',
      sku: 'NRB-AMX-100S',
      name: 'AMOXICILLIN 500MG 100\'S',
      genericName: 'Amoxicillin Trihydrate',
      category: 'Antibiotics',
      unit: 'Box of 100',
      binLocation: 'AISLE 2 - SHELF A3',
      unitPrice: 1450.00,
      costPrice: 900.00,
      minThreshold: 30,
      maxThreshold: 300,
      imageUrl: null, // Relies on placeholder!
      createdAt: DateTime.now(),
    ),
    Drug(
      id: 'nrb-004',
      sku: 'NRB-FLU-60ML',
      name: 'FLUGONE EXP 60MLS',
      genericName: 'Expectorant Cough Formula',
      category: 'Cough & Cold',
      unit: 'Bottle 60ml',
      binLocation: 'AISLE 3 - SHELF C1',
      unitPrice: 380.00,
      costPrice: 210.00,
      minThreshold: 25,
      maxThreshold: 250,
      imageUrl: null, // Relies on placeholder!
      createdAt: DateTime.now(),
    ),
    Drug(
      id: 'nrb-005',
      sku: 'NRB-INS-100U',
      name: 'INSULIN GLARGINE 100U/ML',
      genericName: 'Insulin Glargine',
      category: 'Cold Storage',
      unit: 'Vial 10ml',
      binLocation: 'REFRIGERATOR - BAY 1',
      unitPrice: 3200.00,
      costPrice: 2100.00,
      minThreshold: 10,
      maxThreshold: 50,
      imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
      createdAt: DateTime.now(),
    ),
  ];

  Drug? _selectedDrug;
  String? _capturedImageLocalPath;
  int _currentStep = 1; // 1: Barcode Scan, 1.5: Image Interception, 2: Shelf QR Scan
  bool _isUploading = false;
  final _quantityController = TextEditingController(text: '50');

  void _selectDrug(Drug drug) {
    setState(() {
      _selectedDrug = drug;
      _capturedImageLocalPath = null;
      
      // First-Touch Interception Check
      if (drug.imageUrl == null) {
        _currentStep = 1; // Needs First-Touch Photo Interception
      } else {
        _currentStep = 2; // Directly to Step 2 Shelf Scan
      }
    });
  }

  Future<void> _captureFirstTouchPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (photo != null) {
        _processPhotoUpload(photo.path);
      }
    } catch (e) {
      // Fallback to gallery pick if camera fails or is un-supported in web browser
      try {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (photo != null) {
          _processPhotoUpload(photo.path);
        }
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e2', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _processPhotoUpload(String path) async {
    setState(() {
      _isUploading = true;
    });

    // Simulate 1.5s cloud upload
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    setState(() {
      _isUploading = false;
      _capturedImageLocalPath = path;
      _currentStep = 2; // Immediately resume to Step 2: Scan Shelf QR
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Photo uploaded! Resuming Step 2: Scan Shelf QR.',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _completePutaway() {
    if (_selectedDrug == null) return;

    final qty = _quantityController.text.trim();
    final drugName = _selectedDrug!.name;

    setState(() {
      _selectedDrug = null;
      _capturedImageLocalPath = null;
      _currentStep = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✅ Stock Intake & Putaway Completed!',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '$qty units of $drugName assigned & synced to Nairobi Central cloud.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
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
                color: Colors.amberAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.amberAccent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock Intake & Dual-Scan Putaway',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Storekeeper Workspace • Nairobi Central Branch',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600),
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
              label: Text('Logout', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'First-Touch Visual Intake Protocol',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Items lacking real photos trigger an automatic capture request during stock putaway.',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Step 1: Select / Scan Item from Nairobi Catalog
                Text(
                  'Step 1: Select or Scan Item Barcode (Nairobi Catalog)',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _nairobiCatalog.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = _nairobiCatalog[index];
                      final isSelected = _selectedDrug?.id == item.id;
                      final hasRealImage = item.imageUrl != null || (_selectedDrug?.id == item.id && _capturedImageLocalPath != null);

                      return GestureDetector(
                        onTap: () => _selectDrug(item),
                        child: Container(
                          width: 240,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? Colors.amberAccent : Colors.white.withValues(alpha: 0.1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  color: const Color(0xFF0F172A),
                                  child: Image.network(
                                    item.displayImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.medication_rounded, color: Colors.amberAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.sku,
                                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: hasRealImage
                                            ? Colors.green.withValues(alpha: 0.2)
                                            : Colors.orange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        hasRealImage ? '✓ Real Photo' : '⚠️ Needs Photo',
                                        style: GoogleFonts.inter(
                                          color: hasRealImage ? Colors.greenAccent : Colors.orangeAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Active Item Selected Section
                if (_selectedDrug != null) ...[
                  // Card representing selected item state
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF0F172A),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _selectedDrug!.displayImageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDrug!.name,
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_selectedDrug!.sku} • ${_selectedDrug!.category} • Unit: ${_selectedDrug!.unit}',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bin Target: ${_selectedDrug!.binLocation}',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // FIRST-TOUCH INTERCEPTION WARNING CARD
                        if (_selectedDrug!.imageUrl == null && _capturedImageLocalPath == null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orangeAccent, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'New Packaging Detected: Please snap a live photo of the box.',
                                        style: GoogleFonts.inter(
                                          color: Colors.orangeAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This SKU currently uses a generic category placeholder. Capture a real picture to update the Nairobi Central catalog.',
                                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: _captureFirstTouchPhoto,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amberAccent,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.camera_alt_rounded, size: 22),
                                    label: Text(
                                      'Capture Image (First-Touch Intake)',
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // STEP 2: SCAN SHELF QR & COMPLETE PUTAWAY
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.greenAccent, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Step 2: Scan Shelf QR Code',
                                      style: GoogleFonts.inter(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _quantityController,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.inter(color: Colors.white),
                                        decoration: InputDecoration(
                                          labelText: 'Putaway Quantity',
                                          labelStyle: GoogleFonts.inter(color: Colors.white70),
                                          filled: true,
                                          fillColor: const Color(0xFF0F172A),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: _completePutaway,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.greenAccent,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.qr_code_2_rounded),
                                      label: Text(
                                        'Confirm Putaway',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Uploading cloud overlay simulation
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Uploading to Secure Cloud...',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Updating Nairobi Central Catalog with Real Packaging Image',
                      style: GoogleFonts.inter(color: Colors.amberAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
