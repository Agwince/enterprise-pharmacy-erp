class InventoryItem {
  final String id;
  final String branchId;
  final String drugId;
  final int quantity;
  final String batchNumber;
  final DateTime expiryDate;
  final DateTime lastUpdated;
  final String? drugName;
  final String? drugSku;
  final String? binLocation;

  InventoryItem({
    required this.id,
    required this.branchId,
    required this.drugId,
    required this.quantity,
    required this.batchNumber,
    required this.expiryDate,
    required this.lastUpdated,
    this.drugName,
    this.drugSku,
    this.binLocation,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      drugId: json['drug_id'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      batchNumber: json['batch_number'] as String? ?? 'BATCH-DEFAULT',
      expiryDate: json['expiry_date'] != null 
          ? DateTime.parse(json['expiry_date'] as String)
          : DateTime.now().add(const Duration(days: 365)),
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated'] as String)
          : DateTime.now(),
      drugName: json['drugs']?['name'] as String?,
      drugSku: json['drugs']?['sku'] as String?,
      binLocation: json['drugs']?['bin_location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'drug_id': drugId,
      'quantity': quantity,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String().split('T')[0],
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
