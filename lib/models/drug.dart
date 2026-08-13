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
  final String? imageUrl;
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
    this.imageUrl,
    required this.createdAt,
  });

  /// Category-based placeholder URL assigner
  String get displayImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl!;
    }
    final upperName = name.toUpperCase();
    if (upperName.contains('SYRUP') ||
        upperName.contains('SUSP') ||
        upperName.contains('EXP') ||
        upperName.contains('LIQ') ||
        upperName.contains('60ML') ||
        upperName.contains('10ML')) {
      return 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&auto=format&fit=crop&q=80';
    } else if (upperName.contains('TABS') ||
        upperName.contains('CAPS') ||
        upperName.contains('100\'S') ||
        upperName.contains('PANADOL') ||
        upperName.contains('AMOXICILLIN')) {
      return 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800&auto=format&fit=crop&q=80';
    }
    return 'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800&auto=format&fit=crop&q=80';
  }

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
      imageUrl: json['image_url'] as String?,
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
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
