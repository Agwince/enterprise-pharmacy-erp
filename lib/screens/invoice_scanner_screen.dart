import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
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

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _scanStatusText = 'Capturing High-Res Image...';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _scanStatusText = 'Running OCR Text Extraction...';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _scanStatusText = 'Matching SKUs to Warehouse Bin Locations...';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    // Route to Visual Pick List
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const VisualPickListScreen()),
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
          : SizedBox(
              height: 70,
              width: 300,
              child: FloatingActionButton.extended(
                onPressed: _startScan,
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.camera_alt, size: 28),
                label: Text(
                  'Scan Paper Invoice',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
    );
  }

  Widget _buildCaptureState() {
    return Stack(
      children: [
        // Camera simulation dark background
        Container(color: Colors.black87),
        
        // Scanning brackets
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
