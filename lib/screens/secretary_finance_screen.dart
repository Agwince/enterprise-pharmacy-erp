import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class SecretaryFinanceScreen extends StatefulWidget {
  const SecretaryFinanceScreen({super.key});

  @override
  State<SecretaryFinanceScreen> createState() => _SecretaryFinanceScreenState();
}

class _SecretaryFinanceScreenState extends State<SecretaryFinanceScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingInvoices();
  }

  Future<void> _fetchPendingInvoices() async {
    try {
      final res = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('payment_status', 'PENDING')
          .order('created_at', ascending: false);
      setState(() {
        _invoices = List<Map<String, dynamic>>.from(res as List);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading invoices: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _verifyPayment(Map<String, dynamic> invoice) {
    final TextEditingController receiptCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Verify MPesa Payment', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: receiptCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'MPesa Receipt Number',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (receiptCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter Receipt Number')));
                  return;
                }
                Navigator.pop(context);
                
                setState(() => _isLoading = true);
                try {
                  await Supabase.instance.client
                      .from('transactions')
                      .update({
                        'payment_status': 'PAID',
                        'mpesa_receipt_number': receiptCtrl.text.trim(),
                      })
                      .eq('id', invoice['id']);
                      
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verified!'), backgroundColor: Colors.green));
                  _fetchPendingInvoices();
                } catch (e) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              child: const Text('Verify & Clear'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Secretary Finance Dashboard', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.tealAccent),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchPendingInvoices();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: _invoices.isEmpty
                ? const Center(child: Text('No pending invoices!', style: TextStyle(color: Colors.white54, fontSize: 18)))
                : ListView.builder(
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text('Client: ${invoice['client_name'] ?? 'Walk-in'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Total Amount: \$${invoice['total_amount']}', style: const TextStyle(color: Colors.tealAccent)),
                              Text('Date: ${invoice['created_at']}', style: const TextStyle(color: Colors.white54)),
                            ],
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                            onPressed: () => _verifyPayment(invoice),
                            child: const Text('Verify MPesa Payment'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
    );
  }
}
