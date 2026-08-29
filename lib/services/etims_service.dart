import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/etims_invoice.dart';

class ETIMSService extends ChangeNotifier {
  final SupabaseClient? _client;

  bool _loading = false;
  bool _schemaMissing = false;
  String? _error;

  List<ETIMSInvoice> _invoices = [];
  List<ETIMSZReport> _zReports = [];
  List<TillReconciliationSession> _tillSessions = [];
  List<BranchKraConfig> _kraConfigs = [];

  String _selectedBranch = 'Nairobi HQ';
  String _selectedBranchId = 'nbo-hq-001';

  final List<Map<String, String>> branches = [
    {'name': 'Nairobi HQ', 'id': 'nbo-hq-001'},
    {'name': 'Kisumu Bulk Hub', 'id': 'ksm-hub-002'},
    {'name': 'Mombasa Coastal Depot', 'id': 'mba-cst-003'},
    {'name': 'Eldoret Transit', 'id': 'eld-trn-004'},
  ];

  ETIMSService({SupabaseClient? client})
      : _client = client ?? (Supabase.instance.isInitialized ? Supabase.instance.client : null) {
    _initData();
  }

  bool get loading => _loading;
  bool get schemaMissing => _schemaMissing;
  String? get error => _error;
  List<ETIMSInvoice> get invoices => _invoices;
  List<ETIMSZReport> get zReports => _zReports;
  List<TillReconciliationSession> get tillSessions => _tillSessions;
  List<BranchKraConfig> get kraConfigs => _kraConfigs;
  String get selectedBranch => _selectedBranch;
  String get selectedBranchId => _selectedBranchId;

  /// Retrieves the registered KRA device config for the currently active branch.
  /// Returns null if no real KRA device/machine configuration is registered in database.
  BranchKraConfig? get currentBranchConfig {
    final idx = _kraConfigs.indexWhere((c) => c.branchId == _selectedBranchId || c.branchName == _selectedBranch);
    if (idx != -1) return _kraConfigs[idx];
    return null;
  }

  bool get isCurrentBranchConfigured => currentBranchConfig != null;

  void setSelectedBranch(String branchName) {
    final b = branches.firstWhere((e) => e['name'] == branchName, orElse: () => branches.first);
    _selectedBranch = b['name']!;
    _selectedBranchId = b['id']!;
    notifyListeners();
  }

