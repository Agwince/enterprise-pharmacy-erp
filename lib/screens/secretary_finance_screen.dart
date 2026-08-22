import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/glass_container.dart';

class SecretaryFinanceScreen extends StatefulWidget {
  const SecretaryFinanceScreen({super.key});

  @override
  State<SecretaryFinanceScreen> createState() => _SecretaryFinanceScreenState();
}

class _SecretaryFinanceScreenState extends State<SecretaryFinanceScreen> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  
  bool _isLoading = true;
  double _dailyRevenue = 0.0;
  double _dailyPettyCash = 0.0;
  List<Map<String, dynamic>> _ledgerEntries = [];
  
  String _selectedBranch = 'All Branches';
  final List<String> _branches = ['All Branches', 'Nairobi', 'Kisumu'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

      // Fetch daily revenue (could filter by branch too if needed, but the prompt says update imprest_ledger query)
      var txQuery = db.from('transactions')
          .select('total_amount')
          .eq('transaction_type', 'sale')
          .gte('transaction_date', startOfDay);
          
      final txRes = await txQuery;
      
      double rev = 0.0;
      for (var tx in (txRes as List)) {
        rev += (tx['total_amount'] as num).toDouble();
      }

      // Fetch imprest ledger
      var ledgerQuery = db.from('imprest_ledger')
          .select()
          .gte('created_at', startOfDay);
          
      if (_selectedBranch != 'All Branches') {
        ledgerQuery = ledgerQuery.eq('branch', _selectedBranch);
      }
          
      final ledgerRes = await ledgerQuery.order('created_at', ascending: false);
          
      final ledger = ledgerRes as List<dynamic>;
      double spent = 0.0;
      for (var entry in ledger) {
        spent += (entry['amount'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _dailyRevenue = rev;
          _dailyPettyCash = spent;
          _ledgerEntries = List<Map<String, dynamic>>.from(ledger);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitExpense() async {
    if (_descController.text.isEmpty || _amountController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      await Supabase.instance.client.from('imprest_ledger').insert({
        'description': _descController.text,
        'amount': amount,
        'status': 'Approved',
        'branch': _selectedBranch == 'All Branches' ? 'Nairobi' : _selectedBranch, // default to Nairobi if "All Branches" selected for insert
      });
      _descController.clear();
      _amountController.clear();
      await _fetchData();
    } catch (e) {
      debugPrint('Insert error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text('Central HR Global Ledger', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // In this app AuthService().logout() is the canonical way to notify listeners.
              // We'll also invoke that if possible or rely on the stream.
              if (context.mounted) {
                 Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Reconciliation Dashboard', style: GoogleFonts.inter(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          value: _selectedBranch,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
                          underline: Container(height: 1, color: Colors.tealAccent),
                          items: _branches.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedBranch = newValue;
                              });
                              _fetchData();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Daily Revenue', style: GoogleFonts.inter(color: Colors.white70)),
                                const SizedBox(height: 8),
                                Text('KES ${_dailyRevenue.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 24, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Petty Cash Spent', style: GoogleFonts.inter(color: Colors.white70)),
                                const SizedBox(height: 8),
                                Text('KES ${_dailyPettyCash.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 24, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Net Cash on Hand', style: GoogleFonts.inter(color: Colors.white70)),
                                const SizedBox(height: 8),
                                Text('KES ${(_dailyRevenue - _dailyPettyCash).toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 24, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('Record Petty Cash Expense', style: GoogleFonts.inter(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _descController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: _amountController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Amount (KES)', labelStyle: TextStyle(color: Colors.white70), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _submitExpense,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
                            child: Text('Add Expense', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Today\'s Ledger', style: GoogleFonts.inter(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: ListView.builder(
                          itemCount: _ledgerEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _ledgerEntries[index];
                            return ListTile(
                              leading: const Icon(Icons.money_off, color: Colors.orangeAccent),
                              title: Text(entry['description'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                              subtitle: Text('Branch: ${entry['branch']} | Status: ${entry['status']}', style: GoogleFonts.inter(color: Colors.white54)),
                              trailing: Text('- KES ${entry['amount']}', style: GoogleFonts.inter(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                      ),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
