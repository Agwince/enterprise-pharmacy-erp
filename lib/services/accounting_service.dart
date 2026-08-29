import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single line on a double-entry journal.
class JournalLineDraft {
  final String accountCode;
  final double debit;
  final double credit;
  final String? lineMemo;
  final String? branchId;

  JournalLineDraft({
    required this.accountCode,
    this.debit = 0.0,
    this.credit = 0.0,
    this.lineMemo,
    this.branchId,
  });

  Map<String, dynamic> toJson() => {
        'account_code': accountCode,
        'debit': debit,
        'credit': credit,
        if (branchId != null) 'branch_id': branchId,
        if (lineMemo != null) 'line_memo': lineMemo,
      };
}

/// Finance & General Ledger engine (Sage-class).
/// Every figure returned here comes from live Supabase tables:
/// transactions -> journal_entries -> journal_lines -> chart_of_accounts.
/// Nothing is simulated: if the schema is absent the service reports
/// [schemaMissing] and the UI shows the migration prompt instead of fake
/// numbers.
class AccountingService {
  final SupabaseClient _db = Supabase.instance.client;

  /// KRA standard VAT rate (Kenya).
  static const double vatRate = 0.16;

  /// GL account codes used by the automated postings.
  static const String accMpesa = '1020';
  static const String accBank = '1030';
  static const String accDebtors = '1200';
  static const String accInsuranceDebtors = '1210';
  static const String accInventory = '1300';
  static const String accVatOutput = '2100';
  static const String accSalesRetail = '4000';
  static const String accSalesWholesale = '4010';
  static const String accSalesInsurance = '4020';
  static const String accCogs = '5000';

  bool _schemaMissing = false;
  bool get schemaMissing => _schemaMissing;

  String? _lastError;
  String? get lastError => _lastError;

  void _capture(Object e) {
    _lastError = e.toString();
    final msg = e.toString().toLowerCase();
    if (msg.contains('42p01') ||
        msg.contains('pgrst205') ||
        msg.contains('could not find the table') ||
        msg.contains('relation "public')) {
      _schemaMissing = true;
    }
    debugPrint('AccountingService: $e');
  }

