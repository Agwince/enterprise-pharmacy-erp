import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../utils/invoice_parser.dart';
import 'invoice_review_screen.dart';

class InvoiceScannerScreen extends StatefulWidget {
  const InvoiceScannerScreen({super.key});

  @override
  State<InvoiceScannerScreen> createState() => _InvoiceScannerScreenState();
}

class _InvoiceScannerScreenState extends State<InvoiceScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _processImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      setState(() => _isProcessing = true);

      final Uint8List imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      String extractedText = await AiService().extractTextFromImage(base64Image);

      final supabase = Supabase.instance.client;
      final res = await supabase.from('drugs').select('id, name, target_shelf').order('name');
      final catalog = List<Map<String, dynamic>>.from(res as List);

      final extractedItems = InvoiceParser.parseInvoice(extractedText, catalog);

      if (!mounted) return;

      setState(() => _isProcessing = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => InvoiceReviewScreen(
          imageBytes: imageBytes,
          extractedText: extractedText,
          parsedItems: extractedItems,
        )),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Dispatch Workspace', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => AuthService().logout(),
          )
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.tealAccent),
                  const SizedBox(height: 16),
                  Text('Scanning & Matching offline...', style: GoogleFonts.inter(color: Colors.tealAccent, fontSize: 16)),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: Colors.tealAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.document_scanner_rounded, size: 80, color: Colors.tealAccent),
                  ),
                  const SizedBox(height: 32),
                  Text('Ready to Scan', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isProcessing ? null : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _processImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text('Scan Invoice', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
