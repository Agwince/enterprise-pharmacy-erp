import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../config/app_config.dart';
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
    // Startup / Trigger Guard: If OCR key is not configured, disable feature and notify
    if (!AppConfig.isOcrConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document scanning is not configured'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    try {
      // Compress and resize longest edge to ~1600 px, quality 80 at capture time
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (image == null) return;

      setState(() => _isProcessing = true);

      final Uint8List imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      String extractedText = await AiService().extractTextFromImage(base64Image, rawBytes: imageBytes);

      // Check if OCR failed or returned empty/no legible text
      if (extractedText.trim().isEmpty ||
          extractedText.trim() == 'No legible text detected from prescription scan.') {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read this document — try again or enter details manually.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

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
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read this document — try again or enter details manually.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isConfigured = AppConfig.isOcrConfigured;

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
                    decoration: BoxDecoration(
                      color: isConfigured
                          ? Colors.tealAccent.withValues(alpha: 0.1)
                          : Colors.orangeAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isConfigured ? Icons.document_scanner_rounded : Icons.scanner_outlined,
                      size: 80,
                      color: isConfigured ? Colors.tealAccent : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isConfigured ? 'Ready to Scan' : 'Scanner Disabled',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (!isConfigured)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Document scanning is not configured',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
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
            onPressed: isConfigured ? _processImage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isConfigured ? Colors.tealAccent : Colors.white24,
              foregroundColor: isConfigured ? Colors.black : Colors.white38,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text(
              isConfigured ? 'Scan Invoice' : 'Document scanning is not configured',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

