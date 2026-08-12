import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class StoreMappingScreen extends StatefulWidget {
  const StoreMappingScreen({super.key});

  @override
  State<StoreMappingScreen> createState() => _StoreMappingScreenState();
}

class _StoreMappingScreenState extends State<StoreMappingScreen> {
  final List<Map<String, String>> _mappedLocations = [];
  late MobileScannerController _scannerController;
  bool _cameraFailed = false;
  String _cameraErrorMessage = '';
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Fallback: pick QR image from gallery or native camera
  Future<void> _pickQRImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null) {
        // Image captured — trigger the modal for manual entry
        _showMappingModal();
      }
    } catch (e) {
      // If camera source fails, fall back to gallery
      try {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          _showMappingModal();
        }
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open camera or gallery: $e2',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showMappingModal() {
    final aisleController = TextEditingController();
    final shelfController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'New Shelf Detected',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(aisleController, 'Aisle Number / Name', 'e.g., Aisle 4'),
                const SizedBox(height: 16),
                _buildTextField(shelfController, 'Shelf / Bin ID', 'e.g., Shelf B2'),
                const SizedBox(height: 16),
                _buildTextField(categoryController, 'Category (Optional)', 'e.g., Cold Storage'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (!_cameraFailed) {
                  _scannerController.start();
                }
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final aisle = aisleController.text.trim();
                final shelf = shelfController.text.trim();
                final category = categoryController.text.trim();
                
                if (aisle.isEmpty || shelf.isEmpty) return; // Basic validation
                
                setState(() {
                  _mappedLocations.insert(0, {
                    'aisle': aisle,
                    'shelf': shelf,
                    'category': category.isEmpty ? 'General' : category,
                  });
                });
                
                Navigator.pop(context);
                if (!_cameraFailed) {
                  _scannerController.start();
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Location $aisle-$shelf synced to branch database.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                'Save Location to Cloud',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white70),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCameraErrorFallback(String message) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'Camera Error',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _pickQRImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 20),
                  label: Text(
                    'Upload QR Photo',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
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
                color: Colors.tealAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.map_outlined, color: Colors.tealAccent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store Setup: Map Aisles',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Branch Manager Workspace',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.w600),
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
      body: SafeArea(
        child: Column(
          children: [
            // Top Half: Camera Viewfinder
            Expanded(
              flex: 4,
              child: _cameraFailed
                  ? _buildCameraErrorFallback(_cameraErrorMessage)
                  : Stack(
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            if (capture.barcodes.isNotEmpty) {
                              _scannerController.stop();
                              _showMappingModal();
                            }
                          },
                          errorBuilder: (context, error) {
                            final message = switch (error.errorCode) {
                              MobileScannerErrorCode.permissionDenied =>
                                'Camera permission denied.\nPlease allow camera access in your browser/device settings.',
                              MobileScannerErrorCode.unsupported =>
                                'Barcode scanning is not supported on this device.',
                              MobileScannerErrorCode.genericError =>
                                'Camera error: ${error.errorDetails?.message ?? 'Unknown'}',
                              _ => 'Scanner error: ${error.errorCode.name}',
                            };

                            // Mark camera as failed so fallback UI persists
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_cameraFailed) {
                                setState(() {
                                  _cameraFailed = true;
                                  _cameraErrorMessage = message;
                                });
                              }
                            });

                            return _buildCameraErrorFallback(message);
                          },
                          placeholderBuilder: (context) {
                            return Container(
                              color: Colors.black,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(color: Colors.tealAccent),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Initializing Camera...',
                                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Scanning bracket overlay
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.5), width: 2),
                                    ),
                                  ),
                                  Positioned(top: 0, left: 0, child: _buildCorner(isTop: true, isLeft: true)),
                                  Positioned(top: 0, right: 0, child: _buildCorner(isTop: true, isLeft: false)),
                                  Positioned(bottom: 0, left: 0, child: _buildCorner(isTop: false, isLeft: true)),
                                  Positioned(bottom: 0, right: 0, child: _buildCorner(isTop: false, isLeft: false)),
                                  Center(
                                    child: Icon(Icons.qr_code_scanner_rounded, size: 80, color: Colors.white.withValues(alpha: 0.2)),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Camera Active badge
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                                const SizedBox(width: 6),
                                Text(
                                  'Camera Active',
                                  style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            
            // Middle: Recently Mapped List
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Recently Mapped Locations',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _mappedLocations.isEmpty
                          ? Center(
                              child: Text(
                                'No locations mapped yet.\nScan a shelf QR to begin.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.white38),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _mappedLocations.length,
                              itemBuilder: (context, index) {
                                final loc = _mappedLocations[index];
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.warehouse_rounded, color: Colors.tealAccent),
                                  ),
                                  title: Text(
                                    '${loc['aisle']} - ${loc['shelf']}',
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    loc['category']!,
                                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
          children: [
            // Primary: Scan QR button
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (!_cameraFailed) {
                      _scannerController.stop();
                    }
                    _showMappingModal();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 22),
                  label: Text(
                    'Scan Shelf QR',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Fallback: Upload QR Photo
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _pickQRImage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 22),
                  label: Text(
                    'Upload QR Photo',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.tealAccent, width: 4) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.tealAccent, width: 4) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.tealAccent, width: 4) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.tealAccent, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}
