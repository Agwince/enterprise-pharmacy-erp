import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/auth_service.dart';
import '../services/ai_scanner_service.dart';
import 'visual_pick_list_screen.dart';
import 'invoice_review_screen.dart';

class InvoiceScannerScreen extends StatefulWidget {
  const InvoiceScannerScreen({super.key});

  @override
  State<InvoiceScannerScreen> createState() => _InvoiceScannerScreenState();
}

class _InvoiceScannerScreenState extends State<InvoiceScannerScreen> {
  bool _isScanning = false;
  String _scanStatusText = 'Align invoice within frame...';
  final ImagePicker _imagePicker = ImagePicker();

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
    setState(() {
      _isScanning = true;
      _scanStatusText = 'Initializing Offline AI Scanner...';
    });

    List<String> extractedWords = [];
    final List<String> missingItems = [];

    if (image != null) {
      try {
        setState(() {
          _scanStatusText = kIsWeb ? 'Analyzing Invoice with Cloud AI...' : 'Extracting Text (First run takes 10s)...';
        });
        
        if (kIsWeb) {
          final imageBytes = await image.readAsBytes();
          final aiService = AiScannerService();
          final extractedJson = await aiService.extractInvoiceData(imageBytes);
          
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => InvoiceReviewScreen(
              imageBytes: imageBytes,
              prefilledItems: extractedJson,
            )),
          );
          return;
        } else {
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
        }
      } on PlatformException catch (e) {
        debugPrint('OCR Platform Error: $e');
        if (!mounted || image == null) return;
        final Uint8List imageBytes = await image.readAsBytes();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => InvoiceReviewScreen(imageBytes: imageBytes)),
        );
        return;
      } on NoSuchMethodError catch (e) {
        debugPrint('OCR NoSuchMethodError: $e');
        if (!mounted || image == null) return;
        final Uint8List imageBytes = await image.readAsBytes();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => InvoiceReviewScreen(imageBytes: imageBytes)),
        );
        return;
      } catch (e) {
        debugPrint('OCR Error: $e');
        if (!mounted) return;
        
        // Catch any remaining web plugin errors disguised as normal exceptions
        if (e.toString().contains('NoSuchMethodError') || e.toString().contains('PlatformException')) {
          if (image == null) return;
          final Uint8List imageBytes = await image.readAsBytes();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => InvoiceReviewScreen(imageBytes: imageBytes)),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read image text. Please try again. Error: $e'),
            backgroundColor: Colors.redAccent,
          )
        );
        setState(() {
          _isScanning = false;
        });
        return;
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
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Dispatch Workspace',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              tooltip: 'Logout',
              onPressed: () {
                AuthService().logout();
              },
            ),
          )
        ],
      ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.document_scanner_rounded, size: 80, color: Colors.tealAccent),
          ),
          const SizedBox(height: 32),
          Text(
            'Ready to Scan',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap the button below to capture an invoice\nusing your device camera.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 100), // spacing for FAB
        ],
      ),
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
            kIsWeb ? 'Powered by Google Gemini AI' : 'Powered by Offline Neural Engine',
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
