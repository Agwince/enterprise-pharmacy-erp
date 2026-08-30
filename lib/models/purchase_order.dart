import 'etims_invoice.dart';

class Supplier {
  final String id;
  final String name;
  final String? code;
  final String? kraPin;
  final String? phone;
  final String? email;
  final String? contactPerson;
  final String? paymentTerms;
  final double? creditLimit;
  final double balance;
  final int? leadTimeDays;
  final bool isActive;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.code,
    this.kraPin,
    this.phone,
    this.email,
    this.contactPerson,
    this.paymentTerms,
    this.creditLimit,
    this.balance = 0.0,
    this.leadTimeDays,
    this.isActive = true,
    required this.createdAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      kraPin: json['kra_pin']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      contactPerson: json['contact_person']?.toString(),
      paymentTerms: json['payment_terms']?.toString(),
      creditLimit: (json['credit_limit'] as num?)?.toDouble(),
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (code != null) 'code': code,
      if (kraPin != null) 'kra_pin': kraPin,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (contactPerson != null) 'contact_person': contactPerson,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      if (creditLimit != null) 'credit_limit': creditLimit,
      'balance': balance,
      if (leadTimeDays != null) 'lead_time_days': leadTimeDays,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class PurchaseOrderItem {
  final String id;
  final String poId;
  final String drugId;
  final int quantityRequested;
  final int quantityReceived;
  final double unitCost; // Contracted/Budgeted PO Cost (VAT Exclusive)
  final double? realGrnCost; // Actual Real Cost Price captured at Goods Receipt (VAT Exclusive)
  final TIMSTaxCode taxCode;
  final String? batchNo;
  final DateTime? expiryDate;
  final double? invoiceUnitCost;
  final int? invoiceQuantity;
  final String? drugName;
  final String? drugSku;

  PurchaseOrderItem({
    required this.id,
    required this.poId,
    required this.drugId,
    required this.quantityRequested,
    required this.quantityReceived,
    required this.unitCost,
    this.realGrnCost,
    this.taxCode = TIMSTaxCode.B, // Strict default: 16% Standard VAT
    this.batchNo,
    this.expiryDate,
    this.invoiceUnitCost,
    this.invoiceQuantity,
    this.drugName,
    this.drugSku,
  });

  double get requestedTotal => quantityRequested * unitCost;
  double get netReceivedTotal => quantityReceived * (realGrnCost ?? unitCost);
  double get inputVatRate => taxCode.allowsInputCredit ? taxCode.rate : 0.0;
  double get inputVatAmount => netReceivedTotal * inputVatRate;
  double get grossReceivedTotal => netReceivedTotal + inputVatAmount;
  double get receivedTotal => netReceivedTotal;
  double get invoicedTotal => (invoiceQuantity ?? quantityReceived) * (invoiceUnitCost ?? realGrnCost ?? unitCost);

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id']?.toString() ?? '',
      poId: json['po_id']?.toString() ?? '',
      drugId: json['drug_id']?.toString() ?? '',
      quantityRequested: (json['quantity_requested'] as num?)?.toInt() ?? 0,
      quantityReceived: (json['quantity_received'] as num?)?.toInt() ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      realGrnCost: (json['real_grn_cost'] as num?)?.toDouble(),
      taxCode: TIMSTaxCode.fromCode(json['tax_code']?.toString()),
      batchNo: json['batch_no']?.toString(),
      expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? ''),
      invoiceUnitCost: (json['invoice_unit_cost'] as num?)?.toDouble(),
      invoiceQuantity: (json['invoice_quantity'] as num?)?.toInt(),
      drugName: (json['drug_name'] ?? json['drugs']?['name'])?.toString(),
      drugSku: (json['drug_sku'] ?? json['drugs']?['sku'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'po_id': poId,
      'drug_id': drugId,
      'quantity_requested': quantityRequested,
      'quantity_received': quantityReceived,
      'unit_cost': unitCost,
      'tax_code': taxCode.code,
      if (realGrnCost != null) 'real_grn_cost': realGrnCost,
      if (batchNo != null) 'batch_no': batchNo,
      if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String().substring(0, 10),
      if (invoiceUnitCost != null) 'invoice_unit_cost': invoiceUnitCost,
      if (invoiceQuantity != null) 'invoice_quantity': invoiceQuantity,
      if (drugName != null) 'drug_name': drugName,
      if (drugSku != null) 'drug_sku': drugSku,
    };
  }
}

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String branchId;
  final String? branchName;
  final String? supplierId;
  final String? supplierName;
  final String status; // 'draft', 'approved', 'sent', 'received', 'closed', 'cancelled'
  final double totalAmount;
  final DateTime createdAt;
  final DateTime? deliveryDate;
  final String? notes;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? grnNumber;
  final DateTime? grnDate;
  final String? receivedBy;
  final String? invoiceNumber;
  final double? invoiceAmount;
  final String matchStatus; // 'UNMATCHED', 'MATCHED', 'QTY_VARIANCE', 'PRICE_VARIANCE', 'BLOCKED'
  final double matchTolerance;
  final String? glJournalId;
  final String? glPaymentJournalId;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.branchId,
    this.branchName,
    this.supplierId,
    this.supplierName,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.deliveryDate,
    this.notes,
    this.approvedBy,
    this.approvedAt,
    this.grnNumber,
    this.grnDate,
    this.receivedBy,
    this.invoiceNumber,
    this.invoiceAmount,
    this.matchStatus = 'UNMATCHED',
    this.matchTolerance = 500.0,
    this.glJournalId,
    this.glPaymentJournalId,
    this.items = const [],
  });

  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isSent => status.toLowerCase() == 'sent';
  bool get isReceived => status.toLowerCase() == 'received';
  bool get isClosed => status.toLowerCase() == 'closed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  double get grnTotalCost => items.fold(0.0, (sum, i) => sum + i.receivedTotal);

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['purchase_order_items'] as List<dynamic>?;
    final itemList = rawItems != null
        ? rawItems.map((i) => PurchaseOrderItem.fromJson(Map<String, dynamic>.from(i as Map))).toList()
        : <PurchaseOrderItem>[];

    return PurchaseOrder(
      id: json['id']?.toString() ?? '',
      poNumber: json['po_number']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? json['branches']?['name']?.toString(),
      supplierId: json['supplier_id']?.toString(),
      supplierName: json['supplier_name']?.toString() ?? json['suppliers']?['name']?.toString(),
      status: json['status']?.toString().toLowerCase() ?? 'draft',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      deliveryDate: DateTime.tryParse(json['delivery_date']?.toString() ?? ''),
      notes: json['notes']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      approvedAt: DateTime.tryParse(json['approved_at']?.toString() ?? ''),
      grnNumber: json['grn_number']?.toString(),
      grnDate: DateTime.tryParse(json['grn_date']?.toString() ?? ''),
      receivedBy: json['received_by']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      invoiceAmount: (json['invoice_amount'] as num?)?.toDouble(),
      matchStatus: json['match_status']?.toString().toUpperCase() ?? 'UNMATCHED',
      matchTolerance: (json['match_tolerance'] as num?)?.toDouble() ?? 500.0,
      glJournalId: json['gl_journal_id']?.toString(),
      glPaymentJournalId: json['gl_payment_journal_id']?.toString(),
      items: itemList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'po_number': poNumber,
      'branch_id': branchId,
      if (branchName != null) 'branch_name': branchName,
      if (supplierId != null) 'supplier_id': supplierId,
      if (supplierName != null) 'supplier_name': supplierName,
      'status': status,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
      if (deliveryDate != null) 'delivery_date': deliveryDate!.toIso8601String().substring(0, 10),
      if (notes != null) 'notes': notes,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
      if (grnNumber != null) 'grn_number': grnNumber,
      if (grnDate != null) 'grn_date': grnDate!.toIso8601String(),
      if (receivedBy != null) 'received_by': receivedBy,
      if (invoiceNumber != null) 'invoice_number': invoiceNumber,
      if (invoiceAmount != null) 'invoice_amount': invoiceAmount,
      'match_status': matchStatus,
      'match_tolerance': matchTolerance,
      if (glJournalId != null) 'gl_journal_id': glJournalId,
      if (glPaymentJournalId != null) 'gl_payment_journal_id': glPaymentJournalId,
    };
  }
}
