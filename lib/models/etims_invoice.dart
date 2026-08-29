import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Official KRA TIMS / eTIMS Tax Classification (taxTyCd)
enum TIMSTaxCode {
  /// Code A: Exempt (0% VAT, input VAT NOT claimable under VAT Act First Schedule)
  A(
    code: 'A',
    rate: 0.0,
    description: 'Exempt (0% VAT - Input Tax Blocked)',
    allowsInputCredit: false,
  ),

  /// Code B: 16% Standard VAT (Standard rate taxable supplies, input VAT claimable)
  B(
    code: 'B',
    rate: 0.16,
    description: '16% Standard VAT (Input Tax Claimable)',
    allowsInputCredit: true,
  ),

  /// Code C: Zero-Rated (0% VAT, input VAT claimable under VAT Act Second Schedule)
  C(
    code: 'C',
    rate: 0.0,
    description: '0% Zero-Rated (Input Tax Claimable)',
    allowsInputCredit: true,
  ),

  /// Code D: Non-VAT / Out of Scope (0% non-taxable / not VAT registered)
  D(
    code: 'D',
    rate: 0.0,
    description: 'Non-VAT / Out of Scope (0%)',
    allowsInputCredit: false,
  ),

  /// Code E: 8% Special Reduced VAT (Petroleum products / special concession rate)
  E(
    code: 'E',
    rate: 0.08,
    description: '8% Special Reduced VAT',
    allowsInputCredit: true,
  );

  final String code;
  final double rate;
  final String description;
  final bool allowsInputCredit;

  const TIMSTaxCode({
    required this.code,
    required this.rate,
    required this.description,
    required this.allowsInputCredit,
  });

  /// Parse from code, strictly defaulting to B (16% Standard VAT) until verified per product
  static TIMSTaxCode fromCode(String? c) {
    switch (c?.toUpperCase()) {
      case 'A':
        return TIMSTaxCode.A;
      case 'B':
        return TIMSTaxCode.B;
      case 'C':
        return TIMSTaxCode.C;
      case 'D':
        return TIMSTaxCode.D;
      case 'E':
        return TIMSTaxCode.E;
      default:
        return TIMSTaxCode.B; // Strict default: 16% Standard VAT
    }
  }
}

/// Branch KRA Device & Integration Configuration (from branch_kra_config table)
class BranchKraConfig {
  final String id;
  final String branchId;
  final String branchName;
  final String kraPin;
  final String etimsDeviceId;
  final String machineNumber;
  final String branchIdentifier;
  final bool isActive;

