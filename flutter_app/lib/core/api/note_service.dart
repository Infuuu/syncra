import 'dart:convert';
import '../api/api_client.dart';
import '../models/note_model.dart';

class NoteService {
  final _dio = apiClient;

  NoteModel _mapFromServer(Map<String, dynamic> e) {
    return NoteModel(
      id: e['id'] as String,
      documentJson: jsonEncode(e['content']),
      createdAt: DateTime.parse(e['createdAt'] as String),
      updatedAt: DateTime.parse(e['updatedAt'] as String),
    );
  }

  Future<List<NoteModel>> getNotes() async {
    final resp = await _dio.get('/notes');
    final items = resp.data['items'] as List<dynamic>;
    return items.map((e) => _mapFromServer(e as Map<String, dynamic>)).toList();
  }

  Future<NoteModel> createNote(NoteModel note) async {
    final resp = await _dio.post(
      '/notes',
      data: {
        'id': note.id,
        'title': note.title,
        'content': jsonDecode(note.documentJson),
      },
    );
    return _mapFromServer(resp.data as Map<String, dynamic>);
  }

  Future<NoteModel> updateNote(String noteId, {String? title, String? documentJson, bool? isDeleted}) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (documentJson != null) patch['content'] = jsonDecode(documentJson);
    if (isDeleted != null) patch['isDeleted'] = isDeleted;

    final resp = await _dio.patch(
      '/notes/$noteId',
      data: patch,
    );
    return _mapFromServer(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteNote(String noteId) async {
    await _dio.delete('/notes/$noteId');
  }
}

final noteService = NoteService();
