import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class TelesalesPosScreen extends StatefulWidget {
  const TelesalesPosScreen({super.key});

  @override
  State<TelesalesPosScreen> createState() => _TelesalesPosScreenState();
}

class _TelesalesPosScreenState extends State<TelesalesPosScreen> {
  List<Map<String, dynamic>> _catalog = [];
  List<Map<String, dynamic>> _filteredCatalog = [];
  List<Map<String, dynamic>> _cart = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _clientController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    try {
      final res = await Supabase.instance.client.from('drugs').select('id, name').order('name');
      setState(() {
        _catalog = List<Map<String, dynamic>>.from(res as List);
        _filteredCatalog = List.from(_catalog);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading catalog: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterCatalog(String query) {
    if (query.isEmpty) {
      setState(() => _filteredCatalog = List.from(_catalog));
      return;
    }
    setState(() {
      _filteredCatalog = _catalog.where((d) => 
        (d['name'] as String).toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _addToCart(Map<String, dynamic> drug) {
    setState(() {
      final existing = _cart.indexWhere((item) => item['id'] == drug['id']);
      if (existing >= 0) {
        _cart[existing]['qty'] += 1;
      } else {
        _cart.add({
          'id': drug['id'],
          'name': drug['name'],
          'qty': 1,
          'price': drug['price'] != null ? (drug['price'] as num).toDouble() : 10.0,
        });
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  double get _cartTotal {
    double total = 0;
    for (var item in _cart) {
      total += (item['qty'] as int) * (item['price'] as double);
    }
    return total;
  }

  Future<void> _checkout(String paymentStatus, String? receiptNumber) async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }
    if (_clientController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Client Name!')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      final branches = await db.from('branches').select();
      String? branchId;
      if (branches.isNotEmpty) branchId = branches[0]['id'];

      for (var item in _cart) {
        await db.from('transactions').insert({
          'branch_id': branchId,
          'drug_id': item['id'],
          'transaction_type': 'sale',
          'quantity': item['qty'],
          'total_amount': item['qty'] * item['price'],
          'client_name': _clientController.text.trim(),
          'payment_status': paymentStatus,
          'payment_method': 'MPESA',
          'mpesa_receipt_number': receiptNumber,
        });
      }
      
      setState(() {
        _cart.clear();
        _clientController.clear();
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showInstantPaymentDialog() {
    final TextEditingController receiptCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Instant MPesa Payment', style: TextStyle(color: Colors.white)),
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
              onPressed: () {
                if (receiptCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter Receipt Number')));
                  return;
                }
                Navigator.pop(context);
                _checkout('PAID', receiptCtrl.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
              child: const Text('Submit & Pay'),
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
        title: Text('Telesales POS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Pane: Catalog
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: _filterCatalog,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search Catalog...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                      : ListView.builder(
                          itemCount: _filteredCatalog.length,
                          itemBuilder: (context, index) {
                            final drug = _filteredCatalog[index];
                            return Card(
                              color: const Color(0xFF1E293B),
                              child: ListTile(
                                title: Text(drug['name'], style: const TextStyle(color: Colors.white)),
                                subtitle: Text('Price: \$${drug['price'] ?? 10.0}', style: const TextStyle(color: Colors.white54)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_shopping_cart, color: Colors.tealAccent),
                                  onPressed: () => _addToCart(drug),
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right Pane: Cart
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Active Cart', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _clientController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Client Name',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('Cart is empty', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            itemCount: _cart.length,
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              return Card(
                                color: const Color(0xFF1E293B),
                                child: ListTile(
                                  title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                                  subtitle: Text('Qty: ${item['qty']} x \$${item['price']}', style: const TextStyle(color: Colors.tealAccent)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                    onPressed: () => _removeFromCart(index),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('\$$_cartTotal', style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black, padding: const EdgeInsets.all(16)),
                      onPressed: () => _checkout('PENDING', null),
                      child: const Text('MPesa on Delivery (Invoice)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.all(16)),
                      onPressed: _showInstantPaymentDialog,
                      child: const Text('Instant MPesa Payment'),
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
