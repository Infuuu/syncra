import 'dart:convert';

class NoteModel {
  final String id;
  final String documentJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;

  const NoteModel({
    required this.id,
    required this.documentJson,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
  });

  factory NoteModel.fromMap(Map<String, dynamic> map) => NoteModel(
    id: map['id'] as String,
    documentJson: map['documentJson'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    isPinned: map['isPinned'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'documentJson': documentJson,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPinned': isPinned,
  };

  NoteModel copyWith({
    String? id,
    String? documentJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
  }) => NoteModel(
    id: id ?? this.id,
    documentJson: documentJson ?? this.documentJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPinned: isPinned ?? this.isPinned,
  );

  String get title {
    final lines = _plainTextLines;
    return lines.firstWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => 'Untitled Note',
    );
  }

  String get preview {
    final lines =
        _plainTextLines.where((line) => line.trim().isNotEmpty).toList();
    if (lines.length <= 1) return 'Start writing your note...';
    return lines.skip(1).join(' ').trim();
  }

  int get wordCount {
    final text = plainText.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).length;
  }

  String get plainText => _plainTextLines.join('\n').trimRight();

  List<String> get _plainTextLines {
    try {
      final decoded = jsonDecode(documentJson);
      if (decoded is! List) return const [''];
      final buffer = StringBuffer();
      for (final op in decoded) {
        if (op is Map<String, dynamic>) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        } else if (op is Map) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }
      return buffer.toString().split('\n');
    } catch (_) {
      return const [''];
    }
  }
}
