import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

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
          .from('transactions')
          .select()
          .eq('transaction_type', 'sale')
          .order('created_at', ascending: false)
          .limit(50);
          
      // Filter out delivered ones locally to avoid schema issues if delivery_status doesn't exist
      final filtered = (res as List).where((tx) => tx['payment_status']?.toString().toUpperCase() != 'DELIVERED').toList();
          
      setState(() {
        _deliveries = List<Map<String, dynamic>>.from(filtered);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading deliveries: ')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsDelivered(String id) async {
    try {
      // Repurposing payment_status to avoid schema issues, or just updating to indicate completion
      await Supabase.instance.client
          .from('transactions')
          .update({'payment_status': 'DELIVERED'})
          .eq('id', id);
          
      _fetchDeliveries();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Delivered!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: '), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Rider Dispatch', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: _isLoading
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
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const Icon(Icons.motorcycle, color: Colors.tealAccent, size: 36),
                        title: Text(tx['client_name'] ?? 'Unknown Client', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Invoice: #', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Payment: ', style: TextStyle(color: tx['payment_status'] == 'PAID' ? Colors.green : Colors.orange, fontSize: 14)),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _markAsDelivered(tx['id'].toString()),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                          child: const Text('Mark Delivered'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}