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
  final String? thumbUrl;
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
    this.quantityInStock = 0,
    this.imageUrl,
    this.thumbUrl,
    this.innerUnitImageUrl,
    this.innerUnitType = 'Strip/Blister',
    required this.createdAt,
  });

  /// Returns the real image URL if one exists, otherwise null.
  String? get displayImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl!;
    }
    return null;
  }

  /// Returns the lightweight thumbnail URL if available, falling back to full image.
  String? get displayThumbUrl {
    if (thumbUrl != null && thumbUrl!.isNotEmpty) {
      return thumbUrl!;
    }
    return displayImageUrl;
  }

  factory Drug.fromJson(Map<String, dynamic> json) {
    return Drug(
      id: (json['id'] ?? '') as String,
      sku: (json['barcode'] ?? json['sku'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      genericName: json['generic_name'] as String?,
      category: json['category'] as String? ?? '',
      unit: (json['package_unit'] ?? json['unit'] ?? '') as String,
      binLocation: (json['target_shelf'] ?? json['bin_location'] ?? '') as String,
      unitPrice: json['price'] != null ? double.tryParse(json['price'].toString()) ?? 0.0 : ((json['unit_price'] as num?)?.toDouble() ?? 0.0),
      costPrice: json['cost'] != null ? double.tryParse(json['cost'].toString()) ?? 0.0 : ((json['cost_price'] as num?)?.toDouble() ?? 0.0),
      minThreshold: json['reorder_level'] != null ? int.tryParse(json['reorder_level'].toString()) ?? 0 : ((json['min_threshold'] as num?)?.toInt() ?? 0),
      maxThreshold: json['max_level'] != null ? int.tryParse(json['max_level'].toString()) ?? 0 : ((json['max_threshold'] as num?)?.toInt() ?? 0),
      quantityInStock: json['quantity_in_stock'] != null ? int.tryParse(json['quantity_in_stock'].toString()) ?? 0 : 0,
      imageUrl: (json['box_image_url'] ?? json['image_url']) as String?,
      thumbUrl: json['thumb_url'] as String?,
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
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      'image_url': innerUnitImageUrl,
      'inner_unit_type': innerUnitType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
