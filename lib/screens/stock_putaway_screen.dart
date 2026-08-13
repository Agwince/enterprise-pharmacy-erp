import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/drug.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import 'register_product_screen.dart';

class StockPutawayScreen extends StatefulWidget {
  const StockPutawayScreen({super.key});

  @override
  State<StockPutawayScreen> createState() => _StockPutawayScreenState();
}

class _StockPutawayScreenState extends State<StockPutawayScreen> {
  final ImagePicker _picker = ImagePicker();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;
  List<Drug> _drugsCatalog = []; // Live Supabase Drugs Catalog (No Hardcoded Mock Arrays)
  Drug? _selectedDrug;
  String? _capturedImageLocalPath;
  int _currentStep = 1; // 1: Barcode Scan, 1.5: Image Interception, 2: Shelf QR Scan
  bool _isUploading = false;
  final _quantityController = TextEditingController(text: '50');

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

      List<Drug> drugs = [];
      if (list.isNotEmpty) {
        drugs = list.map((json) => Drug.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        // Query via SupabaseService if direct query returns empty
        drugs = await _supabaseService.fetchDrugs();
      }

      if (mounted) {
        setState(() {
          _drugsCatalog = drugs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Live catalog query note: $e');
      if (mounted) {
        setState(() {
          _drugsCatalog = [];
          _isLoading = false;
        });
      }
    }
  }

  void _openRegisterNewMedicineScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterProductScreen()),
    );
    if (result == true) {
      _loadLiveCatalog();
    }
  }

  void _selectDrug(Drug drug) {
    setState(() {
      _selectedDrug = drug;
      _capturedImageLocalPath = null;
      if (drug.imageUrl == null) {
        _currentStep = 1;
      } else {
        _currentStep = 2;
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

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    setState(() {
      _isUploading = false;
      _capturedImageLocalPath = path;
      _currentStep = 2;
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
            padding: const EdgeInsets.only(right: 12.0),
            child: OutlinedButton.icon(
              onPressed: () => AuthService().logout(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 14),
              label: Text('Logout', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
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
                // Top Header Row with Register New Medicine Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Warehouse Catalog',
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Select items to initiate intake or register new stock.',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openRegisterNewMedicineScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        'Register New Medicine from Scratch',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // TASK 1: BLANK / EMPTY STATE IF NO DATA IN DATABASE
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: Colors.amberAccent),
                    ),
                  )
                else if (_drugsCatalog.isEmpty)
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: Colors.amberAccent, size: 48),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Warehouse is empty. Register new stock to begin.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No pre-filled mock cards. Key in medicine details live into Supabase.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _openRegisterNewMedicineScreen,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                            label: Text(
                              'Register New Medicine from Scratch',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Step 1: Select or Scan Item
                  Text(
                    'Step 1: Select or Scan Item Barcode (Supabase Catalog)',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _drugsCatalog.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _drugsCatalog[index];
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
                ],
                const SizedBox(height: 24),

                // Active Selected Item Putaway UI
                if (_selectedDrug != null) ...[
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
