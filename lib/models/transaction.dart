class TransactionRecord {
  final String id;
  final String branchId;
  final String drugId;
  final String transactionType; // 'sale', 'receipt', 'adjustment', 'transfer'
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final DateTime transactionDate;
  final String? drugName;
  final String? branchName;
  final bool isSynced;

  TransactionRecord({
    required this.id,
    required this.branchId,
    required this.drugId,
    required this.transactionType,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.transactionDate,
    this.drugName,
    this.branchName,
    this.isSynced = true,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      drugId: json['drug_id'] as String,
      transactionType: json['transaction_type'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      transactionDate: json['transaction_date'] != null 
          ? DateTime.parse(json['transaction_date'] as String)
          : DateTime.now(),
      drugName: json['drugs']?['name'] as String?,
      branchName: json['branches']?['name'] as String?,
      isSynced: json['is_synced'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'drug_id': drugId,
      'transaction_type': transactionType,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }
}
