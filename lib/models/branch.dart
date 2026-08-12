class Branch {
  final String id;
  final String name;
  final String code;
  final String? location;
  final DateTime createdAt;

  Branch({
    required this.id,
    required this.name,
    required this.code,
    this.location,
    required this.createdAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      location: json['location'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'location': location,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
