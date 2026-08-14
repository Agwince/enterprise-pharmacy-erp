class ShelfLocation {
  final String id;
  final String aisleName;
  final String shelfName;
  final DateTime createdAt;

  ShelfLocation({
    required this.id,
    required this.aisleName,
    required this.shelfName,
    required this.createdAt,
  });

  String get fullBinLocation => '$aisleName - $shelfName';

  factory ShelfLocation.fromJson(Map<String, dynamic> json) {
    return ShelfLocation(
      id: json['id'] as String,
      aisleName: json['aisle_name'] as String? ?? 'Aisle 1',
      shelfName: json['shelf_name'] as String? ?? 'Shelf A1',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'aisle_name': aisleName,
      'shelf_name': shelfName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
