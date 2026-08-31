import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class SecretaryFinanceScreen extends StatefulWidget {
  const SecretaryFinanceScreen({super.key});

  @override
  State<SecretaryFinanceScreen> createState() => _SecretaryFinanceScreenState();
}

class _SecretaryFinanceScreenState extends State<SecretaryFinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  bool _isLoading = true;
  String _errorMessage = '';

  // Branch Scoping
  String _selectedBranchId = '';
  String _selectedBranchName = 'Nairobi';
  String _selectedBranchCode = 'NBO-01';

  // 1. Revenue & POS Totals (Today)
  double _posCashTotal = 0.0;
  double _posMpesaTotal = 0.0;
  double _posCardTotal = 0.0;
  double _posInsuranceTotal = 0.0;
  double _posGrandTotal = 0.0;

  // 2. Cash-Up & EOD Declaration Controllers
  final _declCashController = TextEditingController();
  final _declMpesaController = TextEditingController();
  final _declCardController = TextEditingController();
  final _declNotesController = TextEditingController();
  List<Map<String, dynamic>> _eodDeclarations = [];

  // 3. Banking & Drawer Balance
  final _bankNameController = TextEditingController();
  final _bankSlipController = TextEditingController();
  final _bankAmountController = TextEditingController();
  final _bankDepositorController = TextEditingController();
  final _bankNotesController = TextEditingController();
  List<Map<String, dynamic>> _bankDeposits = [];
  double _totalBankedToday = 0.0;

  // 4. M-Pesa Reconciliation
  List<Map<String, dynamic>> _posMpesaTxList = [];
  List<Map<String, dynamic>> _mpesaStatementList = [];

  // 5. Insurance / SHA Claims
  final _claimPatientController = TextEditingController();
  final _claimInsurerController = TextEditingController();
  final _claimMemberNoController = TextEditingController();
  final _claimPreAuthCodeController = TextEditingController();
  final _claimGrossController = TextEditingController();
  final _claimCoveredController = TextEditingController();
  final _claimCopayController = TextEditingController();
  List<Map<String, dynamic>> _insuranceClaims = [];

  // 6. Supplier Invoice Intake
  final _supplierNameController = TextEditingController();
  final _supplierInvoiceNoController = TextEditingController();
  final _supplierGrnRefController = TextEditingController();
  final _supplierAmountController = TextEditingController();
  final _supplierNotesController = TextEditingController();
  List<Map<String, dynamic>> _supplierInvoices = [];

  // 7. Expense Claims & Imprest Ledger
  final _expenseDescController = TextEditingController();
  final _expenseAmountController = TextEditingController();
  final _expenseCategoryController = TextEditingController(text: 'Branch Operations');
  final _expenseReceiptController = TextEditingController();
  List<Map<String, dynamic>> _expenseLedger = [];
  double _totalExpensesThisMonth = 0.0;
  final double _monthlyBranchBudget = 50000.0;

  // 8. Shift Handover Log
  final _handoverOutgoingController = TextEditingController();
  final _handoverIncomingController = TextEditingController();
  final _handoverFloatController = TextEditingController();
  final _handoverNotesController = TextEditingController();
  List<Map<String, dynamic>> _shiftHandovers = [];

  // 9. eTIMS Register
  List<Map<String, dynamic>> _etimsInvoices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initWorkspace();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _declCashController.dispose();
    _declMpesaController.dispose();
    _declCardController.dispose();
    _declNotesController.dispose();
    _bankNameController.dispose();
    _bankSlipController.dispose();
    _bankAmountController.dispose();
    _bankDepositorController.dispose();
    _bankNotesController.dispose();
    _claimPatientController.dispose();
    _claimInsurerController.dispose();
    _claimMemberNoController.dispose();
    _claimPreAuthCodeController.dispose();
    _claimGrossController.dispose();
    _claimCoveredController.dispose();
    _claimCopayController.dispose();
    _supplierNameController.dispose();
    _supplierInvoiceNoController.dispose();
    _supplierGrnRefController.dispose();
    _supplierAmountController.dispose();
    _supplierNotesController.dispose();
    _expenseDescController.dispose();
    _expenseAmountController.dispose();
    _expenseCategoryController.dispose();
    _expenseReceiptController.dispose();
    _handoverOutgoingController.dispose();
    _handoverIncomingController.dispose();
    _handoverFloatController.dispose();
    _handoverNotesController.dispose();
    super.dispose();
  }

  Future<void> _initWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final db = Supabase.instance.client;

      // 1. Fetch available branches
      final branchRes = await db.from('branches').select('id, name, code, is_active').order('name');
      final branchList = List<Map<String, dynamic>>.from(branchRes as List);

      if (branchList.isNotEmpty) {
        if (_selectedBranchId.isEmpty) {
          // Check if user belongs to a specific branch in staff table
          final userEmail = AuthService().userEmail;
          if (userEmail.isNotEmpty) {
            final staffMatch = await db.from('staff').select('branch_id').eq('email', userEmail).maybeSingle();
            if (staffMatch != null && staffMatch['branch_id'] != null) {
              final matched = branchList.firstWhere(
                (b) => b['id'] == staffMatch['branch_id'],
                orElse: () => branchList.first,
              );
              _selectedBranchId = matched['id'].toString();
              _selectedBranchName = matched['name'].toString();
              _selectedBranchCode = matched['code']?.toString() ?? 'BR';
            }
          }

          // Fallback to first branch
          if (_selectedBranchId.isEmpty) {
            _selectedBranchId = branchList.first['id'].toString();
            _selectedBranchName = branchList.first['name'].toString();
            _selectedBranchCode = branchList.first['code']?.toString() ?? 'BR';
          }
        }
      }

      await _fetchBranchData();
    } catch (e) {
      debugPrint('Secretary Workspace Init Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load branch workspace: $e';
        });
      }
    }
  }

  Future<void> _fetchBranchData() async {
    try {
      final db = Supabase.instance.client;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

      // 1. POS Transactions Today (for this branch)
      final txRes = await db
          .from('transactions')
          .select('id, total_amount, payment_method, mpesa_receipt_number, client_name, transaction_date')
          .eq('transaction_type', 'sale')
          .gte('transaction_date', startOfDay);

      final txList = List<Map<String, dynamic>>.from(txRes as List);
      double cashTot = 0.0;
      double mpesaTot = 0.0;
      double cardTot = 0.0;
      double insTot = 0.0;
      final List<Map<String, dynamic>> mpesaTx = [];

      for (var tx in txList) {
        final amt = (tx['total_amount'] as num?)?.toDouble() ?? 0.0;
        final mode = (tx['payment_method'] ?? '').toString().toUpperCase();
        if (mode.contains('CASH')) {
          cashTot += amt;
        } else if (mode.contains('MPESA') || mode.contains('M-PESA')) {
          mpesaTot += amt;
          mpesaTx.add(tx);
        } else if (mode.contains('CARD')) {
          cardTot += amt;
        } else if (mode.contains('INSURANCE')) {
          insTot += amt;
        } else {
          cashTot += amt; // Default to cash
        }
      }

      // 2. M-Pesa Statement Records
      final mpesaRes = await db
          .from('mpesa_transactions')
          .select()
          .order('amount', ascending: false)
          .limit(20);
      final mpesaStmt = List<Map<String, dynamic>>.from(mpesaRes as List);

      // 3. EOD Declarations
      final eodRes = await db
          .from('eod_declarations')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      final eodList = List<Map<String, dynamic>>.from(eodRes as List);

      // 4. Bank Deposits Today
      final depRes = await db
          .from('branch_bank_deposits')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      final depList = List<Map<String, dynamic>>.from(depRes as List);
      double bankedToday = 0.0;
      for (var dep in depList) {
        final dDate = dep['deposit_date']?.toString() ?? '';
        final isToday = dDate.startsWith(startOfDay.substring(0, 10));
        if (isToday) {
          bankedToday += (dep['amount_deposited'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // 5. Insurance Claims
      final claimRes = await db
          .from('insurance_claims')
          .select()
          .order('created_at', ascending: false)
          .limit(25);
      final claimList = List<Map<String, dynamic>>.from(claimRes as List);

      // 6. Supplier Invoices Intake
      final suppInvRes = await db
          .from('branch_supplier_invoices')
          .select()
          .order('created_at', ascending: false)
          .limit(25);
      final suppInvList = List<Map<String, dynamic>>.from(suppInvRes as List);

      // 7. Imprest Ledger & Expense Claims
      final ledgerRes = await db
          .from('imprest_ledger')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      final ledgerList = List<Map<String, dynamic>>.from(ledgerRes as List);
      double monthExpenses = 0.0;
      for (var item in ledgerList) {
        if (item['status'] != 'Revenue Entry') {
          monthExpenses += (item['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // 8. Shift Handovers
      final handoverRes = await db
          .from('branch_shift_handovers')
          .select()
          .order('created_at', ascending: false)
          .limit(15);
      final handoverList = List<Map<String, dynamic>>.from(handoverRes as List);

      // 9. eTIMS Invoices
      final etimsRes = await db
          .from('etims_invoices')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      final etimsList = List<Map<String, dynamic>>.from(etimsRes as List);

      if (mounted) {
        setState(() {
          _posCashTotal = cashTot;
          _posMpesaTotal = mpesaTot;
          _posCardTotal = cardTot;
          _posInsuranceTotal = insTot;
          _posGrandTotal = cashTot + mpesaTot + cardTot + insTot;
          _posMpesaTxList = mpesaTx;
          _mpesaStatementList = mpesaStmt;
          _eodDeclarations = eodList;
          _bankDeposits = depList;
          _totalBankedToday = bankedToday;
          _insuranceClaims = claimList;
          _supplierInvoices = suppInvList;
          _expenseLedger = ledgerList;
          _totalExpensesThisMonth = monthExpenses;
          _shiftHandovers = handoverList;
          _etimsInvoices = etimsList;
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      debugPrint('Branch Data Fetch Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error querying branch records: $e';
        });
      }
    }
  }

  // --- ACTIONS ---

  Future<void> _submitEodDeclaration() async {
    final declCash = double.tryParse(_declCashController.text.trim()) ?? 0.0;
    final declMpesa = double.tryParse(_declMpesaController.text.trim()) ?? 0.0;
    final declCard = double.tryParse(_declCardController.text.trim()) ?? 0.0;

    if (declCash <= 0 && declMpesa <= 0 && declCard <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one declared payment amount.')),
      );
      return;
    }

    final totalDeclared = declCash + declMpesa + declCard;
    final totalPos = _posCashTotal + _posMpesaTotal + _posCardTotal;
    final variance = totalDeclared - totalPos;

    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      await db.from('eod_declarations').insert({
        'branch': _selectedBranchName,
        'physical_cash': declCash,
        'mpesa_till_balance': declMpesa,
        'card_balance': declCard,
        'pos_cash': _posCashTotal,
        'pos_mpesa': _posMpesaTotal,
        'pos_card': _posCardTotal,
        'variance': variance,
        'status': variance.abs() < 1.0 ? 'Balanced' : (variance < 0 ? 'Shortage' : 'Over'),
      });

      _declCashController.clear();
      _declMpesaController.clear();
      _declCardController.clear();
      _declNotesController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              'End-of-day declaration submitted. Variance: KES ${variance.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      await _fetchBranchData();
    } catch (e) {
      debugPrint('EOD Declaration submit error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving declaration: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _submitBankDeposit() async {
    final amount = double.tryParse(_bankAmountController.text.trim()) ?? 0.0;
    final bankName = _bankNameController.text.trim();
    final slipRef = _bankSlipController.text.trim();
    final depositor = _bankDepositorController.text.trim();

    if (amount <= 0 || bankName.isEmpty || slipRef.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Bank Name, Slip Reference, and Deposit Amount.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      await db.from('branch_bank_deposits').insert({
        'branch_name': _selectedBranchName,
        'bank_name': bankName,
        'slip_reference': slipRef,
        'amount_deposited': amount,
        'deposited_by': depositor.isNotEmpty ? depositor : AuthService().userName,
        'notes': _bankNotesController.text.trim(),
      });

      _bankAmountController.clear();
      _bankNameController.clear();
      _bankSlipController.clear();
      _bankDepositorController.clear();
      _bankNotesController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Bank deposit of KES ${_currencyFormat.format(amount)} recorded successfully.'),
          ),
        );
      }
      await _fetchBranchData();
    } catch (e) {
      debugPrint('Bank deposit error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving deposit: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _submitInsuranceClaim() async {
    final patient = _claimPatientController.text.trim();
    final insurer = _claimInsurerController.text.trim();
    final memberNo = _claimMemberNoController.text.trim();
    final preAuth = _claimPreAuthCodeController.text.trim();
    final gross = double.tryParse(_claimGrossController.text.trim()) ?? 0.0;
    final covered = double.tryParse(_claimCoveredController.text.trim()) ?? 0.0;
    final copay = double.tryParse(_claimCopayController.text.trim()) ?? 0.0;

    if (patient.isEmpty || insurer.isEmpty || gross <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Patient Name, Insurer / SHA, and Gross Amount.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      await db.from('insurance_claims').insert({
        'client_name': patient,
        'insurer': insurer,
        'member_number': memberNo,
        'pre_auth_code': preAuth,
        'gross_amount': gross,
        'covered_amount': covered > 0 ? covered : (gross - copay),
        'copay_amount': copay,
        'claim_status': 'Submitted',
      });

      _claimPatientController.clear();
      _claimInsurerController.clear();
      _claimMemberNoController.clear();
      _claimPreAuthCodeController.clear();
      _claimGrossController.clear();
      _claimCoveredController.clear();
      _claimCopayController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Insurance / SHA claim logged successfully.'),
          ),
        );
      }
      await _fetchBranchData();
    } catch (e) {
      debugPrint('Insurance claim error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging claim: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _submitSupplierInvoice() async {
    final supplierName = _supplierNameController.text.trim();
    final invoiceNo = _supplierInvoiceNoController.text.trim();
    final grnRef = _supplierGrnRefController.text.trim();
    final amount = double.tryParse(_supplierAmountController.text.trim()) ?? 0.0;

    if (supplierName.isEmpty || invoiceNo.isEmpty || grnRef.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Supplier Name, Invoice #, GRN Ref, and Amount.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      await db.from('branch_supplier_invoices').insert({
        'branch_name': _selectedBranchName,
        'supplier_name': supplierName,
        'invoice_number': invoiceNo,
        'grn_reference': grnRef,
        'amount': amount,
        'discrepancy_notes': _supplierNotesController.text.trim(),
        'status': 'Received - Pending Review',
      });

      _supplierNameController.clear();
      _supplierInvoiceNoController.clear();
      _supplierGrnRefController.clear();
      _supplierAmountController.clear();
      _supplierNotesController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Supplier invoice intake recorded (Read-only on GL).'),
          ),
        );
      }
      await _fetchBranchData();
    } catch (e) {
      debugPrint('Supplier invoice error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice intake: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _submitExpenseClaim() async {
    final desc = _expenseDescController.text.trim();
    final amount = double.tryParse(_expenseAmountController.text.trim()) ?? 0.0;
    final cat = _expenseCategoryController.text.trim();

    if (desc.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Description and valid Amount.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      await db.from('imprest_ledger').insert({
        'description': '$desc [$cat]',
        'amount': amount,
        'status': 'Pending Approval',
        'branch': _selectedBranchName,
      });

      _expenseDescController.clear();
      _expenseAmountController.clear();
      _expenseReceiptController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Branch expense submitted for manager approval.'),
          ),
        );
      }
      await _fetchBranchData();
    } catch (e) {
      debugPrint('Expense error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting expense: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _submitShiftHandover() async {
    final outgoing = _handoverOutgoingController.text.trim();
    final incoming = _handoverIncomingController.text.trim();
    final floatAmt = double.tryParse(_handoverFloatController.text.trim()) ?? 0.0;

    if (outgoing.isEmpty || incoming.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Outgoing and Incoming staff names.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = Supabase.instance.client;
      await db.from('branch_shift_handovers').insert({
        'branch_name': _selectedBranchName,
        'outgoing_staff': outgoing,
        'incoming_staff': incoming,
        'float_amount': floatAmt,
        'notes': _handoverNotesController.text.trim(),
        'status': 'Completed',
      });

      _handoverOutgoingController.clear();
      _handoverIncomingController.clear();
      _handoverFloatController.clear();
      _handoverNotesController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Shift float handover recorded successfully.'),
          ),
        );
      }
      await _fetchBranchData();
    } catch (e) {
      debugPrint('Handover error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving handover: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Branch Finance & Secretary Desk',
                    style: GoogleFonts.inter(fontSize: isDesktop ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Scoped to: $_selectedBranchName ($_selectedBranchCode)',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh Desk Records',
            onPressed: _fetchBranchData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () => AuthService().logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isDesktop,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.calculate_rounded, size: 18), text: 'Cash-Up & Variance'),
            Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: 'Banking & Drawer'),
            Tab(icon: Icon(Icons.phone_android_rounded, size: 18), text: 'M-Pesa & Claims'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Expenses & Budget'),
            Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: 'Intake & eTIMS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchBranchData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCashUpVarianceTab(isDesktop),
                    _buildBankingDrawerTab(isDesktop),
                    _buildMpesaAndClaimsTab(isDesktop),
                    _buildExpensesAndBudgetTab(isDesktop),
                    _buildIntakeAndEtimsTab(isDesktop),
                  ],
                ),
    );
  }

  // ===========================================================================
  // TAB 1: CASH-UP VARIANCE & END-OF-DAY DECLARATION
  // ===========================================================================
  Widget _buildCashUpVarianceTab(bool isDesktop) {
    final declCash = double.tryParse(_declCashController.text) ?? 0.0;
    final declMpesa = double.tryParse(_declMpesaController.text) ?? 0.0;
    final declCard = double.tryParse(_declCardController.text) ?? 0.0;

    final cashVar = declCash - _posCashTotal;
    final mpesaVar = declMpesa - _posMpesaTotal;
    final cardVar = declCard - _posCardTotal;
    final netVariance = cashVar + mpesaVar + cardVar;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header summary cards
          Text('Today\'s Live POS Totals vs Declaration', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard('POS Cash Sales', 'KES ${_currencyFormat.format(_posCashTotal)}', 'Drawer Cash', Icons.payments_rounded, Colors.tealAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('POS M-Pesa Sales', 'KES ${_currencyFormat.format(_posMpesaTotal)}', 'Till / Paybill', Icons.phone_android_rounded, Colors.greenAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('POS Card Sales', 'KES ${_currencyFormat.format(_posCardTotal)}', 'PDQ Terminal', Icons.credit_card_rounded, Colors.blueAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Total POS Sales', 'KES ${_currencyFormat.format(_posGrandTotal)}', 'All Channels (Ins: ${_currencyFormat.format(_posInsuranceTotal)})', Icons.point_of_sale_rounded, const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 24),

          // Cash-Up Declaration Card with Live Variance
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('End-of-Day Till Declaration & Variance Check', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: netVariance == 0 ? Colors.tealAccent.withValues(alpha: 0.15) : (netVariance > 0 ? Colors.green.withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        netVariance == 0 ? 'Balanced' : (netVariance > 0 ? 'Over: +KES ${_currencyFormat.format(netVariance)}' : 'Shortage: KES ${_currencyFormat.format(netVariance)}'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: netVariance == 0 ? Colors.tealAccent : (netVariance > 0 ? Colors.greenAccent : Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _declCashController,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Physical Cash Counted (KES)',
                          hintText: '0.00',
                          helperText: 'POS: KES ${_currencyFormat.format(_posCashTotal)} | Diff: ${cashVar >= 0 ? "+" : ""}${_currencyFormat.format(cashVar)}',
                          helperStyle: TextStyle(color: cashVar == 0 ? Colors.white54 : (cashVar > 0 ? Colors.greenAccent : Colors.redAccent)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _declMpesaController,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'M-Pesa Statement Balance (KES)',
                          hintText: '0.00',
                          helperText: 'POS: KES ${_currencyFormat.format(_posMpesaTotal)} | Diff: ${mpesaVar >= 0 ? "+" : ""}${_currencyFormat.format(mpesaVar)}',
                          helperStyle: TextStyle(color: mpesaVar == 0 ? Colors.white54 : (mpesaVar > 0 ? Colors.greenAccent : Colors.redAccent)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _declCardController,
                        onChanged: (_) => setState(() {}),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Card Terminal Totals (KES)',
                          hintText: '0.00',
                          helperText: 'POS: KES ${_currencyFormat.format(_posCardTotal)} | Diff: ${cardVar >= 0 ? "+" : ""}${_currencyFormat.format(cardVar)}',
                          helperStyle: TextStyle(color: cardVar == 0 ? Colors.white54 : (cardVar > 0 ? Colors.greenAccent : Colors.redAccent)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _submitEodDeclaration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text('Record EOD Cash-Up & Variance', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Previous EOD Declarations Table
          Text('Recent Cash-Up Records', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (_eodDeclarations.isEmpty)
            _buildEmptyCard('No previous cash-up declarations recorded.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Date / Time')),
                    DataColumn(label: Text('Branch')),
                    DataColumn(label: Text('Cash Declared')),
                    DataColumn(label: Text('M-Pesa Declared')),
                    DataColumn(label: Text('Card Declared')),
                    DataColumn(label: Text('Variance')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _eodDeclarations.map((d) {
                    final dateStr = (d['created_at'] ?? '').toString();
                    final variance = (d['variance'] as num?)?.toDouble() ?? 0.0;
                    return DataRow(cells: [
                      DataCell(Text(dateStr.length > 16 ? dateStr.substring(0, 16).replaceAll('T', ' ') : dateStr)),
                      DataCell(Text(d['branch'] ?? _selectedBranchName)),
                      DataCell(Text('KES ${_currencyFormat.format(d['physical_cash'] ?? 0)}')),
                      DataCell(Text('KES ${_currencyFormat.format(d['mpesa_till_balance'] ?? 0)}')),
                      DataCell(Text('KES ${_currencyFormat.format(d['card_balance'] ?? 0)}')),
                      DataCell(Text(
                        'KES ${_currencyFormat.format(variance)}',
                        style: TextStyle(
                          color: variance == 0 ? Colors.tealAccent : (variance > 0 ? Colors.greenAccent : Colors.redAccent),
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                      DataCell(Text(d['status'] ?? 'Submitted')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: BANKING & DRAWER RECONCILIATION
  // ===========================================================================
  Widget _buildBankingDrawerTab(bool isDesktop) {
    final drawerRemainingCash = _posCashTotal - _totalBankedToday;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banking summary cards
          Text('Branch Banking & Cash in Drawer Balance', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Today\'s Cash Collected', 'KES ${_currencyFormat.format(_posCashTotal)}', 'POS Sales', Icons.attach_money_rounded, Colors.tealAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Total Banked Today', 'KES ${_currencyFormat.format(_totalBankedToday)}', 'Deposit Slips', Icons.account_balance_rounded, Colors.blueAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Cash in Drawer', 'KES ${_currencyFormat.format(drawerRemainingCash)}', 'Remaining in Branch', Icons.lock_clock_rounded, drawerRemainingCash >= 0 ? const Color(0xFF10B981) : Colors.amberAccent)),
            ],
          ),
          const SizedBox(height: 24),

          // Bank Deposit Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Record Bank Deposit with Deposit Slip', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bankNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          hintText: 'e.g. Equity Bank, KCB, NCBA',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _bankSlipController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Deposit Slip Reference #',
                          hintText: 'e.g. DEP-2026-8891',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _bankAmountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Deposit Amount (KES)',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bankDepositorController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Deposited By (Staff)',
                          hintText: AuthService().userName,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _bankNotesController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Notes / Branch Tag',
                          hintText: 'e.g. Morning cash drop',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submitBankDeposit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text('Save Deposit', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bank Deposits Table
          Text('Branch Bank Deposit History', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (_bankDeposits.isEmpty)
            _buildEmptyCard('No bank deposits recorded yet for this branch.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Bank')),
                    DataColumn(label: Text('Slip Ref')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Deposited By')),
                    DataColumn(label: Text('Notes')),
                  ],
                  rows: _bankDeposits.map((b) {
                    final dDate = (b['deposit_date'] ?? b['created_at'] ?? '').toString();
                    return DataRow(cells: [
                      DataCell(Text(dDate.length >= 10 ? dDate.substring(0, 10) : dDate)),
                      DataCell(Text(b['bank_name'] ?? 'Bank')),
                      DataCell(Text(b['slip_reference'] ?? '-')),
                      DataCell(Text('KES ${_currencyFormat.format(b['amount_deposited'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                      DataCell(Text(b['deposited_by'] ?? '-')),
                      DataCell(Text(b['notes'] ?? '-')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: M-PESA RECONCILIATION & INSURANCE / SHA CLAIMS
  // ===========================================================================
  Widget _buildMpesaAndClaimsTab(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: M-Pesa Reconciliation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('M-Pesa Reconciliation (POS vs Till Statements)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('POS Total: KES ${_currencyFormat.format(_posMpesaTotal)}', style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_posMpesaTxList.isEmpty && _mpesaStatementList.isEmpty)
            _buildEmptyCard('No M-Pesa POS sales or till statement records found today.')
          else ...[
            if (_posMpesaTxList.isNotEmpty) ...[
              Text('POS M-Pesa Sales (${_posMpesaTxList.length} transactions)', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _posMpesaTxList.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final tx = _posMpesaTxList[index];
                    final ref = tx['mpesa_receipt_number'] ?? tx['id'].toString().substring(0, 8);
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFF065F46), child: Icon(Icons.phone_android, color: Colors.greenAccent, size: 18)),
                      title: Text('Receipt Ref: $ref', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                      subtitle: Text('Client: ${tx['client_name'] ?? 'Walk-in'} • Date: ${tx['transaction_date'] ?? 'Today'}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      trailing: Text('KES ${_currencyFormat.format(tx['total_amount'] ?? 0)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ],
            if (_mpesaStatementList.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Till Statement Feeds (${_mpesaStatementList.length} statement records)', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _mpesaStatementList.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final stmt = _mpesaStatementList[index];
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFF1E3A8A), child: Icon(Icons.receipt_rounded, color: Colors.blueAccent, size: 18)),
                      title: Text('Code: ${stmt['transaction_code'] ?? 'MPESA'}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                      subtitle: Text('Status: ${stmt['status'] ?? 'Completed'}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      trailing: Text('KES ${_currencyFormat.format(stmt['amount'] ?? 0)}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ],
          ],
          const SizedBox(height: 32),

          // Section 2: Insurance & SHA Claims
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Insurance & SHA Claims Tracker', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                onPressed: _showAddClaimModal,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Log New Claim', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_insuranceClaims.isEmpty)
            _buildEmptyCard('No insurance / SHA claims logged yet.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Patient / Client')),
                    DataColumn(label: Text('Insurer / SHA')),
                    DataColumn(label: Text('Member #')),
                    DataColumn(label: Text('Pre-Auth')),
                    DataColumn(label: Text('Gross')),
                    DataColumn(label: Text('Covered')),
                    DataColumn(label: Text('Copay')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _insuranceClaims.map((c) {
                    final status = (c['claim_status'] ?? 'Submitted').toString();
                    return DataRow(cells: [
                      DataCell(Text(c['client_name'] ?? 'Patient')),
                      DataCell(Text(c['insurer'] ?? 'SHA')),
                      DataCell(Text(c['member_number'] ?? '-')),
                      DataCell(Text(c['pre_auth_code'] ?? '-')),
                      DataCell(Text('KES ${_currencyFormat.format(c['gross_amount'] ?? 0)}')),
                      DataCell(Text('KES ${_currencyFormat.format(c['covered_amount'] ?? 0)}', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold))),
                      DataCell(Text('KES ${_currencyFormat.format(c['copay_amount'] ?? 0)}')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: status == 'Paid' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(status, style: TextStyle(color: status == 'Paid' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddClaimModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Log Insurance / SHA Claim', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _claimPatientController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Patient Name', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _claimInsurerController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Insurer / Scheme (e.g. SHA, Jubilee, CIC)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _claimMemberNoController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Member / Card #', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _claimPreAuthCodeController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Pre-Authorization Code', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _claimGrossController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Total Bill Amount (KES)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _claimCoveredController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Covered by Insurance (KES)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _claimCopayController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Copay Paid by Patient (KES)', border: OutlineInputBorder())),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(onPressed: _submitInsuranceClaim, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black), child: const Text('Save Claim')),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: EXPENSES & BUDGET
  // ===========================================================================
  Widget _buildExpensesAndBudgetTab(bool isDesktop) {
    final remainingBudget = _monthlyBranchBudget - _totalExpensesThisMonth;
    final budgetUsedPct = (_totalExpensesThisMonth / _monthlyBranchBudget).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget vs Spend Overview (Read-Only)
          Text('Branch Expense Budget vs Actual Spend (Monthly)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Budget Cap', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                        Text('KES ${_currencyFormat.format(_monthlyBranchBudget)}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Spent This Month', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                        Text('KES ${_currencyFormat.format(_totalExpensesThisMonth)}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Remaining Budget', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                        Text('KES ${_currencyFormat.format(remainingBudget)}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: remainingBudget >= 0 ? const Color(0xFF10B981) : Colors.redAccent)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: budgetUsedPct,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      budgetUsedPct > 0.85 ? Colors.redAccent : (budgetUsedPct > 0.65 ? Colors.amberAccent : const Color(0xFF10B981)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(budgetUsedPct * 100).toStringAsFixed(1)}% of monthly budget utilized',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Expense Form
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Submit Branch Expense Claim (Routed to Manager)', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _expenseDescController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Expense Description', hintText: 'e.g. Office cleaning supplies', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _expenseCategoryController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Category', hintText: 'Utilities, Cleaning, Courier', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _expenseAmountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Amount (KES)', hintText: '0.00', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submitExpenseClaim,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                      icon: const Icon(Icons.send_rounded),
                      label: Text('Submit Claim', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Expense Ledger Table
          Text('Branch Imprest & Expense Ledger', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (_expenseLedger.isEmpty)
            _buildEmptyCard('No expense records logged for this branch.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _expenseLedger.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final entry = _expenseLedger[index];
                  final isRevenue = entry['status'] == 'Revenue Entry';
                  final status = entry['status'] ?? 'Pending Approval';
                  return ListTile(
                    leading: Icon(
                      isRevenue ? Icons.trending_up_rounded : Icons.money_off_rounded,
                      color: isRevenue ? const Color(0xFF10B981) : Colors.orangeAccent,
                    ),
                    title: Text(entry['description'] ?? 'Expense', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('Status: $status • Date: ${(entry['created_at'] ?? '').toString().substring(0, 10)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: Text(
                      '${isRevenue ? "+" : "-"} KES ${_currencyFormat.format(entry['amount'] ?? 0)}',
                      style: TextStyle(color: isRevenue ? const Color(0xFF10B981) : Colors.orangeAccent, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 5: INTAKE & eTIMS REGISTER
  // ===========================================================================
  Widget _buildIntakeAndEtimsTab(bool isDesktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Supplier Invoice Intake (Read-only on Ledger)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Supplier Invoice Intake (Branch Level)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                onPressed: _showAddSupplierInvoiceModal,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                icon: const Icon(Icons.inventory_2_rounded, size: 16),
                label: Text('Receive Invoice & GRN', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_supplierInvoices.isEmpty)
            _buildEmptyCard('No supplier invoices received at branch level yet.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Supplier')),
                    DataColumn(label: Text('Invoice #')),
                    DataColumn(label: Text('GRN Ref')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Discrepancy Notes')),
                  ],
                  rows: _supplierInvoices.map((s) {
                    final status = s['status'] ?? 'Received - Pending Review';
                    return DataRow(cells: [
                      DataCell(Text(s['supplier_name'] ?? 'Supplier')),
                      DataCell(Text(s['invoice_number'] ?? '-')),
                      DataCell(Text(s['grn_reference'] ?? '-')),
                      DataCell(Text('KES ${_currencyFormat.format(s['amount'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: status.contains('Discrepancy') ? Colors.redAccent.withValues(alpha: 0.2) : Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(status, style: TextStyle(color: status.contains('Discrepancy') ? Colors.redAccent : Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      )),
                      DataCell(Text(s['discrepancy_notes'] ?? 'None')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 32),

          // Section 2: Shift Handover Log
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shift Float Handover Log', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                onPressed: _showShiftHandoverModal,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text('Record Handover', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_shiftHandovers.isEmpty)
            _buildEmptyCard('No shift handovers recorded yet.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Timestamp')),
                    DataColumn(label: Text('Outgoing Staff')),
                    DataColumn(label: Text('Incoming Staff')),
                    DataColumn(label: Text('Float Amount')),
                    DataColumn(label: Text('Notes')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _shiftHandovers.map((h) {
                    final tStr = (h['created_at'] ?? '').toString();
                    return DataRow(cells: [
                      DataCell(Text(tStr.length > 16 ? tStr.substring(0, 16).replaceAll('T', ' ') : tStr)),
                      DataCell(Text(h['outgoing_staff'] ?? '-')),
                      DataCell(Text(h['incoming_staff'] ?? '-')),
                      DataCell(Text('KES ${_currencyFormat.format(h['float_amount'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
                      DataCell(Text(h['notes'] ?? '-')),
                      DataCell(Text(h['status'] ?? 'Completed')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 32),

          // Section 3: eTIMS Register
          Text('Today\'s eTIMS Fiscal Invoices Register', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          if (_etimsInvoices.isEmpty)
            _buildEmptyCard('No eTIMS fiscal invoices generated today.')
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Invoice #')),
                    DataColumn(label: Text('CU Invoice #')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Gross Total')),
                    DataColumn(label: Text('Tax (16%)')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _etimsInvoices.map((e) {
                    return DataRow(cells: [
                      DataCell(Text(e['invoice_number'] ?? '-')),
                      DataCell(Text(e['cu_invoice_number'] ?? '-')),
                      DataCell(Text(e['customer_name'] ?? 'Walk-in Client')),
                      DataCell(Text('KES ${_currencyFormat.format(e['total_gross'] ?? 0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      DataCell(Text('KES ${_currencyFormat.format(e['total_tax'] ?? 0)}')),
                      const DataCell(Text('Fiscalized', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddSupplierInvoiceModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Receive Supplier Invoice & GRN', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _supplierNameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Supplier Name', hintText: 'e.g. Meds Kenya, Laborex', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _supplierInvoiceNoController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Supplier Invoice Number', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _supplierGrnRefController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Goods Received Note (GRN) Ref', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _supplierAmountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Invoice Total Amount (KES)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _supplierNotesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Discrepancy / Damage Notes', hintText: 'Optional notes for procurement', border: OutlineInputBorder())),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(onPressed: _submitSupplierInvoice, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white), child: const Text('Save Intake')),
        ],
      ),
    );
  }

  void _showShiftHandoverModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Shift Float Handover', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _handoverOutgoingController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Outgoing Cashier / Secretary', hintText: AuthService().userName, border: const OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _handoverIncomingController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Incoming Cashier / Secretary', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _handoverFloatController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Counted Cash Float (KES)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: _handoverNotesController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Handover Notes', hintText: 'e.g. Float balanced, keys handed over', border: OutlineInputBorder())),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(onPressed: _submitShiftHandover, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black), child: const Text('Confirm Handover')),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 11, color: Colors.white60), overflow: TextOverflow.ellipsis)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
