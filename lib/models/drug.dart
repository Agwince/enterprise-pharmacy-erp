class Drug {
  final String id;
  final String sku;
  final String name;
  final String? genericName;
  final String category;
  final String unit;
  final String binLocation;
  final double unitPrice;
  final double costPrice;
  final int minThreshold;
  final int maxThreshold;
  final DateTime createdAt;

  Drug({
    required this.id,
    required this.sku,
    required this.name,
    this.genericName,
    required this.category,
    required this.unit,
    required this.binLocation,
    required this.unitPrice,
    required this.costPrice,
    required this.minThreshold,
    required this.maxThreshold,
    required this.createdAt,
  });

  factory Drug.fromJson(Map<String, dynamic> json) {
    return Drug(
      id: json['id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      genericName: json['generic_name'] as String?,
      category: json['category'] as String? ?? 'General',
      unit: json['unit'] as String? ?? 'Box',
      binLocation: json['bin_location'] as String? ?? 'AISLE 1 - SHELF A1',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      minThreshold: (json['min_threshold'] as num?)?.toInt() ?? 15,
      maxThreshold: (json['max_threshold'] as num?)?.toInt() ?? 150,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'generic_name': genericName,
      'category': category,
      'unit': unit,
      'bin_location': binLocation,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'min_threshold': minThreshold,
      'max_threshold': maxThreshold,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
