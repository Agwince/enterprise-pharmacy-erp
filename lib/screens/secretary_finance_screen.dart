import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';

class SecretaryFinanceScreen extends StatefulWidget {
  const SecretaryFinanceScreen({super.key});

  @override
  State<SecretaryFinanceScreen> createState() => _SecretaryFinanceScreenState();
}

class _SecretaryFinanceScreenState extends State<SecretaryFinanceScreen> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  
  final _cashController = TextEditingController();
  final _mpesaController = TextEditingController();
  
  final _checkNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _checkAmountController = TextEditingController();

  bool _isLoading = true;
  double _dailyRevenue = 0.0;
  double _dailyPettyCash = 0.0;
  List<Map<String, dynamic>> _ledgerEntries = [];
  
  final List<Map<String, dynamic>> _checksList = [];

  final String _selectedBranch = 'Nairobi';

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

      // Fetch daily revenue from transactions
      final txRes = await db.from('transactions')
          .select('total_amount')
          .eq('transaction_type', 'sale')
          .gte('transaction_date', startOfDay);

      double rev = 0.0;
      for (var tx in (txRes as List)) {
        rev += (tx['total_amount'] as num).toDouble();
      }

      // Fetch imprest ledger (both expenses and revenue entries)
      final ledgerRes = await db.from('imprest_ledger')
          .select()
          .gte('created_at', startOfDay)
          .eq('branch', _selectedBranch)
          .order('created_at', ascending: false);

      final ledger = ledgerRes as List<dynamic>;
      double spent = 0.0;
      for (var entry in ledger) {
        if (entry['status'] != 'Revenue Entry') {
          spent += (entry['amount'] as num).toDouble();
        }
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
        'status': 'Pending',
        'branch': _selectedBranch,
      });
      _descController.clear();
      _amountController.clear();
      await _fetchData();
    } catch (e) {
      debugPrint('Insert error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addCheck() {
    if (_checkNumberController.text.isEmpty || _bankNameController.text.isEmpty || _checkAmountController.text.isEmpty) return;
    final amount = double.tryParse(_checkAmountController.text) ?? 0.0;
    if (amount <= 0) return;
    
    setState(() {
      _checksList.add({
        'checkNumber': _checkNumberController.text,
        'bankName': _bankNameController.text,
        'amount': amount,
      });
      _checkNumberController.clear();
      _bankNameController.clear();
      _checkAmountController.clear();
    });
  }

  Future<void> _submitEodReconciliation() async {
    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final mpesa = double.tryParse(_mpesaController.text) ?? 0.0;
    double checksTotal = _checksList.fold(0.0, (sum, check) => sum + (check['amount'] as double));
    
    final grandTotal = cash + mpesa + checksTotal;
    
    if (grandTotal <= 0) return;

    setState(() => _isLoading = true);
    try {
      // Mock submitting the grand total to imprest_ledger as a Revenue Entry
      await Supabase.instance.client.from('imprest_ledger').insert({
        'description': 'EOD Declaration (Cash: $cash, M-Pesa: $mpesa, Checks: $checksTotal)',
        'amount': grandTotal,
        'status': 'Revenue Entry',
        'branch': _selectedBranch,
      });
      
      _cashController.clear();
      _mpesaController.clear();
      setState(() {
        _checksList.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('EOD Reconciliation of KES ${grandTotal.toStringAsFixed(2)} submitted successfully.', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        );
      }
      await _fetchData();
    } catch (e) {
      debugPrint('EOD submit error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text('Branch Finance Portal', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Summary Cards ---
                          Text('Reconciliation Dashboard', style: GoogleFonts.inter(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
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
                                      Text('KES ${_dailyRevenue.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 22, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
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
                                      Text('KES ${_dailyPettyCash.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 22, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
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
                                      Text('KES ${(_dailyRevenue - _dailyPettyCash).toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 22, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // --- End-of-Day Till Declaration ---
                          Text('End-of-Day Till Declaration', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          GlassContainer(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _cashController,
                                        style: const TextStyle(color: Colors.white),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Physical Cash on Hand (KES)',
                                          labelStyle: TextStyle(color: Colors.white70),
                                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.tealAccent)),
                                          prefixIcon: Icon(Icons.money, color: Colors.tealAccent),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _mpesaController,
                                        style: const TextStyle(color: Colors.white),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'M-Pesa Till Balance (KES)',
                                          labelStyle: TextStyle(color: Colors.white70),
                                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                                          prefixIcon: Icon(Icons.phone_android, color: Colors.greenAccent),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Text('Physical Checks Log', style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _checkNumberController,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(
                                          labelText: 'Check Number',
                                          isDense: true,
                                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _bankNameController,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(
                                          labelText: 'Bank Name',
                                          isDense: true,
                                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _checkAmountController,
                                        style: const TextStyle(color: Colors.white),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Amount (KES)',
                                          isDense: true,
                                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _addCheck,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      child: const Icon(Icons.add, color: Colors.white),
                                    ),
                                  ],
                                ),
                                if (_checksList.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _checksList.length,
                                    itemBuilder: (context, index) {
                                      final check = _checksList[index];
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.account_balance, color: Colors.blueAccent),
                                        title: Text('${check['bankName']} - #${check['checkNumber']}', style: const TextStyle(color: Colors.white)),
                                        trailing: Text('KES ${check['amount']}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                      );
                                    },
                                  ),
                                ],
                                const SizedBox(height: 24),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(
                                    onPressed: _submitEodReconciliation,
                                    icon: const Icon(Icons.upload_rounded, size: 18),
                                    label: Text('Submit EOD Reconciliation', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.tealAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // --- Petty Cash Expense Entry ---
                          Text('Record Petty Cash Expense', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _descController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: 'Description',
                                      labelStyle: TextStyle(color: Colors.white70),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: _amountController,
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Amount (KES)',
                                      labelStyle: TextStyle(color: Colors.white70),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _submitExpense,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text('Add Expense', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orangeAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // --- Today's Ledger ---
                          Text('Today\'s Ledger', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: GlassContainer(
                        padding: const EdgeInsets.all(12),
                        child: ListView.separated(
                          itemCount: _ledgerEntries.length,
                          separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05)),
                          itemBuilder: (context, index) {
                            final entry = _ledgerEntries[index];
                            final isRevenue = entry['status'] == 'Revenue Entry';
                            return ListTile(
                              leading: Icon(
                                isRevenue ? Icons.trending_up_rounded : Icons.money_off_rounded,
                                color: isRevenue ? Colors.tealAccent : Colors.orangeAccent,
                              ),
                              title: Text(
                                entry['description'] ?? '',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Status: ${entry['status']}',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: Text(
                                '${isRevenue ? '+' : '-'} KES ${entry['amount']}',
                                style: GoogleFonts.inter(
                                  color: isRevenue ? Colors.tealAccent : Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
