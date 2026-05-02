class BoardList {
  final String id;
  final String boardId;
  final String title;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BoardList({
    required this.id,
    required this.boardId,
    required this.title,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BoardList.fromJson(Map<String, dynamic> json) => BoardList(
    id: json['id'] as String,
    boardId: json['boardId'] as String,
    title: json['title'] as String,
    orderIndex: (json['orderIndex'] as num).toInt(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
