import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class StoreMappingScreen extends StatefulWidget {
  const StoreMappingScreen({super.key});

  @override
  State<StoreMappingScreen> createState() => _StoreMappingScreenState();
}

class _StoreMappingScreenState extends State<StoreMappingScreen> {
  final List<Map<String, String>> _mappedLocations = [];

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
              onPressed: () => Navigator.pop(context),
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
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.black,
                  ),
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
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _showMappingModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.camera_alt_rounded, size: 24),
            label: Text(
              'Scan Physical Shelf QR',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
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
