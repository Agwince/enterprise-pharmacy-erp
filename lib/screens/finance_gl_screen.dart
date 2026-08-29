import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/accounting_service.dart';
import 'etims_workspace_screen.dart';

/// Finance Hub — Sage-class General Ledger.
/// All balances are computed from real posted journals in Supabase.
class FinanceGlScreen extends StatefulWidget {
  const FinanceGlScreen({super.key});

  @override
  State<FinanceGlScreen> createState() => _FinanceGlScreenState();
}

class _FinanceGlScreenState extends State<FinanceGlScreen>
    with SingleTickerProviderStateMixin {
  final AccountingService _acct = AccountingService();
  final NumberFormat _money = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _compact = NumberFormat('#,##0', 'en_US');

  late TabController _tabs;
  bool _loading = true;
  bool _busy = false;

  List<Map<String, dynamic>> _coa = [];
  List<Map<String, dynamic>> _journals = [];
  List<Map<String, dynamic>> _ledgerRows = [];
  List<Map<String, dynamic>> _unposted = [];
  Map<String, dynamic> _ledger = {};
  Map<String, dynamic> _pl = {};
  Map<String, dynamic> _bs = {};
  Map<String, double> _vat = {'output': 0, 'input': 0, 'payable': 0};
  double _salesRevenue = 0;
  double _insuranceAr = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final coa = await _acct.fetchChartOfAccounts();
      final journals = await _acct.fetchJournals();
      final unposted = await _acct.fetchUnpostedSales();
      final ledger = await _acct.buildLedger();
      final pl = await _acct.incomeStatement(ledger);
      final bs = await _acct.balanceSheet(ledger, pl);
      final vat = await _acct.vatReturn(ledger);

      double sales = 0.0;
      double ar = 0.0;
      try {
        final tx = await Supabase.instance.client
            .from('transactions')
            .select('total_amount, payment_status, amount')
            .eq('transaction_type', 'sale')
            .limit(2000);
        for (final t in (tx as List)) {
          final m = Map<String, dynamic>.from(t as Map);
          final amt = (m['total_amount'] as num?)?.toDouble() ??
              (m['amount'] as num?)?.toDouble() ??
              0.0;
          sales += amt;
          if ((m['payment_status'] ?? '').toString().contains('INSURANCE')) {
            ar += amt;
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _coa = coa;
        _journals = journals;
        _unposted = unposted;
        _ledger = ledger;
        _ledgerRows = (ledger['rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _pl = pl;
        _bs = bs;
        _vat = vat;
        _salesRevenue = sales;
        _insuranceAr = ar;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _seedCoa() async {
    setState(() => _busy = true);
    final n = await _acct.seedChartOfAccounts();
    setState(() => _busy = false);
    _snack(n > 0 ? 'Chart of accounts seeded: $n accounts added' : 'Chart of accounts already up to date');
    await _load();
  }

  Future<void> _postSales() async {
    setState(() => _busy = true);
    try {
      final res = await _acct.postAllUnpostedSales();
      _snack('Posted ${res['posted']} of ${res['total']} real sales to the GL');
    } catch (e) {
      _snack('Posting failed: $e', error: true);
    }
    setState(() => _busy = false);
    await _load();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? Colors.redAccent : Colors.teal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1128),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_rounded,
                  color: Colors.amberAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Finance & General Ledger',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: isDesktop ? 17 : 15,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Sage-class double entry • Live Supabase ledgers',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'KRA eTIMS e-Invoicing',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.tealAccent),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ETIMSWorkspaceScreen()));
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Chart of Accounts'),
            Tab(text: 'Journals'),
            Tab(text: 'Trial Balance'),
            Tab(text: 'Profit & Loss'),
            Tab(text: 'Balance Sheet'),
            Tab(text: 'Sage Sync'),
          ],
        ),
      ),
      body: _acct.schemaMissing
          ? _buildSchemaNotice()
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.amberAccent))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildOverview(isDesktop),
                    _buildCoa(isDesktop),
                    _buildJournals(isDesktop),
                    _buildTrialBalance(isDesktop),
                    _buildProfitLoss(isDesktop),
                    _buildBalanceSheet(isDesktop),
                    _buildSageSync(isDesktop),
                  ],
                ),
    );
  }

  Widget _buildSchemaNotice() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.storage_rounded, color: Colors.amberAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Finance schema not installed',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(
                  'The GL tables (chart_of_accounts, journal_entries, journal_lines) do not exist yet. '
                  'Run the migration in your Supabase SQL Editor, then come back:',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SelectableText(
                    'supabase/migrations/20260829_mediocare_finance_hr.sql',
                    style: TextStyle(
                        color: Colors.tealAccent,
                        fontFamily: 'monospace',
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Re-check database'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // OVERVIEW
  // ==========================================================================
  Widget _buildOverview(bool isDesktop) {
    final revenue = (_pl['revenue'] as double?) ?? 0.0;
    final cogs = (_pl['cogs'] as double?) ?? 0.0;
    final gross = (_pl['gross_profit'] as double?) ?? 0.0;
    final net = (_pl['net_profit'] as double?) ?? 0.0;
    final opex = (_pl['opex'] as double?) ?? 0.0;

    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.amberAccent,
      child: ListView(
        padding: EdgeInsets.all(isDesktop ? 24 : 14),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi('Gross Sales (Live)', 'KES ${_compact.format(_salesRevenue)}',
                  Icons.point_of_sale_rounded, Colors.tealAccent,
                  subtitle: 'transactions table'),
              _kpi('GL Revenue (Net)', 'KES ${_compact.format(revenue)}',
                  Icons.trending_up_rounded, Colors.greenAccent,
                  subtitle: 'posted journals'),
              _kpi('Cost of Sales', 'KES ${_compact.format(cogs)}',
                  Icons.inventory_2_rounded, Colors.orangeAccent,
                  subtitle: 'posted journals'),
              _kpi('Gross Profit', 'KES ${_compact.format(gross)}',
                  Icons.savings_rounded, Colors.cyanAccent,
                  subtitle: 'revenue − COGS'),
              _kpi('Operating Expenses', 'KES ${_compact.format(opex)}',
                  Icons.receipt_long_rounded, Colors.deepOrangeAccent,
                  subtitle: 'posted journals'),
              _kpi('Net Profit', 'KES ${_compact.format(net)}',
                  Icons.account_balance_wallet_rounded,
                  net >= 0 ? Colors.greenAccent : Colors.redAccent,
                  subtitle: 'after opex'),
              _kpi('VAT Payable (KRA)', 'KES ${_compact.format((_vat['payable'] as num?)?.toDouble() ?? 0.0)}',
                  Icons.percent_rounded, Colors.purpleAccent,
                  subtitle: 'output − input @16%'),
              _kpi('Insurance & SHA AR', 'KES ${_compact.format(_insuranceAr)}',
                  Icons.health_and_safety_rounded, Colors.blueAccent,
                  subtitle: 'unsettled claims'),
            ],
          ),
          const SizedBox(height: 18),
          _panel(
            title: 'Ledger Automation',
            icon: Icons.auto_mode_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_unposted.length} real sales are still awaiting GL posting. '
                  'Each posting raises the receipt (M-Pesa / Bank / Debtors / Insurance AR), '
                  'credits net sales and credits KRA VAT output at 16%. COGS is posted '
                  'only where a genuine cost price exists on the drug record.',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _busy || _unposted.isEmpty ? null : _postSales,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text('Post ${_unposted.length} Sales to GL'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _seedCoa,
                      icon: const Icon(Icons.list_alt_rounded, size: 18),
                      label: const Text('Seed / Repair Chart of Accounts'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amberAccent,
                          side: const BorderSide(color: Colors.amberAccent)),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openManualJournal,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Manual Journal'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyanAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _panel(
            title: 'Balance Check',
            icon: Icons.scale_rounded,
            child: Builder(builder: (context) {
              final td = (_ledger['total_debit'] as double?) ?? 0.0;
              final tc = (_ledger['total_credit'] as double?) ?? 0.0;
              final balanced = (td - tc).abs() < 0.01;
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (balanced ? Colors.greenAccent : Colors.redAccent)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      balanced ? Icons.verified_rounded : Icons.warning_rounded,
                      color: balanced ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          balanced
                              ? 'Ledger balances — Dr ${_money.format(td)} = Cr ${_money.format(tc)}'
                              : 'Out of balance by KES ${_money.format((td - tc).abs())}',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_journals.length} journals • ${_ledger['line_count'] ?? 0} lines',
                          style:
                              GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CHART OF ACCOUNTS
  // ==========================================================================
  Widget _buildCoa(bool isDesktop) {
    final types = ['asset', 'liability', 'equity', 'income', 'expense'];
    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Chart of Accounts',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            TextButton.icon(
              onPressed: _openAddAccount,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Account'),
              style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_coa.isEmpty)
          _empty('No accounts found. Tap "Seed Chart of Accounts" on the Overview tab.')
        else
          for (final t in types) ...[
            if (_coa.any((a) => a['type'] == t)) _buildCoaSection(t, isDesktop),
            const SizedBox(height: 14),
          ],
      ],
    );
  }

  Widget _buildCoaSection(String type, bool isDesktop) {
    final rows = _coa.where((a) => a['type'] == type).toList();
    final color = _typeColor(type);
    return _panel(
      title: '${type[0].toUpperCase()}${type.substring(1)}s',
      icon: Icons.account_tree_rounded,
      accent: color,
      child: isDesktop
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white10),
                columns: const [
                  DataColumn(label: Text('Code', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Account', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Category', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Debit', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Credit', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Balance', style: TextStyle(color: Colors.white70))),
                ],
                rows: rows.map((a) {
                  final bal = _balanceFor(a['code'].toString(), type);
                  return DataRow(cells: [
                    DataCell(Text(a['code'].toString(),
                        style: const TextStyle(color: Colors.tealAccent))),
                    DataCell(SizedBox(
                      width: 260,
                      child: Text(a['name'].toString(),
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text((a['category'] ?? '').toString(),
                        style: const TextStyle(color: Colors.white54, fontSize: 11))),
                    DataCell(Text(_money.format(bal['debit']),
                        style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    DataCell(Text(_money.format(bal['credit']),
                        style: const TextStyle(color: Colors.white70, fontSize: 11))),
                    DataCell(Text(_money.format(bal['balance']),
                        style: TextStyle(
                            color: bal['balance']! >= 0 ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11))),
                  ]);
                }).toList(),
              ),
            )
          : Column(
              children: rows.map((a) {
                final bal = _balanceFor(a['code'].toString(), type);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(a['code'].toString(),
                            style: TextStyle(
                                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['name'].toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            Text('Bal KES ${_money.format(bal['balance'])}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Map<String, double> _balanceFor(String code, String type) {
    final row = _ledgerRows.firstWhere(
      (r) => r['code'].toString() == code,
      orElse: () => {'debit': 0.0, 'credit': 0.0, 'type': type},
    );
    final dr = (row['debit'] as double?) ?? 0.0;
    final cr = (row['credit'] as double?) ?? 0.0;
    final bal = (type == 'asset' || type == 'expense') ? dr - cr : cr - dr;
    return {'debit': dr, 'credit': cr, 'balance': bal};
  }

  Color _typeColor(String type) => switch (type) {
        'asset' => Colors.cyanAccent,
        'liability' => Colors.orangeAccent,
        'equity' => Colors.purpleAccent,
        'income' => Colors.greenAccent,
        _ => Colors.redAccent,
      };

  void _openAddAccount() {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String type = 'expense';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setS) {
        return AlertDialog(
          backgroundColor: const Color(0xFF132043),
          title: const Text('New GL Account',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(codeCtrl, 'Account Code (e.g. 6960)'),
              const SizedBox(height: 10),
              _field(nameCtrl, 'Account Name'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                dropdownColor: const Color(0xFF132043),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Type', labelStyle: TextStyle(color: Colors.white54)),
                items: const [
                  DropdownMenuItem(value: 'asset', child: Text('Asset')),
                  DropdownMenuItem(value: 'liability', child: Text('Liability')),
                  DropdownMenuItem(value: 'equity', child: Text('Equity')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                ],
                onChanged: (v) => setS(() => type = v ?? 'expense'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;
                try {
                  await _acct.addAccount(
                      code: codeCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      type: type);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('Account ${codeCtrl.text.trim()} created');
                  await _load();
                } catch (e) {
                  _snack('Failed: $e', error: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      }),
    );
  }

  // ==========================================================================
  // JOURNALS
  // ==========================================================================
  Widget _buildJournals(bool isDesktop) {
    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        Text('Posted Journals',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        if (_journals.isEmpty)
          _empty('No journals posted yet. Use "Post Sales to GL" on the Overview tab.')
        else
          ..._journals.map((j) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(j['entry_no']?.toString() ?? '',
                              style: const TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(j['journal_date']?.toString() ?? '',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 10)),
                        ),
                        Text(
                          'KES ${_money.format((j['total_debit'] as num?)?.toDouble() ?? 0.0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(j['memo']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chip(j['source_module']?.toString() ?? 'manual', Colors.cyanAccent),
                        _chip('Ref ${(j['reference'] ?? '').toString()}',
                            Colors.white38),
                      ],
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  void _openManualJournal() {
    final memoCtrl = TextEditingController();
    final lines = <Map<String, dynamic>>[
      {'code': '6900', 'dr': TextEditingController(), 'cr': TextEditingController()},
      {'code': '1030', 'dr': TextEditingController(), 'cr': TextEditingController()},
    ];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setS) {
        double dr = 0, cr = 0;
        for (final l in lines) {
          dr += double.tryParse((l['dr'] as TextEditingController).text) ?? 0.0;
          cr += double.tryParse((l['cr'] as TextEditingController).text) ?? 0.0;
        }
        final balanced = (dr - cr).abs() < 0.01 && dr > 0;
        return AlertDialog(
          backgroundColor: const Color(0xFF132043),
          title: const Text('Manual Journal Entry',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(memoCtrl, 'Narration'),
              const SizedBox(height: 12),
              ...lines.asMap().entries.map((e) {
                final i = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey(i['code']),
                        initialValue: i['code'] as String,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF132043),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                            labelText: 'Account',
                            labelStyle: TextStyle(color: Colors.white54)),
                        items: _coa
                            .map((a) => DropdownMenuItem<String>(
                                  value: a['code'].toString(),
                                  child: Text('${a['code']} — ${a['name']}',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setS(() => i['code'] = v),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _field(i['dr'] as TextEditingController, 'Debit',
                            numeric: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _field(i['cr'] as TextEditingController, 'Credit',
                            numeric: true)),
                      ]),
                    ]),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => setS(() => lines.add({
                      'code': '6900',
                      'dr': TextEditingController(),
                      'cr': TextEditingController()
                    })),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add line'),
                style: TextButton.styleFrom(foregroundColor: Colors.cyanAccent),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dr ${_money.format(dr)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('Cr ${_money.format(cr)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      balanced ? Colors.tealAccent : Colors.white24,
                  foregroundColor: balanced ? Colors.black : Colors.white54),
              onPressed: balanced
                  ? () async {
                      try {
                        await _acct.postJournal(
                          date: DateTime.now(),
                          memo: memoCtrl.text.trim(),
                          lines: lines
                              .map((l) => JournalLineDraft(
                                    accountCode: l['code'] as String,
                                    debit: double.tryParse(
                                            (l['dr'] as TextEditingController).text) ??
                                        0.0,
                                    credit: double.tryParse(
                                            (l['cr'] as TextEditingController).text) ??
                                        0.0,
                                  ))
                              .toList(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack('Journal posted');
                        await _load();
                      } catch (e) {
                        _snack('Posting failed: $e', error: true);
                      }
                    }
                  : null,
              child: const Text('Post Journal'),
            ),
          ],
        );
      }),
    );
  }

  // ==========================================================================
  // TRIAL BALANCE
  // ==========================================================================
  Widget _buildTrialBalance(bool isDesktop) {
    final rows = _ledgerRows.where((r) {
      final dr = (r['debit'] as double?) ?? 0.0;
      final cr = (r['credit'] as double?) ?? 0.0;
      return dr != 0 || cr != 0;
    }).toList();
    final td = (_ledger['total_debit'] as double?) ?? 0.0;
    final tc = (_ledger['total_credit'] as double?) ?? 0.0;

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Trial Balance',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.tealAccent),
              onPressed: () async {
                final csv = await _acct.trialBalanceCsv();
                _showCsv('Trial Balance (CSV)', csv);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _empty('No movements posted yet.')
        else if (isDesktop)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.white10),
              columns: const [
                DataColumn(label: Text('Code', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Account', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Type', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Debit', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Credit', style: TextStyle(color: Colors.white70))),
              ],
              rows: rows
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r['code'].toString(),
                            style: const TextStyle(color: Colors.tealAccent))),
                        DataCell(SizedBox(
                            width: 240,
                            child: Text(r['name'].toString(),
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis))),
                        DataCell(Text(r['type'].toString(),
                            style: const TextStyle(color: Colors.white54, fontSize: 11))),
                        DataCell(Text(_money.format(r['debit'] ?? 0),
                            style: const TextStyle(color: Colors.white70, fontSize: 11))),
                        DataCell(Text(_money.format(r['credit'] ?? 0),
                            style: const TextStyle(color: Colors.white70, fontSize: 11))),
                      ]))
                  .toList(),
            ),
          )
        else
          ...rows.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['code']} • ${r['name']}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            'Dr ${_money.format(r['debit'] ?? 0)}   Cr ${_money.format(r['credit'] ?? 0)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 14),
        _panel(
          title: 'Totals',
          icon: Icons.summarize_rounded,
          child: Column(
            children: [
              _totalRow('Total Debits', td, Colors.greenAccent),
              const SizedBox(height: 8),
              _totalRow('Total Credits', tc, Colors.orangeAccent),
              const Divider(color: Colors.white12, height: 20),
              _totalRow(
                'Difference',
                td - tc,
                (td - tc).abs() < 0.01 ? Colors.greenAccent : Colors.redAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PROFIT & LOSS
  // ==========================================================================
  Widget _buildProfitLoss(bool isDesktop) {
    final revenueLines =
        ((_pl['revenue_lines'] as List?) ?? []).cast<Map<String, dynamic>>();
    final cogsLines =
        ((_pl['cogs_lines'] as List?) ?? []).cast<Map<String, dynamic>>();
    final opexLines =
        ((_pl['opex_lines'] as List?) ?? []).cast<Map<String, dynamic>>();
    final revenue = (_pl['revenue'] as double?) ?? 0.0;
    final cogs = (_pl['cogs'] as double?) ?? 0.0;
    final gross = (_pl['gross_profit'] as double?) ?? 0.0;
    final opex = (_pl['opex'] as double?) ?? 0.0;
    final net = (_pl['net_profit'] as double?) ?? 0.0;

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        Text('Statement of Profit or Loss',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi('Revenue', 'KES ${_compact.format(revenue)}',
                Icons.trending_up_rounded, Colors.greenAccent),
            _kpi('Cost of Sales', 'KES ${_compact.format(cogs)}',
                Icons.inventory_2_rounded, Colors.orangeAccent),
            _kpi('Gross Profit', 'KES ${_compact.format(gross)}',
                Icons.savings_rounded, Colors.cyanAccent),
            _kpi('Net Profit', 'KES ${_compact.format(net)}',
                Icons.account_balance_wallet_rounded,
                net >= 0 ? Colors.greenAccent : Colors.redAccent),
          ],
        ),
        const SizedBox(height: 16),
        _statementSection('Revenue', revenueLines, Colors.greenAccent, isDesktop),
        const SizedBox(height: 14),
        _statementSection('Cost of Sales', cogsLines, Colors.orangeAccent, isDesktop),
        const SizedBox(height: 14),
        _statementSection('Operating Expenses', opexLines, Colors.redAccent, isDesktop),
        const SizedBox(height: 14),
        _panel(
          title: 'Bottom Line',
          icon: Icons.flag_rounded,
          child: Column(children: [
            _totalRow('Gross Profit', gross, Colors.cyanAccent),
            const SizedBox(height: 8),
            _totalRow('Less Operating Expenses', -opex, Colors.redAccent),
            const Divider(color: Colors.white12, height: 20),
            _totalRow('Net Profit / (Loss)', net,
                net >= 0 ? Colors.greenAccent : Colors.redAccent),
          ]),
        ),
      ],
    );
  }

  Widget _statementSection(
      String title, List<Map<String, dynamic>> lines, Color color, bool isDesktop) {
    return _panel(
      title: title,
      icon: Icons.list_alt_rounded,
      accent: color,
      child: lines.isEmpty
          ? Text('No movements posted to this section yet.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12))
          : Column(
              children: lines.map((l) {
                final bal = AccountingService.signedBalance(l);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5)),
                        child: Text(l['code'].toString(),
                            style: TextStyle(color: color, fontSize: 9)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l['name'].toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('KES ${_money.format(bal)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ==========================================================================
  // BALANCE SHEET
  // ==========================================================================
  Widget _buildBalanceSheet(bool isDesktop) {
    final assetLines =
        ((_bs['asset_lines'] as List?) ?? []).cast<Map<String, dynamic>>();
    final liabLines =
        ((_bs['liability_lines'] as List?) ?? []).cast<Map<String, dynamic>>();
    final equityLines =
        ((_bs['equity_lines'] as List?) ?? []).cast<Map<String, dynamic>>();
    final assets = (_bs['assets'] as double?) ?? 0.0;
    final liabilities = (_bs['liabilities'] as double?) ?? 0.0;
    final equity = (_bs['equity'] as double?) ?? 0.0;
    final retained = (_bs['retained'] as double?) ?? 0.0;

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        Text('Statement of Financial Position',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi('Total Assets', 'KES ${_compact.format(assets)}',
                Icons.account_balance_rounded, Colors.cyanAccent),
            _kpi('Total Liabilities', 'KES ${_compact.format(liabilities)}',
                Icons.credit_card_rounded, Colors.orangeAccent),
            _kpi('Equity', 'KES ${_compact.format(equity)}',
                Icons.pie_chart_rounded, Colors.purpleAccent),
            _kpi('Current Year Result', 'KES ${_compact.format(retained)}',
                Icons.show_chart_rounded,
                retained >= 0 ? Colors.greenAccent : Colors.redAccent),
          ],
        ),
        const SizedBox(height: 16),
        _statementSection('Assets', assetLines, Colors.cyanAccent, isDesktop),
        const SizedBox(height: 14),
        _statementSection('Liabilities', liabLines, Colors.orangeAccent, isDesktop),
        const SizedBox(height: 14),
        _statementSection('Equity', equityLines, Colors.purpleAccent, isDesktop),
        const SizedBox(height: 14),
        _panel(
          title: 'Accounting Equation',
          icon: Icons.balance_rounded,
          child: Column(children: [
            _totalRow('Assets', assets, Colors.cyanAccent),
            const SizedBox(height: 8),
            _totalRow('Liabilities + Equity', liabilities + equity, Colors.purpleAccent),
            const Divider(color: Colors.white12, height: 20),
            _totalRow(
              'Difference',
              assets - (liabilities + equity),
              (assets - (liabilities + equity)).abs() < 0.01
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
            const SizedBox(height: 8),
            Text(
              'Current-year profit of KES ${_money.format(retained)} will be closed to Retained Earnings (3100) at year end.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
            ),
          ]),
        ),
      ],
    );
  }

  // ==========================================================================
  // SAGE SYNC
  // ==========================================================================
  Widget _buildSageSync(bool isDesktop) {
    return ListView(
      padding: EdgeInsets.all(isDesktop ? 24 : 14),
      children: [
        _panel(
          title: 'Sage Integration Bridge',
          icon: Icons.sync_alt_rounded,
          accent: Colors.greenAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mediocare posts every sale, purchase, payroll and insurance movement into its own '
                'double-entry ledger. The bridge below emits Sage-ready import files (journals, '
                'nominal ledger, trial balance) so your accountant can load them straight into '
                'Sage Accounting / Sage Intacct without re-keying.',
                style: GoogleFonts.inter(
                    color: Colors.white70, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final csv = await _acct.sageJournalCsv();
                      _showCsv('Sage Journal Import (CSV)', csv);
                    },
                    icon: const Icon(Icons.description_rounded, size: 18),
                    label: const Text('Generate Sage Journal File'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final csv = await _acct.chartOfAccountsCsv();
                      _showCsv('Sage Nominal Ledger (CSV)', csv);
                    },
                    icon: const Icon(Icons.account_tree_rounded, size: 18),
                    label: const Text('Export Nominal Ledger'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        side: const BorderSide(color: Colors.tealAccent)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final pl = await _acct.incomeStatement();
                      final bs = await _acct.balanceSheet();
                      final vat = await _acct.vatReturn();
                      final buf = StringBuffer()
                        ..writeln('MEDIOCARE PHARMACY ERP - FINANCIAL PACK')
                        ..writeln('Generated, ${DateTime.now().toIso8601String()}')
                        ..writeln()
                        ..writeln('Revenue, ${(pl['revenue'] as double).toStringAsFixed(2)}')
                        ..writeln('Cost of Sales, ${(pl['cogs'] as double).toStringAsFixed(2)}')
                        ..writeln('Gross Profit, ${(pl['gross_profit'] as double).toStringAsFixed(2)}')
                        ..writeln('Operating Expenses, ${(pl['opex'] as double).toStringAsFixed(2)}')
                        ..writeln('Net Profit, ${(pl['net_profit'] as double).toStringAsFixed(2)}')
                        ..writeln('Assets, ${(bs['assets'] as double).toStringAsFixed(2)}')
                        ..writeln('Liabilities, ${(bs['liabilities'] as double).toStringAsFixed(2)}')
                        ..writeln('Equity, ${(bs['equity'] as double).toStringAsFixed(2)}')
                        ..writeln('VAT Output, ${(vat['output'] ?? 0.0).toStringAsFixed(2)}')
                        ..writeln('VAT Input, ${(vat['input'] ?? 0.0).toStringAsFixed(2)}')
                        ..writeln('VAT Payable, ${(vat['payable'] ?? 0.0).toStringAsFixed(2)}');
                      _showCsv('Financial Pack (CSV)', buf.toString());
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Management Accounts Pack'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        side: const BorderSide(color: Colors.amberAccent)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          title: 'KRA VAT Return (derived)',
          icon: Icons.receipt_long_rounded,
          accent: Colors.purpleAccent,
          child: Column(children: [
            _totalRow('Output VAT (16% on sales)', (_vat['output'] as num?)?.toDouble() ?? 0.0, Colors.greenAccent),
            const SizedBox(height: 8),
            _totalRow('Input VAT (recoverable)', (_vat['input'] as num?)?.toDouble() ?? 0.0, Colors.blueAccent),
            const Divider(color: Colors.white12, height: 20),
            _totalRow('VAT Payable to KRA', (_vat['payable'] as num?)?.toDouble() ?? 0.0, Colors.purpleAccent),
            const SizedBox(height: 10),
            Text(
              'Returns are due by the 20th of the following month on KRA iTax.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _panel(
          title: 'Connection Status',
          icon: Icons.cloud_sync_rounded,
          accent: Colors.cyanAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusRow('Supabase ledger', 'Connected', Colors.greenAccent),
              _statusRow('Chart of accounts',
                  '${_coa.length} accounts', Colors.cyanAccent),
              _statusRow('Posted journals', '${_journals.length}', Colors.cyanAccent),
              _statusRow('Awaiting posting', '${_unposted.length} sales',
                  _unposted.isEmpty ? Colors.greenAccent : Colors.orangeAccent),
              _statusRow('Sage live API', 'File export mode (no credentials stored)',
                  Colors.white54),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _showCsv(String title, String csv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132043),
        title: Row(children: [
          const Icon(Icons.description_rounded, color: Colors.tealAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              csv.isEmpty ? '(nothing to export yet)' : csv,
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('CSV copied to clipboard',
                    style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.teal,
                behavior: SnackBarBehavior.floating,
              ));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy CSV'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Shared widgets
  // ==========================================================================
  Widget _kpi(String label, String value, IconData icon, Color color,
      {String? subtitle}) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 240.0;
      return Container(
        width: w > 420 ? (w - 36) / 4 : (w > 260 ? (w - 12) / 2 : w),
        constraints: const BoxConstraints(minWidth: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      );
    });
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
    Color accent = Colors.tealAccent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(icon, color: accent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('KES ${_money.format(value)}',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 9),
          overflow: TextOverflow.ellipsis),
    );
  }

  Widget _empty(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: Colors.white24, size: 38),
          const SizedBox(height: 10),
          Text(msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool numeric = false}) {
    return TextField(
      controller: c,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.tealAccent)),
        isDense: true,
      ),
    );
  }
}
