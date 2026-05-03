import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/note_model.dart';
import '../../../core/api/note_service.dart';
import '../data/local_note_repository.dart';

final localNoteRepositoryProvider = Provider<LocalNoteRepository>((ref) {
  return LocalNoteRepository();
});

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, List<NoteModel>>(
      NotesController.new,
    );

final noteByIdProvider = Provider.family<NoteModel?, String>((ref, id) {
  final notes =
      ref.watch(notesControllerProvider).asData?.value ?? const <NoteModel>[];
  for (final note in notes) {
    if (note.id == id) return note;
  }
  return null;
});

class NotesController extends AsyncNotifier<List<NoteModel>> {
  LocalNoteRepository get _repository => ref.read(localNoteRepositoryProvider);

  @override
  Future<List<NoteModel>> build() async {
    try {
      final remoteNotes = await noteService.getNotes();
      // Optional: sync down to local repo
      return remoteNotes;
    } catch (_) {
      return _repository.listNotes();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        return await noteService.getNotes();
      } catch (_) {
        return await _repository.listNotes();
      }
    });
  }

  Future<NoteModel> createDraft({String? documentJson}) async {
    final note = await _repository.createDraft(documentJson: documentJson);
    try {
      await noteService.createNote(note);
    } catch (e) {
      print('Failed to sync new note to backend: $e');
    }
    
    final current = state.asData?.value ?? const <NoteModel>[];
    state = AsyncData([note, ...current.where((item) => item.id != note.id)]);
    return note;
  }

  Future<void> saveNote({
    required String id,
    required String documentJson,
  }) async {
    await _repository.saveNote(id: id, documentJson: documentJson);
    try {
      await noteService.updateNote(id, documentJson: documentJson);
    } catch (e) {
      print('Failed to sync updated note to backend: $e');
    }
    await _reloadSilently();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    try {
      await noteService.deleteNote(id);
    } catch (e) {
      print('Failed to delete note from backend: $e');
    }
    final current = state.asData?.value ?? const <NoteModel>[];
    state = AsyncData(current.where((note) => note.id != id).toList());
  }

  Future<void> togglePinned(String id) async {
    await _repository.togglePinned(id);
    // Pin status currently only exists locally
    await _reloadSilently();
  }

  Future<void> _reloadSilently() async {
    try {
      final notes = await noteService.getNotes();
      state = AsyncData(notes);
    } catch (_) {
      final notes = await _repository.listNotes();
      state = AsyncData(notes);
    }
  }
}
