import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/note_model.dart';

import '../../../ui_kit/components/layout/ambient_background.dart';
import '../../../ui_kit/components/surfaces/glass_panel.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/theme/typography.dart';
import '../application/notes_controller.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createNote() async {
    final note = await ref.read(notesControllerProvider.notifier).createDraft();
    if (mounted) context.push('/notes/${note.id}');
  }

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    final notesValue = ref.watch(notesControllerProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      color: c.surfaceLow,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16, vertical: 16),
          child: CustomScrollView(
            slivers: [
              // Top Bar
              SliverToBoxAdapter(
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Text('Notes', style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Autosave', style: AppTypography.label.copyWith(color: c.textMuted, fontSize: 11)),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              // Hero search
              SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Notes', style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 8),
                  Text('${notesValue.asData?.value.length ?? 0} notes in your workspace',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  GlassPanel(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      Padding(padding: const EdgeInsets.only(left: 12),
                          child: Icon(Icons.search_rounded, color: c.textMuted, size: 22)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search notes...',
                          border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero,
                        ),
                      )),
                      ElevatedButton.icon(
                        onPressed: _createNote,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New Note'),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              // Notes grid
              notesValue.when(
                loading: () => SliverToBoxAdapter(child: Center(
                  child: Padding(padding: const EdgeInsets.all(48),
                      child: CircularProgressIndicator(color: c.primary)),
                )),
                error: (e, _) => SliverToBoxAdapter(child: GlassPanel(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(children: [
                    Icon(Icons.error_outline_rounded, size: 42, color: c.textMuted),
                    const SizedBox(height: 12),
                    Text(e.toString(), style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ))),
                data: (notes) {
                  final filtered = _filterNotes(notes);
                  if (filtered.isEmpty) {
                    return SliverToBoxAdapter(child: GlassPanel(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(children: [
                        Icon(Icons.note_alt_outlined, size: 52, color: c.textMuted),
                        const SizedBox(height: 16),
                        Text(_query.trim().isEmpty ? 'No notes yet' : 'No matching notes',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(_query.trim().isEmpty ? 'Create a note to start writing' : 'Try a different search',
                            style: Theme.of(context).textTheme.bodyMedium),
                        if (_query.trim().isEmpty) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _createNote,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create Note'),
                          ),
                        ],
                      ]),
                    )));
                  }
                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360, crossAxisSpacing: 16,
                      mainAxisSpacing: 16, childAspectRatio: 1.1,
                    ),
                    delegate: SliverChildBuilderDelegate((ctx, index) {
                      final note = filtered[index];
                      final accent = AppPalette.columnAccentForIndex(index);
                      return _NoteCard(
                        note: note, accent: accent,
                        onOpen: () => context.push('/notes/${note.id}'),
                        onTogglePinned: () => ref.read(notesControllerProvider.notifier).togglePinned(note.id),
                        onDelete: () => ref.read(notesControllerProvider.notifier).deleteNote(note.id),
                      );
                    }, childCount: filtered.length),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<NoteModel> _filterNotes(List<NoteModel> notes) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return notes;
    return notes.where((n) => n.title.toLowerCase().contains(query) || n.preview.toLowerCase().contains(query)).toList();
  }
}

class _NoteCard extends StatefulWidget {
  final NoteModel note;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onTogglePinned;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.accent, required this.onOpen,
      required this.onTogglePinned, required this.onDelete});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _hovered ? (Matrix4.identity()..setTranslationRaw(0.0, -3.0, 0.0)) : Matrix4.identity(),
        child: GlassPanel(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: widget.onOpen,
            child: Row(children: [
              Container(width: 5, decoration: BoxDecoration(
                color: widget.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg), bottomLeft: Radius.circular(AppRadius.lg),
                ),
              )),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ), child: Icon(
                      widget.note.isPinned ? Icons.push_pin_rounded : Icons.description_outlined,
                      color: widget.accent, size: 18,
                    )),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Actions', icon: Icon(Icons.more_horiz_rounded, color: c.textMuted),
                      onSelected: (v) {
                        if (v == 'pin') widget.onTogglePinned();
                        if (v == 'delete') widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'pin', child: Text(widget.note.isPinned ? 'Unpin' : 'Pin')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(widget.note.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16)),
                  const SizedBox(height: 6),
                  Expanded(child: Text(widget.note.preview, maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Text('${widget.note.wordCount} words', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                    const Spacer(),
                    Text(_formatRelative(widget.note.updatedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ]),
                ]),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

String _formatRelative(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}
