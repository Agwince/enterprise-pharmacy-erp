import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'storekeeper_routing_screen.dart';

class StorekeeperHome extends StatefulWidget {
  const StorekeeperHome({super.key});

  @override
  State<StorekeeperHome> createState() => _StorekeeperHomeState();
}

class _StorekeeperHomeState extends State<StorekeeperHome> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      final data = await Supabase.instance.client
          .from('drugs')
          .select()
          .eq('sku', code)
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
        _scannerController.start();
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StorekeeperRoutingScreen(drug: data),
        ),
      ).then((_) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _scannerController.start();
        }
      });
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error querying database: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isProcessing = false);
      _scannerController.start();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storekeeper Receiving',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              AuthService().userName,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.amberAccent),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amberAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scan physical medicine barcode to log receipt and determine putaway location.',
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
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
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
          Container(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton.icon(
              onPressed: () {
                // Mock scanning a drug for testing since webcams might be tricky
                _scannerController.stop();
                _onDetect(BarcodeCapture(
                  barcodes: [Barcode(rawValue: 'DRUG-AMX-500', format: BarcodeFormat.qrCode)],
                ));
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Simulate Scan: DRUG-AMX-500'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.amberAccent,
                side: const BorderSide(color: Colors.amberAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
