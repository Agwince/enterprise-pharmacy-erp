import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;
import '../services/auth_service.dart';
import 'visual_pick_list_screen.dart';

class InvoiceScannerScreen extends StatefulWidget {
  const InvoiceScannerScreen({super.key});

  @override
  State<InvoiceScannerScreen> createState() => _InvoiceScannerScreenState();
}

class _InvoiceScannerScreenState extends State<InvoiceScannerScreen> {
  bool _isScanning = false;
  String _scanStatusText = 'Align invoice within frame...';
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

  Future<void> _pickInvoiceImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null) {
        _startScan(image);
      }
    } catch (e) {
      try {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          _startScan(image);
        }
      } catch (e2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera or gallery: $e2'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _startScan([XFile? image]) async {
    if (!_cameraFailed) {
      _scannerController.stop();
    }

    setState(() {
      _isScanning = true;
      _scanStatusText = 'Initializing Offline AI Scanner...';
    });

    List<String> extractedWords = [];
    final List<String> missingItems = [];

    if (image != null) {
      try {
        setState(() {
          _scanStatusText = 'Extracting Text (First run takes 10s)...';
        });
        
        // Use Tesseract (Offline, no CORS, no rate limit)
        String parsedText = await FlutterTesseractOcr.extractText(
          image.path, 
          language: 'eng',
          args: {
            "preserve_interword_spaces": "1",
          }
        );
        
        final List<String> words = parsedText.split(RegExp(r'\s+'));
        extractedWords.addAll(words.where((w) => w.length > 2));
      } catch (e) {
        debugPrint('OCR Error: $e');
        missingItems.add('OCR Processing Failed');
      }
    }

    if (!mounted) return;
    setState(() {
      _scanStatusText = 'Matching text to your Database...';
    });

    final supabase = Supabase.instance.client;
    final List<String> foundTerms = [];
    final Map<String, double> requiredQuantities = {};

    try {
      final res = await supabase.from('drugs').select('name');
      final List<dynamic> allDrugs = res as List<dynamic>;
      final List<String> allDrugNames = allDrugs.map((d) => (d['name'] as String).toUpperCase()).toList();

      final String rawOcrText = extractedWords.join(' ').toUpperCase();
      
      for (String dbName in allDrugNames) {
        final String normalizedDbName = dbName.replaceAll(RegExp(r'\s+'), '');
        final String normalizedOcrText = rawOcrText.replaceAll(RegExp(r'\s+'), '');

        bool isMatch = false;
        if (normalizedOcrText.contains(normalizedDbName)) {
           isMatch = true;
        } else {
           List<String> dbWords = dbName.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
           if (dbWords.length >= 2) {
             if (rawOcrText.contains(dbWords[0]) && rawOcrText.contains(dbWords[1])) {
               isMatch = true;
             }
           } else if (dbWords.isNotEmpty) {
             if (rawOcrText.contains(dbWords[0]) && dbWords[0].length > 5) {
               isMatch = true;
             }
           }
        }

        if (isMatch) {
          foundTerms.add(dbName);
          double extractedQty = 1.0;
          for (String word in extractedWords) {
             final val = double.tryParse(word);
             if (val != null && val > 0 && val < 500) {
               extractedQty = val;
             }
          }
          requiredQuantities[dbName] = extractedQty;
        }
      }
      
      if (foundTerms.isEmpty && missingItems.isEmpty) {
        missingItems.add('Text found, but no exact matching medicines in system.');
      }
    } catch (e) {
      debugPrint('Error checking DB: $e');
      missingItems.add('Database check failed');
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => VisualPickListScreen(
        searchTerms: foundTerms.isEmpty ? ['__NO_MATCH__'] : foundTerms, 
        missingItems: missingItems,
        requiredQuantities: requiredQuantities,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Invoice Scanner',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: _isScanning ? _buildProcessingState() : _buildCaptureState(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isScanning
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _pickInvoiceImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(
                    'Scan Invoice',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCaptureState() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          errorBuilder: (context, error) {
            return Container(
              color: const Color(0xFF0B1120),
              child: Center(
                child: Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              ),
            );
          },
          placeholderBuilder: (context) {
            return Container(color: Colors.black);
          },
        ),
        
        // Blur overlay
        ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),
        
        // Focus window
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.8), width: 3),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.tealAccent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: MobileScanner(
                controller: _scannerController,
                placeholderBuilder: (context) => Container(color: Colors.black),
              ),
            ),
          ),
        ),
        
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              _scanStatusText,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingState() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0B1120)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.tealAccent,
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _scanStatusText,
            style: GoogleFonts.inter(
              color: Colors.tealAccent,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Powered by Offline Neural Engine',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
