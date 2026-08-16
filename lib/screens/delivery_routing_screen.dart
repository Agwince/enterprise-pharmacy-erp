import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/drug.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';

class DeliveryRoutingScreen extends StatefulWidget {
  const DeliveryRoutingScreen({super.key});

  @override
  State<DeliveryRoutingScreen> createState() => _DeliveryRoutingScreenState();
}

class _DeliveryRoutingScreenState extends State<DeliveryRoutingScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _scannedItems = [];

  @override
  void initState() {
    super.initState();
    _loadSimulatedInvoiceItems();
  }

  Future<void> _loadSimulatedInvoiceItems() async {
    try {
      List<Drug> allDrugs = await _supabaseService.fetchDrugs();
      
      if (allDrugs.isNotEmpty) {
        allDrugs.shuffle();
        // Pick 4 random drugs for the simulation
        final selected = allDrugs.take(4).toList();
        
        _scannedItems = selected.map((drug) {
          // Determine realistic package assumptions based on name/category
          bool isLiquid = drug.name.toUpperCase().contains('SUSP') || drug.name.toUpperCase().contains('SYRUP');
          String boxType = isLiquid ? 'Carton (100 Bottles)' : 'Carton (50 Boxes)';
          String looseType = isLiquid ? 'Loose Bottles' : 'Loose Packs';
          
          return {
            'drug': drug,
            'routed': false,
            'route_destination': null, // 'STORE' or 'PHARMACY'
            'box_type': boxType,
            'loose_type': looseType,
          };
        }).toList();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading invoice items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _routeItem(int index, String destination) {
    setState(() {
      _scannedItems[index]['routed'] = true;
      _scannedItems[index]['route_destination'] = destination;
    });

    final drug = _scannedItems[index]['drug'] as Drug;
    final message = destination == 'STORE'
        ? '📦 Full Boxes Routed to Store\\nLocation: ${drug.binLocation}'
        : '💊 Loose Items Routed to Pharmacy Shelf\\nLocation: ${drug.binLocation}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: destination == 'STORE' ? Colors.blueAccent : Colors.tealAccent.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int routedCount = _scannedItems.where((item) => item['routed'] == true).length;
    bool allRouted = routedCount == _scannedItems.length && _scannedItems.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock Routing',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Invoice #INV-92837',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.amberAccent),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '$routedCount / ${_scannedItems.length} Routed',
                style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : _scannedItems.isEmpty
              ? Center(
                  child: Text('No items found on invoice.', style: GoogleFonts.inter(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _scannedItems.length,
                  itemBuilder: (context, index) {
                    final item = _scannedItems[index];
                    final drug = item['drug'] as Drug;
                    final bool isRouted = item['routed'];
                    final String? destination = item['route_destination'];

                    return Card(
                      color: isRouted ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isRouted
                              ? (destination == 'STORE' ? Colors.blueAccent : Colors.tealAccent)
                              : Colors.white12,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: drug.imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(drug.imageUrl!, fit: BoxFit.cover),
                                        )
                                      : const Icon(Icons.medication_rounded, color: Colors.white54),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        drug.name,
                                        style: GoogleFonts.inter(
                                          color: isRouted ? Colors.white54 : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'SKU: ${drug.sku}',
                                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isRouted)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: destination == 'STORE' ? Colors.blueAccent : Colors.tealAccent,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (!isRouted) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _routeItem(index, 'STORE'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blueAccent,
                                        side: const BorderSide(color: Colors.blueAccent),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.warehouse_rounded, size: 16),
                                      label: Text(
                                        'Full Boxes\\n(To Store)',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _routeItem(index, 'PHARMACY'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.tealAccent,
                                        side: const BorderSide(color: Colors.tealAccent),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: const Icon(Icons.local_pharmacy_rounded, size: 16),
                                      label: Text(
                                        'Loose Items\\n(To Pharmacy)',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: destination == 'STORE'
                                      ? Colors.blueAccent.withOpacity(0.1)
                                      : Colors.tealAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destination == 'STORE' ? '✅ Routed to Store/Warehouse' : '✅ Routed to Pharmacy Shelf',
                                      style: GoogleFonts.inter(
                                        color: destination == 'STORE' ? Colors.blueAccent : Colors.tealAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Putaway Location: ${drug.binLocation}',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: allRouted
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Complete Receiving',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
