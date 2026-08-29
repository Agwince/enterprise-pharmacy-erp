import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'delivery_routing_screen.dart';

class ReceiveDeliveryScanner extends StatefulWidget {
  const ReceiveDeliveryScanner({super.key});

  @override
  State<ReceiveDeliveryScanner> createState() => _ReceiveDeliveryScannerState();
}

class _ReceiveDeliveryScannerState extends State<ReceiveDeliveryScanner> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _scanStep = 0; // 0 = idle, 1 = scanning, 2 = finding items

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 300).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startScan() async {
    setState(() => _scanStep = 1);

    // Simulate scanning processing
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    setState(() => _scanStep = 2);

    // Simulate OCR text extraction
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    // Route to Delivery Routing
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DeliveryRoutingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          'Supplier Invoice Scanner',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 320,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amberAccent, width: 2),
                  ),
                  child: Stack(
                    children: [
                      if (_scanStep == 0)
                        const Center(
                          child: Icon(Icons.document_scanner_rounded, color: Colors.white24, size: 80),
                        ),
                      if (_scanStep > 0)
                        AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            return Positioned(
                              top: _animation.value,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amberAccent.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                      spreadRadius: 5,
                                    )
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
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Text(
                    _scanStep == 0
                        ? 'Align Supplier Invoice in frame'
                        : _scanStep == 1
                            ? 'Scanning line items...'
                            : 'Identifying medicines...',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _scanStep == 0 ? _startScan : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(
                        _scanStep == 0 ? 'Capture Invoice' : 'Processing...',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