  Future<void> _initData() async {
    _loading = true;
    notifyListeners();

    try {
      if (_client != null) {
        // 1. Load real branch KRA configurations
        try {
          final cfgRes = await _client.from('branch_kra_config').select().eq('is_active', true);
          _kraConfigs = (cfgRes as List).map((r) => BranchKraConfig.fromJson(Map<String, dynamic>.from(r as Map))).toList();
        } catch (_) {
          _kraConfigs = [];
        }

        // 2. Load live invoices from Supabase
        try {
          final res = await _client.from('etims_invoices').select().order('date_time', ascending: false).limit(100);
          _invoices = (res as List).map((r) => ETIMSInvoice.fromJson(Map<String, dynamic>.from(r as Map))).toList();
          _schemaMissing = false;
        } catch (_) {
          _invoices = [];
          _schemaMissing = true;
        }

        // 3. Load Z-reports
        try {
          final zRes = await _client.from('etims_z_reports').select().order('date', ascending: false).limit(50);
          _zReports = (zRes as List).map((r) {
            final map = Map<String, dynamic>.from(r as Map);
            return ETIMSZReport(
              zReportNumber: map['z_report_number']?.toString() ?? '',
              date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
              branchName: map['branch_name']?.toString() ?? 'Nairobi HQ',
              branchId: map['branch_id']?.toString() ?? '',
              cuSerialNumber: map['cu_serial_number']?.toString() ?? '',
              startInvoiceNumber: map['start_invoice_number']?.toString() ?? '',
              endInvoiceNumber: map['end_invoice_number']?.toString() ?? '',
              totalInvoices: (map['total_invoices'] as num?)?.toInt() ?? 0,
              grossSales: (map['gross_sales'] as num?)?.toDouble() ?? 0.0,
              netSales: (map['net_sales'] as num?)?.toDouble() ?? 0.0,
              taxCodeASales: (map['tax_code_a_sales'] as num?)?.toDouble() ?? 0.0,
              taxCodeBSales: (map['tax_code_b_sales'] as num?)?.toDouble() ?? 0.0,
              taxCodeBTax: (map['tax_code_b_tax'] as num?)?.toDouble() ?? 0.0,
              taxCodeCSales: (map['tax_code_c_sales'] as num?)?.toDouble() ?? 0.0,
              taxCodeDSales: (map['tax_code_d_sales'] as num?)?.toDouble() ?? 0.0,
              taxCodeESales: (map['tax_code_e_sales'] as num?)?.toDouble() ?? 0.0,
              taxCodeETax: (map['tax_code_e_tax'] as num?)?.toDouble() ?? 0.0,
              totalTax: (map['total_tax'] as num?)?.toDouble() ?? 0.0,
              paymentBreakdown: Map<String, double>.from(
                  (map['payment_breakdown'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
              generatedAt: DateTime.tryParse(map['generated_at']?.toString() ?? '') ?? DateTime.now(),
              supervisorSignOff: map['supervisor_sign_off']?.toString() ?? '',
            );
          }).toList();
        } catch (_) {
          _zReports = [];
        }

        // 4. Load Till Sessions
        try {
          final tRes = await _client.from('branch_till_sessions').select().order('shift_start', ascending: false).limit(50);
          _tillSessions = (tRes as List).map((r) {
            final map = Map<String, dynamic>.from(r as Map);
            return TillReconciliationSession(
              sessionId: map['session_id']?.toString() ?? '',
              branchName: map['branch_name']?.toString() ?? '',
              branchId: map['branch_id']?.toString() ?? '',
              cashierName: map['cashier_name']?.toString() ?? '',
              shiftStart: DateTime.tryParse(map['shift_start']?.toString() ?? '') ?? DateTime.now(),
              shiftEnd: DateTime.tryParse(map['shift_end']?.toString() ?? ''),
              openingFloat: (map['opening_float'] as num?)?.toDouble() ?? 0.0,
              cashSales: (map['cash_sales'] as num?)?.toDouble() ?? 0.0,
              mpesaSales: (map['mpesa_sales'] as num?)?.toDouble() ?? 0.0,
              cardSales: (map['card_sales'] as num?)?.toDouble() ?? 0.0,
              insuranceSales: (map['insurance_sales'] as num?)?.toDouble() ?? 0.0,
              pettyCashPayouts: (map['petty_cash_payouts'] as num?)?.toDouble() ?? 0.0,
              actualCashInDrawer: (map['actual_cash_in_drawer'] as num?)?.toDouble() ?? 0.0,
              status: map['status']?.toString() ?? 'OPEN',
              managerNotes: map['manager_notes']?.toString(),
            );
          }).toList();
        } catch (_) {
          _tillSessions = [];
        }
      } else {
        // Pure empty state fallback without generating fake data
        _schemaMissing = true;
        _invoices = [];
        _zReports = [];
        _tillSessions = [];
        _kraConfigs = [];
      }
    } catch (e) {
      _error = e.toString();
      _invoices = [];
      _zReports = [];
      _tillSessions = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Create and register an eTIMS Invoice with local integrity hash
  Future<ETIMSInvoice> generateInvoice({
    required List<ETIMSLineItem> items,
    required String branchName,
    required String branchId,
    String customerName = 'Walk-in Customer',
    String? customerPin,
    String paymentMode = 'M-Pesa',
    String paymentReference = '',
    String cashierName = 'Cashier 01',
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final count = _invoices.where((i) => DateFormat('yyyyMMdd').format(i.dateTime) == dateStr).length + 1;
    final invoiceNo = 'MED-INV-$dateStr-${count.toString().padLeft(3, '0')}';

    final cfg = currentBranchConfig;
    final kraPin = cfg?.kraPin.isNotEmpty == true ? cfg!.kraPin : 'PENDING-KRA-CONFIG';
    final cuSerial = cfg?.machineNumber.isNotEmpty == true ? cfg!.machineNumber : 'UNCONFIGURED-DEVICE';
    final cuInvoiceNo = '${cuSerial.replaceAll("-", "")}${count.toString().padLeft(4, '0')}';

    final totalGross = items.fold(0.0, (sum, i) => sum + i.grossTotal);
    final totalTax = items.fold(0.0, (sum, i) => sum + i.taxAmount);

    final localHash = ETIMSInvoice.computeLocalIntegrityHash(
      kraPin: kraPin,
      cuSerial: cuSerial,
      invoiceNo: invoiceNo,
      dateTime: now,
      totalGross: totalGross,
      totalTax: totalTax,
    );

    final verificationUrl = ETIMSInvoice.buildVerificationUrl(
      kraPin: kraPin,
      cuSerial: cuSerial,
      invoiceNo: invoiceNo,
      totalGross: totalGross,
      signature: localHash,
    );

    final invoice = ETIMSInvoice(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: invoiceNo,
      cuInvoiceNumber: cuInvoiceNo,
      cuSerialNumber: cuSerial,
      kraPin: kraPin,
      traderName: 'Mediocare Pharmacy Ltd',
      branchName: branchName,
      branchId: branchId,
      customerName: customerName,
      customerPin: customerPin?.trim().isEmpty == true ? null : customerPin?.trim(),
      dateTime: now,
      items: items,
      paymentMode: paymentMode,
      paymentReference: paymentReference,
      cashierName: cashierName,
      localIntegrityHash: localHash,
      cuSignature: null, // Left null until signed by real physical VSCU/OSCU device
      verificationUrl: verificationUrl,
    );

    _invoices.insert(0, invoice);

    if (_client != null && !_schemaMissing) {
      try {
        await _client.from('etims_invoices').insert(invoice.toJson());
      } catch (e) {
        debugPrint('eTIMS Supabase insert note: $e');
      }
    }

    notifyListeners();
    return invoice;
  }

  /// Generate and finalize a Daily Z-Report for a specific branch & date
  Future<ETIMSZReport> generateDailyZReport({
    required String branchName,
    required String branchId,
    required DateTime date,
    required String supervisorName,
  }) async {
    final dateFormatted = DateFormat('yyyy-MM-dd').format(date);
    final branchInvoices = _invoices.where((i) {
      final iDate = DateFormat('yyyy-MM-dd').format(i.dateTime);
      return iDate == dateFormatted && i.branchName == branchName;
    }).toList();

    final zCount = _zReports.length + 1;
    final zReportNumber = 'Z-REP-${DateFormat("yyyyMMdd").format(date)}-${zCount.toString().padLeft(3, '0')}';

    double grossSales = 0.0;
    double netSales = 0.0;
    double taxCodeASales = 0.0; // Exempt
    double taxCodeBSales = 0.0; // 16% Taxable
    double taxCodeBTax = 0.0;   // 16% Tax
    double taxCodeCSales = 0.0; // Zero-rated
    double taxCodeDSales = 0.0; // Non-VAT
    double taxCodeESales = 0.0; // 8% Reduced
    double taxCodeETax = 0.0;   // 8% Tax
    double totalTax = 0.0;

    final Map<String, double> paymentBreakdown = {
      'Cash': 0.0,
      'M-Pesa': 0.0,
      'Card': 0.0,
      'Insurance': 0.0,
      'Credit': 0.0,
    };

    String startInv = 'N/A';
    String endInv = 'N/A';

    if (branchInvoices.isNotEmpty) {
      startInv = branchInvoices.last.invoiceNumber;
      endInv = branchInvoices.first.invoiceNumber;

      for (final inv in branchInvoices) {
        grossSales += inv.totalGross;
        netSales += inv.totalNet;
        taxCodeASales += inv.totalTaxableA;
        taxCodeBSales += inv.totalTaxableB;
        taxCodeBTax += inv.totalTaxB;
        taxCodeCSales += inv.totalTaxableC;
        taxCodeDSales += inv.totalTaxableD;
        taxCodeESales += inv.totalTaxableE;
        taxCodeETax += inv.totalTaxE;
        totalTax += inv.totalTax;

        final mode = inv.paymentMode;
        paymentBreakdown[mode] = (paymentBreakdown[mode] ?? 0.0) + inv.totalGross;
      }
    }

    final cfg = currentBranchConfig;
    final cuSerial = cfg?.machineNumber.isNotEmpty == true ? cfg!.machineNumber : 'UNCONFIGURED-DEVICE';

    final zReport = ETIMSZReport(
      zReportNumber: zReportNumber,
      date: date,
      branchName: branchName,
      branchId: branchId,
      cuSerialNumber: cuSerial,
      startInvoiceNumber: startInv,
      endInvoiceNumber: endInv,
      totalInvoices: branchInvoices.length,
      grossSales: grossSales,
      netSales: netSales,
      taxCodeASales: taxCodeASales,
      taxCodeBSales: taxCodeBSales,
      taxCodeBTax: taxCodeBTax,
      taxCodeCSales: taxCodeCSales,
      taxCodeDSales: taxCodeDSales,
      taxCodeESales: taxCodeESales,
      taxCodeETax: taxCodeETax,
      totalTax: totalTax,
      paymentBreakdown: paymentBreakdown,
      generatedAt: DateTime.now(),
      supervisorSignOff: supervisorName,
    );

    _zReports.insert(0, zReport);

    if (_client != null && !_schemaMissing) {
      try {
        await _client.from('etims_z_reports').insert(zReport.toJson());
      } catch (e) {
        debugPrint('eTIMS Z-Report Supabase insert note: $e');
      }
    }

    notifyListeners();
    return zReport;
  }

  /// Perform Branch Till & Cash Drawer Reconciliation
  Future<TillReconciliationSession> reconcileTillSession({
    required String branchName,
    required String branchId,
    required String cashierName,
    required double openingFloat,
    required double cashSales,
    required double mpesaSales,
    required double cardSales,
    required double insuranceSales,
    required double pettyCashPayouts,
    required double actualCashInDrawer,
    String? managerNotes,
  }) async {
    final sessionId = 'TILL-${branchId.toUpperCase()}-${DateFormat("yyyyMMdd-HHmm").format(DateTime.now())}';

    final session = TillReconciliationSession(
      sessionId: sessionId,
      branchName: branchName,
      branchId: branchId,
      cashierName: cashierName,
      shiftStart: DateTime.now().subtract(const Duration(hours: 8)),
      shiftEnd: DateTime.now(),
      openingFloat: openingFloat,
      cashSales: cashSales,
      mpesaSales: mpesaSales,
      cardSales: cardSales,
      insuranceSales: insuranceSales,
      pettyCashPayouts: pettyCashPayouts,
      actualCashInDrawer: actualCashInDrawer,
      status: 'CLOSED',
      managerNotes: managerNotes,
    );

    _tillSessions.insert(0, session);

    if (_client != null && !_schemaMissing) {
      try {
        await _client.from('branch_till_sessions').insert(session.toJson());
      } catch (e) {
        debugPrint('Branch Till Session Supabase insert note: $e');
      }
    }

    notifyListeners();
    return session;
  }
}
