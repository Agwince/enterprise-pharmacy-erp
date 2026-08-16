import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storekeeper_routing_screen.dart';

class StorekeeperScannerScreen extends StatefulWidget {
  const StorekeeperScannerScreen({super.key});

  @override
  State<StorekeeperScannerScreen> createState() => _StorekeeperScannerScreenState();
}

class _StorekeeperScannerScreenState extends State<StorekeeperScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  bool _cameraFailed = false;
  String _cameraErrorMessage = '';

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);

    try {
      final data = await Supabase.instance.client
          .from('drugs')
          .select()
          .eq('barcode', code)
          .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medicine not found in database for barcode: $code'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isProcessing = false);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StorekeeperRoutingScreen(drug: data),
        ),
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error querying database: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Scan Medicine Barcode',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.amberAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scan the physical medicine barcode to log receipt and determine putaway location.',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_cameraFailed)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Camera Error',
                            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _cameraErrorMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      final message = switch (error.errorCode) {
                        MobileScannerErrorCode.permissionDenied =>
                          'Camera permission denied.\nPlease allow camera access in your browser/device settings.',
                        MobileScannerErrorCode.unsupported =>
                          'Camera scanning is not supported on this device.',
                        _ => 'Camera error: ${error.errorCode.name}',
                      };

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_cameraFailed) {
                          setState(() {
                            _cameraFailed = true;
                            _cameraErrorMessage = message;
                          });
                        }
                      });

                      return Container(); // Placeholder, the actual error UI is handled by _cameraFailed condition above
                    },
                    placeholderBuilder: (context) => const Center(
                      child: CircularProgressIndicator(color: Colors.amberAccent),
                    ),
                  ),
                if (!_cameraFailed)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amberAccent, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    width: 250,
                    height: 250,
                  ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.amberAccent),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
