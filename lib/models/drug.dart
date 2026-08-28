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
  final int quantityInStock;
  final String? imageUrl;
  final String? innerUnitImageUrl;
  final String innerUnitType;
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
    this.quantityInStock = 50,
    this.imageUrl,
    this.innerUnitImageUrl,
    this.innerUnitType = 'Strip/Blister',
    required this.createdAt,
  });

  /// Returns the real image URL if one exists, otherwise null (no fake images).
  String? get displayImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl!;
    }
    return null;
  }

  factory Drug.fromJson(Map<String, dynamic> json) {
    return Drug(
      id: (json['id'] ?? '') as String,
      sku: (json['barcode'] ?? json['sku'] ?? 'SKU-GEN') as String,
      name: (json['name'] ?? 'Pharmaceutical Drug') as String,
      genericName: json['generic_name'] as String?,
      category: json['category'] as String? ?? 'General Medicines',
      unit: (json['package_unit'] ?? json['unit'] ?? 'Box') as String,
      binLocation: (json['target_shelf'] ?? json['bin_location'] ?? 'AISLE 1 - SHELF A1') as String,
      unitPrice: json['price'] != null ? double.tryParse(json['price'].toString()) ?? 0.0 : ((json['unit_price'] as num?)?.toDouble() ?? 0.0),
      costPrice: json['cost'] != null ? double.tryParse(json['cost'].toString()) ?? 0.0 : ((json['cost_price'] as num?)?.toDouble() ?? 0.0),
      minThreshold: json['reorder_level'] != null ? int.tryParse(json['reorder_level'].toString()) ?? 15 : ((json['min_threshold'] as num?)?.toInt() ?? 15),
      maxThreshold: json['max_level'] != null ? int.tryParse(json['max_level'].toString()) ?? 150 : ((json['max_threshold'] as num?)?.toInt() ?? 150),
      quantityInStock: json['quantity_in_stock'] != null ? int.tryParse(json['quantity_in_stock'].toString()) ?? 50 : 50,
      imageUrl: (json['box_image_url'] ?? json['image_url']) as String?,
      innerUnitImageUrl: (json['image_url'] ?? json['inner_unit_image_url']) as String?,
      innerUnitType: json['inner_unit_type'] as String? ?? 'Strip/Blister',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': sku,
      'name': name,
      'generic_name': genericName,
      'category': category,
      'package_unit': unit,
      'target_shelf': binLocation,
      'price': unitPrice,
      'cost': costPrice,
      'reorder_level': minThreshold,
      'max_level': maxThreshold,
      'quantity_in_stock': quantityInStock,
      'box_image_url': imageUrl,
      'image_url': innerUnitImageUrl,
      'inner_unit_type': innerUnitType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