  // --------------------------------------------------------------------------
  // Chart of accounts
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchChartOfAccounts() async {
    try {
      final res = await _db
          .from('chart_of_accounts')
          .select()
          .order('code');
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  /// Default Kenyan pharmacy chart of accounts (used to seed an empty COA).
  static const List<Map<String, String>> defaultCoa = [
    {'code': '1000', 'name': 'Cash and Cash Equivalents', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1010', 'name': 'Cash in Hand - Till', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1020', 'name': 'M-Pesa Float', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1030', 'name': 'Bank - KCB Current Account', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1040', 'name': 'Bank - Equity Current Account', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1200', 'name': 'Accounts Receivable - Trade Debtors', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1210', 'name': 'Accounts Receivable - Insurance & SHA', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1220', 'name': 'Accounts Receivable - Corporate Credit', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1300', 'name': 'Inventory - Pharmaceutical Stock', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1400', 'name': 'Prepayments, Deposits & Rent Deposits', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '1500', 'name': 'Property, Plant & Equipment', 'type': 'asset', 'category': 'Non-Current Assets'},
    {'code': '1510', 'name': 'Accumulated Depreciation - PPE', 'type': 'asset', 'category': 'Non-Current Assets'},
    {'code': '1600', 'name': 'Motor Vehicles - Distribution Fleet', 'type': 'asset', 'category': 'Non-Current Assets'},
    {'code': '1700', 'name': 'Intangibles - Software & Licences', 'type': 'asset', 'category': 'Non-Current Assets'},
    {'code': '2000', 'name': 'Accounts Payable - Suppliers', 'type': 'liability', 'category': 'Current Liabilities'},
    {'code': '2100', 'name': 'VAT Payable - KRA Output Tax', 'type': 'liability', 'category': 'Current Liabilities'},
    {'code': '2110', 'name': 'VAT Recoverable - KRA Input Tax', 'type': 'asset', 'category': 'Current Assets'},
    {'code': '2200', 'name': 'PAYE Payable - KRA', 'type': 'liability', 'category': 'Current Liabilities'},
    {'code': '2210', 'name': 'NSSF Payable', 'type': 'liability', 'category': 'Current Liabilities'},
    {'code': '2220', 'name': 'SHIF / SHA Contributions Payable', 'type': 'liability', 'category': 'Current Liabilities'},
    {'code': '2230', 'name': 'Affordable Housing Levy Payable', 'type': 'liability', 'category': 'Current Liabilities'},
    {'code': '2300', 'name': 'Accrued Salaries & Wages', 'type': 'liability', 'category': 'Current Liabilities'},
    {'code': '2400', 'name': 'Loans & Borrowings', 'type': 'liability', 'category': 'Non-Current Liabilities'},
    {'code': '2500', 'name': 'Dividends Payable', 'type': 'liability', 'category': 'Current Liabilities'},
    {'code': '3000', 'name': 'Share Capital', 'type': 'equity', 'category': 'Equity'},
    {'code': '3100', 'name': 'Retained Earnings', 'type': 'equity', 'category': 'Equity'},
    {'code': '3200', 'name': 'Current Year Earnings', 'type': 'equity', 'category': 'Equity'},
    {'code': '3300', 'name': 'Directors Drawings', 'type': 'equity', 'category': 'Equity'},
    {'code': '4000', 'name': 'Sales Revenue - Retail Pharmacy', 'type': 'income', 'category': 'Revenue'},
    {'code': '4010', 'name': 'Sales Revenue - Wholesale & Institutional', 'type': 'income', 'category': 'Revenue'},
    {'code': '4020', 'name': 'Sales Revenue - Insurance & SHA', 'type': 'income', 'category': 'Revenue'},
    {'code': '4030', 'name': 'Dispensing & Professional Service Fees', 'type': 'income', 'category': 'Revenue'},
    {'code': '4100', 'name': 'Other Income', 'type': 'income', 'category': 'Revenue'},
    {'code': '4200', 'name': 'Purchase Discounts & Rebates Received', 'type': 'income', 'category': 'Revenue'},
    {'code': '5000', 'name': 'Cost of Goods Sold', 'type': 'expense', 'category': 'Cost of Sales'},
    {'code': '5010', 'name': 'Freight & Inward Logistics', 'type': 'expense', 'category': 'Cost of Sales'},
    {'code': '5020', 'name': 'Inventory Write-off & Expiry Shrinkage', 'type': 'expense', 'category': 'Cost of Sales'},
    {'code': '6000', 'name': 'Salaries & Wages', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6010', 'name': 'Employer Statutory Contributions (NSSF/AHL/WIBA)', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6100', 'name': 'Staff Medical & Welfare', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6200', 'name': 'Rent & Rates', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6210', 'name': 'Electricity, Water & Utilities', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6300', 'name': 'Transport, Fuel & Fleet Running', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6310', 'name': 'Vehicle Maintenance & Insurance', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6400', 'name': 'Marketing & Merchandising', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6500', 'name': 'Licences & Regulatory Fees (PPB/KRA)', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6510', 'name': 'Professional, Audit & Legal Fees', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6600', 'name': 'IT, Software & Connectivity', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6700', 'name': 'Bank & M-Pesa Transaction Charges', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6800', 'name': 'Depreciation Expense', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6900', 'name': 'General Office & Administration', 'type': 'expense', 'category': 'Operating Expenses'},
    {'code': '6950', 'name': 'Security & Cash-in-Transit', 'type': 'expense', 'category': 'Operating Expenses'},
  ];

  /// Inserts the default COA rows that do not yet exist.
  Future<int> seedChartOfAccounts() async {
    try {
      final existing = await fetchChartOfAccounts();
      final have = existing.map((e) => e['code'].toString()).toSet();
      final missing = defaultCoa.where((a) => !have.contains(a['code'])).toList();
      if (missing.isEmpty) return 0;
      await _db.from('chart_of_accounts').insert(missing
          .map((a) => {
                'code': a['code'],
                'name': a['name'],
                'type': a['type'],
                'category': a['category'],
              })
          .toList());
      return missing.length;
    } catch (e) {
      _capture(e);
      return 0;
    }
  }

  Future<void> addAccount({
    required String code,
    required String name,
    required String type,
    String? category,
  }) async {
    await _db.from('chart_of_accounts').insert({
      'code': code,
      'name': name,
      'type': type,
      'category': category ?? 'Operating',
    });
  }

  // --------------------------------------------------------------------------
  // Journal posting
  // --------------------------------------------------------------------------
  Future<String?> postJournal({
    required DateTime date,
    required String memo,
    required List<JournalLineDraft> lines,
    String reference = '',
    String sourceModule = 'manual',
    String? sourceId,
    String? branchId,
    String createdBy = 'System',
  }) async {
    try {
      final res = await _db.rpc('mc_post_journal', params: {
        'p_date': date.toIso8601String().substring(0, 10),
        'p_memo': memo,
        'p_reference': reference,
        'p_source_module': sourceModule,
        'p_source_id': sourceId,
        'p_branch_id': branchId,
        'p_created_by': createdBy,
        'p_lines': lines.map((l) => l.toJson()).toList(),
      });
      return res?.toString();
    } catch (e) {
      _capture(e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchJournals({int limit = 200}) async {
    try {
      final res = await _db
          .from('journal_entries')
          .select()
          .order('journal_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchJournalLines(String journalId) async {
    try {
      final res = await _db
          .from('journal_lines')
          .select()
          .eq('journal_id', journalId)
          .order('debit', ascending: false);
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // Automated posting: real POS / wholesale / insurance sales -> GL
  // --------------------------------------------------------------------------
  /// Returns sales transactions that exist in Supabase but have not yet been
  /// posted to the general ledger.
  Future<List<Map<String, dynamic>>> fetchUnpostedSales({int limit = 500}) async {
    try {
      final res = await _db
          .from('transactions')
          .select()
          .eq('transaction_type', 'sale')
          .eq('gl_posted', false)
          .order('transaction_date', ascending: false)
          .limit(limit);
      return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _capture(e);
      return [];
    }
  }

  /// Posts one real sale into the GL.
  /// VAT is extracted from the gross (Kenya retail prices are VAT inclusive):
  ///   net = gross / 1.16 ; vat = gross - net
  /// COGS is only posted when a real cost price exists on the drug record.
  Future<String?> postSaleToGl(
    Map<String, dynamic> tx, {
    double? costPrice,
  }) async {
    final gross = (tx['total_amount'] as num?)?.toDouble() ??
        (tx['amount'] as num?)?.toDouble() ??
        0.0;
    if (gross <= 0) return null;

    final net = gross / (1 + vatRate);
    final vat = gross - net;

    final method = (tx['payment_method'] ?? '').toString().toUpperCase();
    final status = (tx['payment_status'] ?? '').toString().toUpperCase();
    final isInsurance = status.contains('INSURANCE');

    String receiptAccount = accDebtors;
    if (method.contains('MPESA') || method.contains('M-PESA')) {
      receiptAccount = accMpesa;
    } else if (method.contains('BANK') || method.contains('RTGS') || method.contains('CARD')) {
      receiptAccount = accBank;
    } else if (isInsurance) {
      receiptAccount = accInsuranceDebtors;
    } else if (status == 'PAID') {
      receiptAccount = accMpesa;
    }

    String salesAccount = accSalesRetail;
    final qty = (tx['quantity'] as num?)?.toInt() ?? 0;
    final client = (tx['client_name'] ?? '').toString().toLowerCase();
    final institutional = client.contains('hospital') ||
        client.contains('clinic') ||
        client.contains('medical') ||
        client.contains('pharmacy') ||
        client.contains('health') ||
        client.contains('ltd') ||
        client.contains('limited');
    if (isInsurance) {
      salesAccount = accSalesInsurance;
    } else if (institutional || qty >= 50) {
      salesAccount = accSalesWholesale;
    }

    final branchId = tx['branch_id']?.toString();
    final lines = <JournalLineDraft>[
      JournalLineDraft(
        accountCode: receiptAccount,
        debit: gross,
        lineMemo: 'Receipt ${tx['mpesa_receipt_number'] ?? tx['client_name'] ?? ''}'.trim(),
        branchId: branchId,
      ),
      JournalLineDraft(
        accountCode: salesAccount,
        credit: net,
        lineMemo: 'Net sales',
        branchId: branchId,
      ),
      JournalLineDraft(
        accountCode: accVatOutput,
        credit: vat,
        lineMemo: 'VAT @16% output tax',
        branchId: branchId,
      ),
    ];

    if (costPrice != null && costPrice > 0) {
      final cogs = costPrice * qty;
      lines.add(JournalLineDraft(
        accountCode: accCogs,
        debit: cogs,
        lineMemo: 'Cost of goods sold',
        branchId: branchId,
      ));
      lines.add(JournalLineDraft(
        accountCode: accInventory,
        credit: cogs,
        lineMemo: 'Inventory relief',
        branchId: branchId,
      ));
    }

    final journalId = await postJournal(
      date: DateTime.tryParse(tx['transaction_date']?.toString() ?? '') ?? DateTime.now(),
      memo: 'POS Sale — ${tx['client_name'] ?? 'Walk-in Customer'}',
      reference: tx['id']?.toString().substring(0, 8) ?? '',
      sourceModule: 'pos',
      sourceId: tx['id']?.toString(),
      branchId: branchId,
      lines: lines,
    );

    if (journalId != null) {
      try {
        await _db.from('transactions').update({
          'gl_posted': true,
          'gl_journal_id': journalId,
          'vat_amount': vat,
          if (costPrice != null) 'cost_amount': costPrice * qty,
          if (costPrice != null) 'gross_profit': net - (costPrice * qty),
        }).eq('id', tx['id']);
      } catch (_) {}
    }
    return journalId;
  }

  /// Batch-posts every unposted real sale. Returns counts for the UI.
  Future<Map<String, dynamic>> postAllUnpostedSales() async {
    final sales = await fetchUnpostedSales();
    int posted = 0;
    int skipped = 0;
    final List<String> errors = [];

    // Cache drug costs (only real cost prices are used for COGS).
    final Map<String, double> costCache = {};
    try {
      final drugs = await _db.from('drugs').select('id, price');
      for (final d in (drugs as List)) {
        final m = Map<String, dynamic>.from(d as Map);
        final v = m['price'];
        if (v != null) costCache[m['id'].toString()] = double.tryParse(v.toString()) ?? 0.0;
      }
    } catch (_) {}

    for (final tx in sales) {
      try {
        final drugId = tx['drug_id']?.toString();
        double? cost;
        if (drugId != null) {
          // 'price' on drugs is the selling price; use it only if a true cost
          // column exists on the schema, otherwise COGS is left unposted.
          final c = costCache[drugId];
          if (c != null && c > 0) cost = null; // selling price != cost: do not invent COGS
        }
        final id = await postSaleToGl(tx, costPrice: cost);
        if (id != null) {
          posted++;
        } else {
          skipped++;
        }
      } catch (e) {
        errors.add('${tx['id']}: $e');
        skipped++;
      }
    }
    return {'posted': posted, 'skipped': skipped, 'total': sales.length, 'errors': errors};
  }

  // --------------------------------------------------------------------------
  // Reporting: trial balance, P&L, balance sheet
  // --------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _allLines() async {
    final res = await _db
        .from('journal_lines')
        .select('journal_id, account_code, debit, credit, branch_id');
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> buildLedger() async {
    final accounts = await fetchChartOfAccounts();
    final journals = await fetchJournals(limit: 1000);
    final List<Map<String, dynamic>> lines = [];
    try {
      lines.addAll(await _allLines());
    } catch (e) {
      _capture(e);
    }

    final jDates = <String, String>{};
    for (final j in journals) {
      jDates[j['id'].toString()] = (j['journal_date'] ?? '').toString();
    }

    final Map<String, Map<String, dynamic>> accMap = {
      for (final a in accounts)
        a['code'].toString(): {
          'code': a['code'].toString(),
          'name': a['name'].toString(),
          'type': a['type'].toString(),
          'category': (a['category'] ?? '').toString(),
          'debit': 0.0,
          'credit': 0.0,
        }
    };

    for (final l in lines) {
      final code = l['account_code'].toString();
      final acc = accMap.putIfAbsent(
        code,
        () => {'code': code, 'name': code, 'type': 'expense', 'category': 'Unmapped', 'debit': 0.0, 'credit': 0.0},
      );
      acc['debit'] = (acc['debit'] as double) + ((l['debit'] as num?)?.toDouble() ?? 0.0);
      acc['credit'] = (acc['credit'] as double) + ((l['credit'] as num?)?.toDouble() ?? 0.0);
    }

    final rows = accMap.values.toList()
      ..sort((a, b) => a['code'].toString().compareTo(b['code'].toString()));

    double totalDebit = 0.0, totalCredit = 0.0;
    for (final r in rows) {
      totalDebit += (r['debit'] as num?)?.toDouble() ?? 0.0;
      totalCredit += (r['credit'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'rows': rows,
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'journal_count': journals.length,
      'line_count': lines.length,
      'journals': journals,
      'journal_dates': jDates,
    };
  }

  /// Signed balance per account, signed the way the account type expects.
  static double signedBalance(Map<String, dynamic> row) {
    final dr = (row['debit'] as num?)?.toDouble() ?? 0.0;
    final cr = (row['credit'] as num?)?.toDouble() ?? 0.0;
    final type = row['type'].toString();
    if (type == 'asset' || type == 'expense') return dr - cr;
    return cr - dr;
  }

  Future<Map<String, dynamic>> incomeStatement([Map<String, dynamic>? prebuiltLedger]) async {
    final ledger = prebuiltLedger ?? await buildLedger();
    final rows = (ledger['rows'] as List).cast<Map<String, dynamic>>();
    double revenue = 0.0, cogs = 0.0, opex = 0.0;
    final List<Map<String, dynamic>> revenueLines = [], cogsLines = [], opexLines = [];
    for (final r in rows) {
      final bal = signedBalance(r);
      final code = r['code'].toString();
      if (r['type'] == 'income') {
        revenue += bal;
        revenueLines.add(r);
      } else if (r['type'] == 'expense') {
        if (code.startsWith('50')) {
          cogs += bal;
          cogsLines.add(r);
        } else {
          opex += bal;
          opexLines.add(r);
        }
      }
    }
    final grossProfit = revenue - cogs;
    return {
      'revenue': revenue,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'opex': opex,
      'net_profit': grossProfit - opex,
      'revenue_lines': revenueLines,
      'cogs_lines': cogsLines,
      'opex_lines': opexLines,
    };
  }

  Future<Map<String, dynamic>> balanceSheet([
    Map<String, dynamic>? prebuiltLedger,
    Map<String, dynamic>? prebuiltPl,
  ]) async {
    final ledger = prebuiltLedger ?? await buildLedger();
    final pl = prebuiltPl ?? await incomeStatement(ledger);
    final rows = (ledger['rows'] as List).cast<Map<String, dynamic>>();
    double assets = 0.0, liabilities = 0.0, equity = 0.0;
    final List<Map<String, dynamic>> assetLines = [], liabLines = [], equityLines = [];
    for (final r in rows) {
      final bal = signedBalance(r);
      if (r['type'] == 'asset') {
        assets += bal;
        assetLines.add(r);
      } else if (r['type'] == 'liability') {
        liabilities += bal;
        liabLines.add(r);
      } else if (r['type'] == 'equity') {
        equity += bal;
        equityLines.add(r);
      }
    }
    return {
      'assets': assets,
      'liabilities': liabilities,
      'equity': equity,
      'retained': (pl['net_profit'] as num?)?.toDouble() ?? 0.0,
      'asset_lines': assetLines,
      'liability_lines': liabLines,
      'equity_lines': equityLines,
    };
  }

  // --------------------------------------------------------------------------
  // Sage / Excel export helpers
  // --------------------------------------------------------------------------
  String _csv(List<String> headers, List<List<dynamic>> rows) {
    final buf = StringBuffer();
    buf.writeln(headers.map(_esc).join(','));
    for (final r in rows) {
      buf.writeln(r.map((c) => _esc(c.toString())).join(','));
    }
    return buf.toString();
  }

  String _esc(String v) => '"${v.replaceAll('"', '""')}"';

  /// Sage-compatible journal import file (Date, Reference, Memo, Account, Debit, Credit).
  Future<String> sageJournalCsv() async {
    final journals = await fetchJournals(limit: 500);
    final rows = <List<dynamic>>[];
    for (final j in journals) {
      final lines = await fetchJournalLines(j['id'].toString());
      for (final l in lines) {
        final dr = (l['debit'] as num?)?.toDouble() ?? 0.0;
        final cr = (l['credit'] as num?)?.toDouble() ?? 0.0;
        if (dr == 0 && cr == 0) continue;
        rows.add([
          (j['journal_date'] ?? '').toString(),
          j['entry_no'] ?? '',
          j['reference'] ?? '',
          j['memo'] ?? '',
          l['account_code'] ?? '',
          dr.toStringAsFixed(2),
          cr.toStringAsFixed(2),
        ]);
      }
    }
    return _csv(
      ['Date', 'EntryNo', 'Reference', 'Memo', 'AccountCode', 'Debit', 'Credit'],
      rows,
    );
  }

  Future<String> chartOfAccountsCsv() async {
    final accounts = await fetchChartOfAccounts();
    return _csv(
      ['Code', 'Name', 'Type', 'Category'],
      accounts
          .map((a) => [a['code'], a['name'], a['type'], a['category'] ?? ''])
          .toList(),
    );
  }

  Future<String> trialBalanceCsv() async {
    final ledger = await buildLedger();
    final rows = (ledger['rows'] as List).cast<Map<String, dynamic>>();
    final data = rows
        .map((r) => [
              r['code'],
              r['name'],
              (r['debit'] as double).toStringAsFixed(2),
              (r['credit'] as double).toStringAsFixed(2),
              signedBalance(r).toStringAsFixed(2),
            ])
        .toList();
    data.add([
      'TOTAL',
      '',
      (ledger['total_debit'] as double).toStringAsFixed(2),
      (ledger['total_credit'] as double).toStringAsFixed(2),
      ''
    ]);
    return _csv(['Code', 'Account', 'Debit', 'Credit', 'Balance'], data);
  }

  /// KRA VAT 3 style return derived from posted journals.
  Future<Map<String, double>> vatReturn([Map<String, dynamic>? prebuiltLedger]) async {
    final ledger = prebuiltLedger ?? await buildLedger();
    final rows = (ledger['rows'] as List).cast<Map<String, dynamic>>();
    double output = 0.0, input = 0.0;
    for (final r in rows) {
      final code = r['code'].toString();
      if (code == accVatOutput) output += signedBalance(r);
      if (code == '2110') input += signedBalance(r);
    }
    return {'output': output, 'input': input, 'payable': output - input};
  }
}
