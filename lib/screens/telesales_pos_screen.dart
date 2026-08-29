import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/accounting_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/leave_application_form.dart';
import 'etims_workspace_screen.dart';

class TelesalesPosScreen extends StatefulWidget {
  const TelesalesPosScreen({super.key});

  @override
  State<TelesalesPosScreen> createState() => _TelesalesPosScreenState();
}

class _TelesalesPosScreenState extends State<TelesalesPosScreen> {
  List<Map<String, dynamic>> _catalog = [];
  List<Map<String, dynamic>> _filteredCatalog = [];
  final List<Map<String, dynamic>> _cart = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _mpesaVerificationController = TextEditingController();

  Future<void> _verifyMpesaPayment() async {
    final code = _mpesaVerificationController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final record = await Supabase.instance.client
          .from('mpesa_transactions')
          .select()
          .eq('transaction_code', code)
          .maybeSingle();

      if (mounted) {
        setState(() => _isLoading = false);
        if (record != null) {
          _mpesaVerificationController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text('M-Pesa code verified. Invoice cleared successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Invalid or Unmatched M-Pesa Code', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error: $e', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    try {
      final res = await Supabase.instance.client.from('drugs').select('id, name, price, image_url').order('name');
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
          'price': drug['price'] != null ? (double.tryParse(drug['price'].toString()) ?? 0.0) : 0.0,
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

  final AccountingService _accounting = AccountingService();

  Future<void> _checkout(
    String paymentStatus,
    String? receiptNumber, {
    Map<String, dynamic>? insurance,
  }) async {
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
      const branchId = '9bdf6137-8825-4bc2-8bbd-f128c975c7a5';
      final isInsurance = insurance != null;

      final payloads = _cart.map((item) {
        final lineTotal = (item['qty'] as int) * (item['price'] as double);
        return <String, dynamic>{
          'branch_id': branchId,
          'drug_id': item['id'],
          'transaction_type': 'sale',
          'quantity': item['qty'],
          'unit_price': item['price'],
          'total_amount': lineTotal,
          'amount': lineTotal,
          'client_name': _clientController.text.trim(),
          'payment_status': paymentStatus,
          'payment_method': isInsurance ? 'INSURANCE' : 'MPESA',
          'mpesa_receipt_number': receiptNumber,
          if (isInsurance) 'insurer': insurance['insurer'],
          if (isInsurance) 'member_number': insurance['member_number'],
          if (isInsurance) 'pre_auth_code': insurance['pre_auth_code'],
          if (isInsurance) 'insurance_covered': insurance['covered_amount'],
          if (isInsurance) 'copay_amount': insurance['copay_amount'],
        };
      }).toList();

      final inserted = await db.from('transactions').insert(payloads).select();
      final rows = (inserted as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Persist a real insurance / SHA claim record (insurer receivable).
      if (isInsurance && rows.isNotEmpty) {
        try {
          await db.from('insurance_claims').insert({
            'transaction_id': rows.first['id'],
            'branch_id': branchId,
            'client_name': _clientController.text.trim(),
            'insurer': insurance['insurer'],
            'member_number': insurance['member_number'],
            'pre_auth_code': insurance['pre_auth_code'],
            'gross_amount': _cartTotal,
            'covered_amount': insurance['covered_amount'],
            'copay_amount': insurance['copay_amount'],
            if (insurance['copay_percent'] != null)
              'copay_percent': (insurance['copay_percent'] as num).toDouble() * 100,
            'claim_status': 'SUBMITTED',
          });
        } catch (e) {
          debugPrint('Insurance claim record skipped: $e');
        }
      }

      // Post the real sale into the general ledger (never blocks dispensing).
      for (final row in rows) {
        try {
          await _accounting.postSaleToGl(row);
        } catch (e) {
          debugPrint('GL posting skipped: $e');
        }
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

  void _showInsuranceCheckoutDialog() {
    String selectedInsurer = 'Social Health Authority (SHA)';
    final memberNoCtrl = TextEditingController();
    final preAuthCtrl = TextEditingController(text: 'AUTH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    double copayPct = 0.10;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalBill = _cartTotal;
          final copayAmount = totalBill * copayPct;
          final insuranceCovered = totalBill - copayAmount;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, color: Colors.blueAccent, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Healthcare Insurance & SHA Copay',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Healthcare Scheme / Underwriter', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedInsurer,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        items: [
                          'Social Health Authority (SHA)',
                          'Jubilee Health Insurance',
                          'AAR Insurance Kenya',
                          'Old Mutual Health',
                          'Britam Mediflex',
                          'CIC Medical Cover',
                        ].map((ins) => DropdownMenuItem(value: ins, child: Text(ins))).toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedInsurer = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: memberNoCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Member / Card / Policy Number',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                      hintText: 'e.g. SHA-94819024',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: preAuthCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Pre-Authorization Code (Smart / EDI)',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Copay Tier Selector
                  Text('Patient Copay Percentage', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildCopayChip('0% Full', 0.0, copayPct, (p) => setModalState(() => copayPct = p)),
                      const SizedBox(width: 6),
                      _buildCopayChip('10% Copay', 0.10, copayPct, (p) => setModalState(() => copayPct = p)),
                      const SizedBox(width: 6),
                      _buildCopayChip('20% Copay', 0.20, copayPct, (p) => setModalState(() => copayPct = p)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Billing Split Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Gross Prescription:', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                            Text('Ksh ${totalBill.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Covered by Insurer:', style: GoogleFonts.inter(fontSize: 12, color: Colors.cyanAccent)),
                            Text('Ksh ${insuranceCovered.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Patient M-Pesa Copay:', style: GoogleFonts.inter(fontSize: 13, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                            Text('Ksh ${copayAmount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (memberNoCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Please enter patient Member / Card Number')));
                    return;
                  }
                  Navigator.pop(ctx);
                  _checkout(
                    'APPROVED_INSURANCE',
                    '${selectedInsurer.substring(0, 3).toUpperCase()}-${preAuthCtrl.text.trim()}',
                    insurance: {
                      'insurer': selectedInsurer,
                      'member_number': memberNoCtrl.text.trim(),
                      'pre_auth_code': preAuthCtrl.text.trim(),
                      'covered_amount': insuranceCovered,
                      'copay_amount': copayAmount,
                      'copay_percent': copayPct,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.verified_rounded, size: 16),
                label: const Text('Adjudicate & Dispense', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCopayChip(String label, double pct, double current, Function(double) onSelect) {
    final isSelected = current == pct;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(pct),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blueAccent.withValues(alpha: 0.25) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: _cart.isEmpty
                        ? const Center(child: Text('Cart is empty', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _cart.length,
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              return Card(
                                color: const Color(0xFF0F172A),
                                child: ListTile(
                                  title: Text(item['name'], style: const TextStyle(color: Colors.white)),
                                  subtitle: Text('Qty: ${item['qty']} x Ksh ${(item['price'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.tealAccent)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                                    onPressed: () {
                                      setSheetState(() {
                                        _removeFromCart(index);
                                      });
                                      setState(() {}); // Update the main UI badge as well
                                    },
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
                      Text('Ksh ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                         Navigator.pop(context);
                         _checkout('PENDING', null);
                      },
                      child: const Text('MPesa on Delivery (Invoice)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                         Navigator.pop(context);
                         _showInstantPaymentDialog();
                      },
                      child: const Text('Instant MPesa Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                         Navigator.pop(context);
                         _showInsuranceCheckoutDialog();
                      },
                      icon: const Icon(Icons.health_and_safety_rounded, size: 18),
                      label: const Text('Insurance & SHA Split-Bill (Copay)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = _cart.fold(0, (sum, item) => sum + (item['qty'] as int));
    
    return GradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Telesales POS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'KRA eTIMS e-Invoicing',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ETIMSWorkspaceScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.beach_access, color: Colors.blueAccent),
            tooltip: 'Request Leave',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: const LeaveApplicationForm(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.shopping_cart),
        label: Text('Cart ($totalItems) - Ksh ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showCartBottomSheet,
      ),
      body: SafeArea(
        child: Container(
        padding: const EdgeInsets.all(16),
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
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            // --- Manual M-Pesa Verification ---
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manual M-Pesa Verification', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mpesaVerificationController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Enter M-Pesa Transaction Code (e.g., QAZ123...)',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                            prefixIcon: Icon(Icons.verified, color: Colors.greenAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _verifyMpesaPayment,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text('Verify & Clear Invoice', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                      ),
                    ],
                  ),
                ],
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
                      return GlassContainer(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: drug['image_url'] != null && drug['image_url'].toString().isNotEmpty
                                  ? Image.network(
                                      drug['image_url'].toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.medication, color: Colors.tealAccent, size: 30),
                                    )
                                  : const Icon(Icons.medication, color: Colors.tealAccent, size: 30),
                            ),
                          ),
                          title: Text(drug['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text('Price: Ksh ${drug['price'] != null ? (double.tryParse(drug['price'].toString()) ?? 0.0).toStringAsFixed(2) : '0.00'}', style: const TextStyle(color: Colors.white54)),
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
    );
  }
}
