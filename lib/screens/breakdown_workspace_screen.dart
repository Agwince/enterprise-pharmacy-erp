import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BreakdownWorkspaceScreen extends StatefulWidget {
  const BreakdownWorkspaceScreen({super.key});

  @override
  State<BreakdownWorkspaceScreen> createState() => _BreakdownWorkspaceScreenState();
}

class _BreakdownWorkspaceScreenState extends State<BreakdownWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  bool _isFlashOn = false;

  final List<Map<String, dynamic>> _checklistItems = [];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _simulateScan() {
    setState(() {
      for (var item in _checklistItems) {
        if (!item['isChecked']) {
          item['isChecked'] = true;
          item['scanned'] = item['expected'];
          break;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.blueAccent,
        content: Text('Simulated Barcode Scan: Item Verified!', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
            const Icon(Icons.qr_code_scanner_rounded, color: Colors.cyanAccent),
            const SizedBox(width: 10),
            Text(
              'Mixed-SKU Intake Workspace',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.amber),
            onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
            tooltip: 'Toggle Camera Flash',
          ),
        ],
      ),
      body: Column(
        children: [
          // TOP HALF: SIMULATED CAMERA PREVIEW (Mobile First Split)
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                // Simulated Camera Feed Frame
                Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 48,
                          color: _isFlashOn ? Colors.white : Colors.white24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Simulated Barcode Viewfinder active',
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                // Viewfinder Target Box Overlay
                Center(
                  child: Container(
                    width: 260,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.cyanAccent.withOpacity(0.05),
                    ),
                    child: Stack(
                      children: [
                        AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, child) {
                            return Positioned(
                              top: _scanController.value * 120,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                decoration: const BoxDecoration(
                                  color: Colors.cyanAccent,
                                  boxShadow: [
                                    BoxShadow(color: Colors.cyanAccent, blurRadius: 8, spreadRadius: 2),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Manual Trigger Floating Action inside Camera Top
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: _simulateScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: Text('Simulate Scan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM HALF: INTAKE CHECKLIST (Mobile First Split)
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Receiving Box #BOX-9081 Breakdown',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${_checklistItems.where((i) => i['isChecked']).length} / ${_checklistItems.length} Verified',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // Checklist Items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _checklistItems.length,
                      itemBuilder: (context, index) {
                        final item = _checklistItems[index];
                        final bool checked = item['isChecked'] as bool;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: checked ? const Color(0xFF0F2942) : const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: checked ? Colors.cyanAccent.withOpacity(0.4) : Colors.white10,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                activeColor: Colors.cyanAccent,
                                checkColor: Colors.black,
                                value: checked,
                                onChanged: (val) {
                                  setState(() => item['isChecked'] = val ?? false);
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item['sku']} • Lot: ${item['batch']}',
                                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white38, size: 20),
                                    onPressed: () {
                                      if (item['scanned'] > 0) {
                                        setState(() => item['scanned']--);
                                      }
                                    },
                                  ),
                                  Text(
                                    '${item['scanned']} / ${item['expected']}',
                                    style: GoogleFonts.inter(
                                      color: item['scanned'] == item['expected'] ? const Color(0xFF10B981) : Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 20),
                                    onPressed: () {
                                      setState(() => item['scanned']++);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Action Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF0F172A),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF10B981),
                              content: Text('Intake Verified & Synced with Supabase Inventory!', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.inventory_2_rounded),
                        label: Text(
                          'Complete Intake & Update Stock',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
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
  }
}