  BranchKraConfig({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.kraPin,
    required this.etimsDeviceId,
    required this.machineNumber,
    required this.branchIdentifier,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'branch_id': branchId,
        'branch_name': branchName,
        'kra_pin': kraPin,
        'etims_device_id': etimsDeviceId,
        'machine_number': machineNumber,
        'branch_identifier': branchIdentifier,
        'is_active': isActive,
      };

  factory BranchKraConfig.fromJson(Map<String, dynamic> json) {
    return BranchKraConfig(
      id: json['id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      kraPin: json['kra_pin']?.toString() ?? '',
      etimsDeviceId: json['etims_device_id']?.toString() ?? '',
      machineNumber: json['machine_number']?.toString() ?? '',
      branchIdentifier: json['branch_identifier']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// A line item in an eTIMS invoice
class ETIMSLineItem {
  final String drugId;
  final String itemName;
  final String sku;
  final int quantity;
  final double unitPrice;
  final TIMSTaxCode taxCode;
  final double discount;

  ETIMSLineItem({
    required this.drugId,
    required this.itemName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    this.taxCode = TIMSTaxCode.B, // Strict default: 16% Standard VAT
    this.discount = 0.0,
  });

  double get grossTotal => (unitPrice * quantity) - discount;

  double get taxRate => taxCode.rate;

  /// Tax calculated from gross inclusive price (Kenyan retail practice)
  double get taxAmount {
    if (taxRate == 0.0) return 0.0;
    return grossTotal - (grossTotal / (1.0 + taxRate));
  }

  double get netAmount => grossTotal - taxAmount;

  Map<String, dynamic> toJson() => {
        'drug_id': drugId,
        'item_name': itemName,
        'sku': sku,
        'quantity': quantity,
        'unit_price': unitPrice,
        'tax_code': taxCode.code,
        'tax_rate': taxRate,
        'discount': discount,
        'net_amount': netAmount,
        'tax_amount': taxAmount,
        'gross_total': grossTotal,
      };

  factory ETIMSLineItem.fromJson(Map<String, dynamic> json) {
    return ETIMSLineItem(
      drugId: json['drug_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? 'Pharmaceutical Item',
      sku: json['sku']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      taxCode: TIMSTaxCode.fromCode(json['tax_code']?.toString()),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Official KRA eTIMS Electronic Tax Invoice
class ETIMSInvoice {
  final String id;
  final String invoiceNumber;
  final String cuInvoiceNumber;
  final String cuSerialNumber;
  final String kraPin;
  final String traderName;
  final String branchName;
  final String branchId;
  final String customerName;
  final String? customerPin;
  final DateTime dateTime;
  final List<ETIMSLineItem> items;
  final String paymentMode; // Cash, M-Pesa, Card, Insurance, Credit
  final String paymentReference;
  final String cashierName;
  final String localIntegrityHash;
  final String? cuSignature;
  final String verificationUrl;

  ETIMSInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.cuInvoiceNumber,
    required this.cuSerialNumber,
    this.kraPin = 'P051234567Z',
    this.traderName = 'Mediocare Pharmacy Ltd',
    required this.branchName,
    required this.branchId,
    this.customerName = 'Walk-in Customer',
    this.customerPin,
    required this.dateTime,
    required this.items,
    this.paymentMode = 'M-Pesa',
    this.paymentReference = '',
    this.cashierName = 'Cashier 01',
    required this.localIntegrityHash,
    this.cuSignature,
    required this.verificationUrl,
  });

  // Tax summaries by Tax Code
  double get totalTaxableA => items
      .where((i) => i.taxCode == TIMSTaxCode.A)
      .fold(0.0, (sum, i) => sum + i.grossTotal);

  double get totalTaxableB => items
      .where((i) => i.taxCode == TIMSTaxCode.B)
      .fold(0.0, (sum, i) => sum + i.netAmount);

  double get totalTaxB => items
      .where((i) => i.taxCode == TIMSTaxCode.B)
      .fold(0.0, (sum, i) => sum + i.taxAmount);

  double get totalTaxableC => items
      .where((i) => i.taxCode == TIMSTaxCode.C)
      .fold(0.0, (sum, i) => sum + i.grossTotal);

  double get totalTaxableD => items
      .where((i) => i.taxCode == TIMSTaxCode.D)
      .fold(0.0, (sum, i) => sum + i.grossTotal);

  double get totalTaxableE => items
      .where((i) => i.taxCode == TIMSTaxCode.E)
      .fold(0.0, (sum, i) => sum + i.netAmount);

  double get totalTaxE => items
      .where((i) => i.taxCode == TIMSTaxCode.E)
      .fold(0.0, (sum, i) => sum + i.taxAmount);

  double get totalNet => items.fold(0.0, (sum, i) => sum + i.netAmount);
  double get totalTax => items.fold(0.0, (sum, i) => sum + i.taxAmount);
  double get totalGross => items.fold(0.0, (sum, i) => sum + i.grossTotal);

  /// Local integrity hash for internal audit and tamper-evidence before device transmission
  static String computeLocalIntegrityHash({
    required String kraPin,
    required String cuSerial,
    required String invoiceNo,
    required DateTime dateTime,
    required double totalGross,
    required double totalTax,
  }) {
    final raw = '$kraPin|$cuSerial|$invoiceNo|${dateTime.toIso8601String()}|${totalGross.toStringAsFixed(2)}|${totalTax.toStringAsFixed(2)}';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    final hex = digest.toString().toUpperCase();
    return 'INT-HASH-${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }

  /// Generates the QR verification URL for KRA portal
  static String buildVerificationUrl({
    required String kraPin,
    required String cuSerial,
    required String invoiceNo,
    required double totalGross,
    required String signature,
  }) {
    final encSignature = Uri.encodeComponent(signature);
    return 'https://etims.kra.go.ke/verify?pin=$kraPin&cu=$cuSerial&inv=$invoiceNo&tot=${totalGross.toStringAsFixed(2)}&sig=$encSignature';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice_number': invoiceNumber,
        'cu_invoice_number': cuInvoiceNumber,
        'cu_serial_number': cuSerialNumber,
        'kra_pin': kraPin,
        'trader_name': traderName,
        'branch_name': branchName,
        'branch_id': branchId,
        'customer_name': customerName,
        'customer_pin': customerPin,
        'date_time': dateTime.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'payment_mode': paymentMode,
        'payment_reference': paymentReference,
        'cashier_name': cashierName,
        'total_taxable_a': totalTaxableA,
        'total_taxable_b': totalTaxableB,
        'total_tax_b': totalTaxB,
        'total_taxable_c': totalTaxableC,
        'total_taxable_d': totalTaxableD,
        'total_taxable_e': totalTaxableE,
        'total_tax_e': totalTaxE,
        'total_net': totalNet,
        'total_tax': totalTax,
        'total_gross': totalGross,
        'local_integrity_hash': localIntegrityHash,
        'cu_signature': cuSignature,
        'verification_url': verificationUrl,
      };

  factory ETIMSInvoice.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    final items = rawItems.map((e) => ETIMSLineItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    return ETIMSInvoice(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      cuInvoiceNumber: json['cu_invoice_number']?.toString() ?? '',
      cuSerialNumber: json['cu_serial_number']?.toString() ?? '',
      kraPin: json['kra_pin']?.toString() ?? '',
      traderName: json['trader_name']?.toString() ?? 'Mediocare Pharmacy Ltd',
      branchName: json['branch_name']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Walk-in Customer',
      customerPin: json['customer_pin']?.toString(),
      dateTime: DateTime.tryParse(json['date_time']?.toString() ?? '') ?? DateTime.now(),
      items: items,
      paymentMode: json['payment_mode']?.toString() ?? 'M-Pesa',
      paymentReference: json['payment_reference']?.toString() ?? '',
      cashierName: json['cashier_name']?.toString() ?? 'Cashier 01',
      localIntegrityHash: json['local_integrity_hash']?.toString() ?? '',
      cuSignature: json['cu_signature']?.toString(),
      verificationUrl: json['verification_url']?.toString() ?? '',
    );
  }
}

/// KRA Daily Z-Report Model
class ETIMSZReport {
  final String zReportNumber;
  final DateTime date;
  final String branchName;
  final String branchId;
  final String cuSerialNumber;
  final String startInvoiceNumber;
  final String endInvoiceNumber;
  final int totalInvoices;
  final double grossSales;
  final double netSales;
  final double taxCodeASales; // Exempt
  final double taxCodeBSales; // 16% VAT Taxable
  final double taxCodeBTax;   // 16% VAT Tax Amount
  final double taxCodeCSales; // Zero-Rated
  final double taxCodeDSales; // Non-VAT
  final double taxCodeESales; // 8% Reduced VAT
  final double taxCodeETax;   // 8% Tax Amount
  final double totalTax;
  final Map<String, double> paymentBreakdown; // Cash, M-Pesa, Card, etc.
  final DateTime generatedAt;
  final String supervisorSignOff;

  ETIMSZReport({
    required this.zReportNumber,
    required this.date,
    required this.branchName,
    required this.branchId,
    required this.cuSerialNumber,
    required this.startInvoiceNumber,
    required this.endInvoiceNumber,
    required this.totalInvoices,
    required this.grossSales,
    required this.netSales,
    required this.taxCodeASales,
    required this.taxCodeBSales,
    required this.taxCodeBTax,
    required this.taxCodeCSales,
    required this.taxCodeDSales,
    required this.taxCodeESales,
    required this.taxCodeETax,
    required this.totalTax,
    required this.paymentBreakdown,
    required this.generatedAt,
    required this.supervisorSignOff,
  });

  Map<String, dynamic> toJson() => {
        'z_report_number': zReportNumber,
        'date': date.toIso8601String(),
        'branch_name': branchName,
        'branch_id': branchId,
        'cu_serial_number': cuSerialNumber,
        'start_invoice_number': startInvoiceNumber,
        'end_invoice_number': endInvoiceNumber,
        'total_invoices': totalInvoices,
        'gross_sales': grossSales,
        'net_sales': netSales,
        'tax_code_a_sales': taxCodeASales,
        'tax_code_b_sales': taxCodeBSales,
        'tax_code_b_tax': taxCodeBTax,
        'tax_code_c_sales': taxCodeCSales,
        'tax_code_d_sales': taxCodeDSales,
        'tax_code_e_sales': taxCodeESales,
        'tax_code_e_tax': taxCodeETax,
        'total_tax': totalTax,
        'payment_breakdown': paymentBreakdown,
        'generated_at': generatedAt.toIso8601String(),
        'supervisor_sign_off': supervisorSignOff,
      };
}

/// Branch Till & Cash Drawer Session Reconciliation Model
class TillReconciliationSession {
  final String sessionId;
  final String branchName;
  final String branchId;
  final String cashierName;
  final DateTime shiftStart;
  final DateTime? shiftEnd;
  final double openingFloat;
  final double cashSales;
  final double mpesaSales;
  final double cardSales;
  final double insuranceSales;
  final double pettyCashPayouts;
  final double actualCashInDrawer;
  final String status; // OPEN, CLOSED, AUDITED
  final String? managerNotes;

  TillReconciliationSession({
    required this.sessionId,
    required this.branchName,
    required this.branchId,
    required this.cashierName,
    required this.shiftStart,
    this.shiftEnd,
    required this.openingFloat,
    required this.cashSales,
    required this.mpesaSales,
    required this.cardSales,
    required this.insuranceSales,
    required this.pettyCashPayouts,
    required this.actualCashInDrawer,
    this.status = 'OPEN',
    this.managerNotes,
  });

  double get expectedCashInDrawer => openingFloat + cashSales - pettyCashPayouts;
  double get variance => actualCashInDrawer - expectedCashInDrawer;
  double get totalRevenue => cashSales + mpesaSales + cardSales + insuranceSales;

  bool get isBalanced => variance.abs() < 1.0;
  bool get hasShortage => variance < -1.0;
  bool get hasSurplus => variance > 1.0;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'branch_name': branchName,
        'branch_id': branchId,
        'cashier_name': cashierName,
        'shift_start': shiftStart.toIso8601String(),
        'shift_end': shiftEnd?.toIso8601String(),
        'opening_float': openingFloat,
        'cash_sales': cashSales,
        'mpesa_sales': mpesaSales,
        'card_sales': cardSales,
        'insurance_sales': insuranceSales,
        'petty_cash_payouts': pettyCashPayouts,
        'actual_cash_in_drawer': actualCashInDrawer,
        'expected_cash_in_drawer': expectedCashInDrawer,
        'variance': variance,
        'total_revenue': totalRevenue,
        'status': status,
        'manager_notes': managerNotes,
      };
}
