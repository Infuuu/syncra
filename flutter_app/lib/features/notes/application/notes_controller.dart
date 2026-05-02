import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/note_model.dart';
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
  Future<List<NoteModel>> build() {
    return _repository.listNotes();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.listNotes);
  }

  Future<NoteModel> createDraft({String? documentJson}) async {
    final note = await _repository.createDraft(documentJson: documentJson);
    final current = state.asData?.value ?? const <NoteModel>[];
    state = AsyncData([note, ...current.where((item) => item.id != note.id)]);
    return note;
  }

  Future<void> saveNote({
    required String id,
    required String documentJson,
  }) async {
    await _repository.saveNote(id: id, documentJson: documentJson);
    await _reloadSilently();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    final current = state.asData?.value ?? const <NoteModel>[];
    state = AsyncData(current.where((note) => note.id != id).toList());
  }

  Future<void> togglePinned(String id) async {
    await _repository.togglePinned(id);
    await _reloadSilently();
  }

  Future<void> _reloadSilently() async {
    final notes = await _repository.listNotes();
    state = AsyncData(notes);
  }
}
