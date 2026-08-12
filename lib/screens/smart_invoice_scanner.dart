import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'wholesale_catalog_screen.dart';

enum ScannerState { capture, processing, results }

class SmartInvoiceScannerScreen extends StatefulWidget {
  const SmartInvoiceScannerScreen({super.key});

  @override
  State<SmartInvoiceScannerScreen> createState() => _SmartInvoiceScannerScreenState();
}

class _SmartInvoiceScannerScreenState extends State<SmartInvoiceScannerScreen> {
  ScannerState _currentState = ScannerState.capture;

  final List<Map<String, dynamic>> _extractedItems = [
    {
      'name': 'Amoxicillin Trihydrate 500mg',
      'qty': 'Need: 10 Boxes',
      'location': 'AISLE 3 - SHELF C',
      'image': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
    {
      'name': 'Paracetamol Extra 500mg/65mg',
      'qty': 'Need: 5 Cartons',
      'location': 'AISLE 1 - PALLET BAY A4',
      'image': 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
    {
      'name': 'Ibuprofen Suspension 100mg/5ml',
      'qty': 'Need: 20 Bottles',
      'location': 'AISLE 5 - SHELF E2',
      'image': 'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800&auto=format&fit=crop&q=80',
      'checked': false,
    },
  ];

  void _simulateScan() async {
    setState(() {
      _currentState = ScannerState.processing;
    });

    // Simulate AI extraction and DB matching
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _currentState = ScannerState.results;
      });
    }
  }

  void _resetScanner() {
    setState(() {
      _currentState = ScannerState.capture;
      for (var item in _extractedItems) {
        item['checked'] = false;
      }
    });
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
                  'Smart OCR Document Extraction',
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
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0F172A)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.warehouse_rounded, size: 40, color: Colors.cyanAccent),
                  const SizedBox(height: 12),
                  Text('Floor Ops Workspace', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(AuthService().userName, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_rounded, color: Colors.white54),
              title: Text('Wholesale Catalog', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) => const WholesaleCatalogScreen(),
                    transitionDuration: Duration.zero,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_rounded, color: Colors.purpleAccent),
              title: Text('Invoice Auto-Picker', style: GoogleFonts.inter(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
              selected: true,
              selectedTileColor: Colors.purpleAccent.withValues(alpha: 0.1),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentState) {
      case ScannerState.capture:
        return _buildCaptureState();
      case ScannerState.processing:
        return _buildProcessingState();
      case ScannerState.results:
        return _buildResultsState();
    }
  }

  Widget _buildCaptureState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Viewfinder placeholder
            Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.black26,
                border: Border.all(color: Colors.purpleAccent, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white24),
                  Positioned(
                    top: 20, left: 20,
                    child: _buildCorner(isTop: true, isLeft: true),
                  ),
                  Positioned(
                    top: 20, right: 20,
                    child: _buildCorner(isTop: true, isLeft: false),
                  ),
                  Positioned(
                    bottom: 20, left: 20,
                    child: _buildCorner(isTop: false, isLeft: true),
                  ),
                  Positioned(
                    bottom: 20, right: 20,
                    child: _buildCorner(isTop: false, isLeft: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 300,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _simulateScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 8,
                  shadowColor: Colors.purpleAccent.withValues(alpha: 0.5),
                ),
                icon: const Icon(Icons.document_scanner_rounded, size: 28),
                label: Text('Scan Paper Invoice', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Align invoice within the frame',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
            )
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
          const CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 4),
          const SizedBox(height: 32),
          Text(
            'AI Vision Extracting Items...',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Matching to Inventory DB...',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice Extracted', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                  Text('3 Items Matched', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _resetScanner,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                label: Text('Scan Another', style: GoogleFonts.inter(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: _extractedItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final item = _extractedItems[index];
              return Container(
                decoration: BoxDecoration(
                  color: item['checked'] ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item['checked'] ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
                    width: item['checked'] ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Checkbox Area
                    InkWell(
                      onTap: () {
                        setState(() {
                          item['checked'] = !item['checked'];
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: item['checked'] ? Colors.greenAccent : Colors.transparent,
                            border: Border.all(color: item['checked'] ? Colors.greenAccent : Colors.white54, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: item['checked']
                              ? const Icon(Icons.check_rounded, color: Colors.black, size: 24)
                              : null,
                        ),
                      ),
                    ),
                    
                    // Image
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(right: 20, top: 20, bottom: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: item['image'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
                          errorWidget: (context, url, error) => const Icon(Icons.medication_rounded, size: 40, color: Colors.purpleAccent),
                        ),
                      ),
                    ),

                    // Details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24.0, top: 20, bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.inter(
                                color: item['checked'] ? Colors.white54 : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                decoration: item['checked'] ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['qty'],
                              style: GoogleFonts.inter(
                                color: Colors.purpleAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                'LOCATION: ${item['location']}',
                                style: GoogleFonts.inter(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
