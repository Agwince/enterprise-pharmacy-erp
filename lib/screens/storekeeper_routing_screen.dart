import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorekeeperRoutingScreen extends StatefulWidget {
  final Map<String, dynamic> drug;

  const StorekeeperRoutingScreen({
    super.key,
    required this.drug,
  });

  @override
  State<StorekeeperRoutingScreen> createState() => _StorekeeperRoutingScreenState();
}

class _StorekeeperRoutingScreenState extends State<StorekeeperRoutingScreen> {
  bool _isSaving = false;

  void _savePutaway(String destination, String location) async {
    setState(() => _isSaving = true);

    try {
      // Create a receipt transaction in the database
      final String drugId = widget.drug['id'];
      
      // Get the first branch as default
      final branches = await Supabase.instance.client.from('branches').select('id').limit(1);
      final String branchId = branches.isNotEmpty ? branches[0]['id'] : '';

      if (branchId.isNotEmpty) {
        await Supabase.instance.client.from('transactions').insert({
          'branch_id': branchId,
          'drug_id': drugId,
          'transaction_type': 'receipt',
          'quantity': 1,
          'unit_price': widget.drug['price'] ?? 0.00,
          'total_amount': widget.drug['price'] ?? 0.00,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully received and routed to $destination ($location)'),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Go back to scanner
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving receipt: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  void _showLocationDialog(String destination, String location) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.amberAccent, width: 2),
          ),
          title: Text(
            'Route to $destination',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, size: 64, color: Colors.amberAccent),
              const SizedBox(height: 16),
              Text(
                'Please take this item to:',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  location,
                  style: GoogleFonts.inter(
                    color: Colors.amberAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: _isSaving ? null : () {
                Navigator.pop(context);
                _savePutaway(destination, location);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Confirm Putaway'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.drug['name'] ?? 'Unknown Medicine';
    final String sku = widget.drug['barcode'] ?? 'Unknown Barcode';
    final String binLocation = widget.drug['target_shelf'] ?? 'UNASSIGNED';
    
    // In our simplified database, we use bin_location for both, but we could map pharmacy differently.
    final String storeLocation = 'WAREHOUSE: $binLocation';
    final String pharmacyLocation = 'PHARMACY SHELF: $binLocation';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Route Medicine',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
              const SizedBox(height: 16),
              Text(
                'Barcode Scanned Successfully',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                color: const Color(0xFF1E293B),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SKU: $sku',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Where are you routing this receipt?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: ElevatedButton(
                        onPressed: () => _showLocationDialog('Store', storeLocation),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                          foregroundColor: Colors.blueAccent,
                          side: const BorderSide(color: Colors.blueAccent, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              'Full Box\n(To Store)',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: ElevatedButton(
                        onPressed: () => _showLocationDialog('Pharmacy', pharmacyLocation),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent.withValues(alpha: 0.2),
                          foregroundColor: Colors.purpleAccent,
                          side: const BorderSide(color: Colors.purpleAccent, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.medication_liquid_rounded, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              'Loose Unit\n(To Pharmacy)',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
