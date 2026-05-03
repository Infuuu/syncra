import 'package:flutter/foundation.dart';
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
    // 1. Load instantly from local storage so UI is fast
    final localNotes = await _repository.listNotes();
    
    // 2. Trigger background sync without blocking the UI
    Future.microtask(() => _backgroundSync(localNotes));
    
    return localNotes;
  }

  Future<void> _backgroundSync(List<NoteModel> localNotes) async {
    try {
      debugPrint('[Syncra] Starting background sync...');
      final remoteNotes = await noteService.getNotes();
      debugPrint('[Syncra] Got ${remoteNotes.length} remote notes');
      final remoteIds = remoteNotes.map((n) => n.id).toSet();
      
      // Upload local notes that are missing on the server
      for (final local in localNotes) {
        if (!remoteIds.contains(local.id)) {
          try {
            await noteService.createNote(local);
            debugPrint('[Syncra] Uploaded local note ${local.id}');
          } catch (e) {
            debugPrint('[Syncra] Migration error for note ${local.id}: $e');
          }
        }
      }
      
      // Fetch the final merged list and save to local storage
      final finalRemote = await noteService.getNotes();
      for (final note in finalRemote) {
        await _repository.upsertNote(note);
      }
      
      // Update the UI state with the fresh synced notes
      debugPrint('[Syncra] Background sync complete: ${finalRemote.length} notes');
      state = AsyncData(finalRemote);
    } catch (e) {
      debugPrint('[Syncra] Background sync error: $e');
      // Don't touch state — keep showing whatever local notes we had
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final remote = await noteService.getNotes();
        for (final note in remote) {
          await _repository.upsertNote(note);
        }
        return remote;
      } catch (_) {
        return await _repository.listNotes();
      }
    });
  }

  Future<NoteModel> createDraft({String? documentJson}) async {
    final note = await _repository.createDraft(documentJson: documentJson);
    
    final current = state.asData?.value ?? const <NoteModel>[];
    state = AsyncData([note, ...current.where((item) => item.id != note.id)]);
    
    // Sync to backend in background — use async/await + try/catch (not .catchError)
    Future.microtask(() async {
      try {
        await noteService.createNote(note);
        debugPrint('[Syncra] New note synced to cloud: ${note.id}');
      } catch (e) {
        debugPrint('[Syncra] Failed to sync new note: $e');
      }
    });
    
    return note;
  }

  Future<void> saveNote({
    required String id,
    required String documentJson,
  }) async {
    await _repository.saveNote(id: id, documentJson: documentJson);
    
    // Sync to backend in background
    Future.microtask(() async {
      try {
        await noteService.updateNote(id, documentJson: documentJson);
        debugPrint('[Syncra] Note update synced: $id');
      } catch (e) {
        debugPrint('[Syncra] Failed to sync note update: $e');
      }
    });
    
    // Reload local state silently
    final notes = await _repository.listNotes();
    state = AsyncData(notes);
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    
    final current = state.asData?.value ?? const <NoteModel>[];
    state = AsyncData(current.where((note) => note.id != id).toList());
    
    // Sync to backend in background
    Future.microtask(() async {
      try {
        await noteService.deleteNote(id);
        debugPrint('[Syncra] Note deleted from cloud: $id');
      } catch (e) {
        debugPrint('[Syncra] Failed to delete note from cloud: $e');
      }
    });
  }

  Future<void> togglePinned(String id) async {
    await _repository.togglePinned(id);
    // Pin status currently only exists locally
    final notes = await _repository.listNotes();
    state = AsyncData(notes);
  }
}
