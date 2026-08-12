class PurchaseOrderItem {
  final String id;
  final String poId;
  final String drugId;
  final int quantityRequested;
  final int quantityReceived;
  final double unitCost;
  final String? drugName;
  final String? drugSku;

  PurchaseOrderItem({
    required this.id,
    required this.poId,
    required this.drugId,
    required this.quantityRequested,
    required this.quantityReceived,
    required this.unitCost,
    this.drugName,
    this.drugSku,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] as String,
      poId: json['po_id'] as String,
      drugId: json['drug_id'] as String,
      quantityRequested: (json['quantity_requested'] as num?)?.toInt() ?? 0,
      quantityReceived: (json['quantity_received'] as num?)?.toInt() ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      drugName: json['drugs']?['name'] as String?,
      drugSku: json['drugs']?['sku'] as String?,
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
    };
  }
}

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String branchId;
  final String status; // 'draft', 'submitted', 'received', 'cancelled'
  final double totalAmount;
  final DateTime createdAt;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.branchId,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.items = const [],
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    var rawItems = json['purchase_order_items'] as List<dynamic>?;
    List<PurchaseOrderItem> itemList = rawItems != null
        ? rawItems.map((i) => PurchaseOrderItem.fromJson(i as Map<String, dynamic>)).toList()
        : [];

    return PurchaseOrder(
      id: json['id'] as String,
      poNumber: json['po_number'] as String,
      branchId: json['branch_id'] as String,
      status: json['status'] as String? ?? 'draft',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      items: itemList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'po_number': poNumber,
      'branch_id': branchId,
      'status': status,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
