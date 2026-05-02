class Board {
  final String id;
  final String name;
  final String? ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Board({
    required this.id,
    required this.name,
    this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Board.fromJson(Map<String, dynamic> json) => Board(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerId: json['ownerId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
