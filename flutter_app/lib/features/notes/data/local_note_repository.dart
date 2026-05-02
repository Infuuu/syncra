import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/note_model.dart';

class LocalNoteRepository {
  static const _storageKey = 'syncra.notes.v2';
  static const _legacyKey = 'notes';

  Future<List<NoteModel>> listNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return _migrateLegacyNotes(prefs);
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => NoteModel.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort(_sortNotes);
  }

  Future<NoteModel> createDraft({String? documentJson}) async {
    final notes = await listNotes();
    final now = DateTime.now();
    final note = NoteModel(
      id: _generateId(),
      documentJson: documentJson ?? _emptyDocumentJson,
      createdAt: now,
      updatedAt: now,
    );
    notes.insert(0, note);
    await _persist(notes);
    return note;
  }

  Future<NoteModel?> getNote(String id) async {
    final notes = await listNotes();
    try {
      return notes.firstWhere((note) => note.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNote({
    required String id,
    required String documentJson,
  }) async {
    final notes = await listNotes();
    final index = notes.indexWhere((note) => note.id == id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(
      documentJson: documentJson,
      updatedAt: DateTime.now(),
    );
    notes.sort(_sortNotes);
    await _persist(notes);
  }

  Future<void> deleteNote(String id) async {
    final notes = await listNotes();
    notes.removeWhere((note) => note.id == id);
    await _persist(notes);
  }

  Future<void> togglePinned(String id) async {
    final notes = await listNotes();
    final index = notes.indexWhere((note) => note.id == id);
    if (index == -1) return;
    notes[index] = notes[index].copyWith(
      isPinned: !notes[index].isPinned,
      updatedAt: DateTime.now(),
    );
    notes.sort(_sortNotes);
    await _persist(notes);
  }

  Future<void> _persist(List<NoteModel> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(notes.map((note) => note.toMap()).toList()),
    );
  }

  Future<List<NoteModel>> _migrateLegacyNotes(SharedPreferences prefs) async {
    final legacy = prefs.getStringList(_legacyKey) ?? const [];
    if (legacy.isEmpty) return const [];

    final now = DateTime.now();
    final notes = <NoteModel>[];
    for (var index = 0; index < legacy.length; index++) {
      final offset = Duration(minutes: legacy.length - index);
      notes.add(
        NoteModel(
          id: _generateId(),
          documentJson: legacy[index],
          createdAt: now.subtract(offset),
          updatedAt: now.subtract(offset),
        ),
      );
    }
    await _persist(notes);
    await prefs.remove(_legacyKey);
    return notes..sort(_sortNotes);
  }

  int _sortNotes(NoteModel a, NoteModel b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random().nextInt(999999999).toRadixString(16);
    return 'note_$now$random';
  }
}

const _emptyDocumentJson = '[{"insert":"\\n"}]';
