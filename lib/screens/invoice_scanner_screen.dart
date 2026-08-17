import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'visual_pick_list_screen.dart';

class InvoiceScannerScreen extends StatefulWidget {
  const InvoiceScannerScreen({super.key});

  @override
  State<InvoiceScannerScreen> createState() => _InvoiceScannerScreenState();
}

class _InvoiceScannerScreenState extends State<InvoiceScannerScreen> {
  bool _isScanning = false;
  String _scanStatusText = 'Capturing High-Res Image...';
  late MobileScannerController _scannerController;
  bool _cameraFailed = false;
  String _cameraErrorMessage = '';
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
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

  /// Fallback: capture invoice photo via native camera or gallery
  Future<void> _pickInvoiceImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null) {
        _startScan();
      }
    } catch (e) {
      // Fall back to gallery if native camera fails
      try {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          _startScan();
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

  void _startScan() async {
    if (!_cameraFailed) {
      _scannerController.stop();
    }

    setState(() {
      _isScanning = true;
      _scanStatusText = 'Reading Invoice Text...';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _scanStatusText = 'Matching to Database...';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _scanStatusText = 'Generating Visual Route...';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    // Route to Visual Pick List (it will simulate scanning 3 random items from DB since we pass an empty list)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const VisualPickListScreen(
        searchTerms: [], // Will load all items in DB as "found"
        missingItems: [
          "TINIDAZOLE TABS 500MG 4'S",
          'BRUFEN SYRUP 60ML',
          'PROMETHAZINE SUSP 60ML'
        ],
      )),
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
                width: 260,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _pickInvoiceImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.photo_camera_rounded, size: 22),
                  label: Text(
                    'Take Photo of Invoice',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
                      if (image != null) _startScan();
                    } catch (_) {}
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purpleAccent,
                    side: const BorderSide(color: Colors.purpleAccent, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 20),
                  label: Text(
                    'Upload from Gallery',
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
                color: Colors.purpleAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.document_scanner_rounded, color: Colors.purpleAccent),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Auto-Picker',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Floor Ops • Scanner Mode',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.purpleAccent, fontWeight: FontWeight.w600),
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
              label: Text('Logout Picker', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isScanning ? _buildProcessingState() : _buildCaptureState(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isScanning
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Primary scan button
                  SizedBox(
                    height: 64,
                    width: 280,
                    child: FloatingActionButton.extended(
                      heroTag: 'scan_invoice',
                      onPressed: _startScan,
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.camera_alt, size: 24),
                      label: Text(
                        'Snap Photo of Printed Invoice',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Fallback: Upload photo
                  SizedBox(
                    height: 64,
                    width: 64,
                    child: FloatingActionButton(
                      heroTag: 'upload_invoice',
                      onPressed: _pickInvoiceImage,
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      child: const Icon(Icons.folder_open_rounded, size: 28),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCaptureState() {
    if (_cameraFailed) {
      return _buildCameraErrorFallback(_cameraErrorMessage);
    }

    return Stack(
      children: [
        // Live camera feed with error handling
        MobileScanner(
          controller: _scannerController,
          errorBuilder: (context, error) {
            final message = switch (error.errorCode) {
              MobileScannerErrorCode.permissionDenied =>
                'Camera permission denied.\nPlease allow camera access in your browser/device settings.',
              MobileScannerErrorCode.unsupported =>
                'Camera scanning is not supported on this device.',
              MobileScannerErrorCode.genericError =>
                'Camera error: ${error.errorDetails?.message ?? 'Unknown'}',
              _ => 'Scanner error: ${error.errorCode.name}',
            };

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
                    const CircularProgressIndicator(color: Colors.purpleAccent),
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
        
        // Scanning brackets overlay
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5), width: 2),
                      color: Colors.transparent,
                    ),
                  ),
                  Positioned(top: 0, left: 0, child: _buildCorner(isTop: true, isLeft: true)),
                  Positioned(top: 0, right: 0, child: _buildCorner(isTop: true, isLeft: false)),
                  Positioned(bottom: 0, left: 0, child: _buildCorner(isTop: false, isLeft: true)),
                  Positioned(bottom: 0, right: 0, child: _buildCorner(isTop: false, isLeft: false)),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.document_scanner_outlined, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          'Align invoice within frame',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner({required bool isTop, required bool isLeft}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.purpleAccent, width: 4) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.purpleAccent, width: 4) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.purpleAccent, width: 4) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.purpleAccent, width: 4) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 6),
          ),
          const SizedBox(height: 40),
          Text(
            _scanStatusText,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
