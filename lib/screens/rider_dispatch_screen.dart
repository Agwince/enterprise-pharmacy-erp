import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';
import 'dispatch_map_screen.dart';

class RiderDispatchScreen extends StatefulWidget {
  const RiderDispatchScreen({super.key});

  @override
  State<RiderDispatchScreen> createState() => _RiderDispatchScreenState();
}

class _RiderDispatchScreenState extends State<RiderDispatchScreen> {
  List<Map<String, dynamic>> _deliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  Future<void> _fetchDeliveries() async {
    try {
      final res = await Supabase.instance.client
          .from('deliveries')
          .select()
          .neq('status', 'Delivered')
          .order('created_at', ascending: false)
          .limit(50);
          
      setState(() {
        _deliveries = List<Map<String, dynamic>>.from(res as List);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading deliveries: ${e.toString()}')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateDeliveryStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('deliveries')
          .update({'status': status})
          .eq('id', id);
          
      _fetchDeliveries();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delivery marked as $status!', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Rider Dispatch', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.blueAccent),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DispatchMapScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : _deliveries.isEmpty 
              ? Center(child: Text('No active deliveries.', style: GoogleFonts.inter(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _deliveries.length,
                  itemBuilder: (context, index) {
                    final tx = _deliveries[index];
                    
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.motorcycle, color: Colors.tealAccent, size: 28),
                                    const SizedBox(width: 12),
                                    Text(
                                      tx['customer_name'] ?? 'Unknown Customer',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (tx['status'] == 'In Transit') ? Colors.blue.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (tx['status'] == 'In Transit') ? Colors.blueAccent : Colors.orangeAccent,
                                    ),
                                  ),
                                  child: Text(
                                    tx['status'] ?? 'Pending',
                                    style: TextStyle(
                                      color: (tx['status'] == 'In Transit') ? Colors.blueAccent : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(tx['delivery_address'] ?? 'No address provided', style: const TextStyle(color: Colors.white70, fontSize: 14))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 8),
                                Text(tx['customer_phone'] ?? 'No phone', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.receipt_long, color: Colors.white54, size: 16),
                                const SizedBox(width: 8),
                                Text('Order Ref: ${tx['order_reference'] ?? 'N/A'}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: Colors.white.withValues(alpha: 0.1)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Amount Due', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'KES ${tx['amount_due'] ?? 0}',
                                      style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (tx['status'] == 'Pending Dispatch' || tx['status'] == null)
                                      ElevatedButton(
                                        onPressed: () => _updateDeliveryStatus(tx['id'].toString(), 'In Transit'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueAccent,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Accept Dispatch'),
                                      ),
                                    if (tx['status'] == 'In Transit' || tx['status'] == 'Pending Dispatch') ...[
                                      if (tx['status'] == 'Pending Dispatch' || tx['status'] == null)
                                        const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _updateDeliveryStatus(tx['id'].toString(), 'Delivered'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Mark Delivered'),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}