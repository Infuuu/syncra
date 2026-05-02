class Card {
  final String id;
  final String boardId;
  final String listId;
  final String title;
  final String? description;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Card({
    required this.id,
    required this.boardId,
    required this.listId,
    required this.title,
    this.description,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Card.fromJson(Map<String, dynamic> json) => Card(
    id: json['id'] as String,
    boardId: json['boardId'] as String,
    listId: json['listId'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    orderIndex: (json['orderIndex'] as num).toInt(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Card copyWith({String? listId, String? title, String? description}) => Card(
    id: id,
    boardId: boardId,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    description: description ?? this.description,
    orderIndex: orderIndex,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
