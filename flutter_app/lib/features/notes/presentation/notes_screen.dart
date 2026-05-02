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
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Search
              Row(
                children: [
                  Text('Notes', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary, fontSize: 32)),
                  const Spacer(),
                  Container(
                    width: 300,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border.withValues(alpha: 0.5)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _createNote,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Note'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Filters
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildFilterChip(c, 'All Notes', true),
                      const SizedBox(width: 8),
                      _buildFilterChip(c, 'Personal', false),
                      const SizedBox(width: 8),
                      _buildFilterChip(c, 'Work', false),
                      const SizedBox(width: 8),
                      _buildFilterChip(c, 'Ideas', false),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.border.withValues(alpha: 0.5)),
                        ),
                        child: Icon(Icons.grid_view_rounded, size: 20, color: c.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.view_list_rounded, size: 20, color: c.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Notes Grid
              Expanded(
                child: notesValue.when(
                  loading: () => Center(child: CircularProgressIndicator(color: c.primary)),
                  error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: c.error))),
                  data: (notes) {
                    final filtered = _filterNotes(notes);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.note_alt_outlined, size: 52, color: c.textMuted),
                            const SizedBox(height: 16),
                            Text('No notes yet', style: Theme.of(context).textTheme.headlineSmall),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320, crossAxisSpacing: 16,
                        mainAxisSpacing: 16, childAspectRatio: 1.1,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) {
                        final note = filtered[index];
                        final accent = AppPalette.columnAccentForIndex(index);
                        return _NoteCard(
                          note: note, accent: accent,
                          onOpen: () => context.push('/notes/${note.id}'),
                          onTogglePinned: () => ref.read(notesControllerProvider.notifier).togglePinned(note.id),
                          onDelete: () => ref.read(notesControllerProvider.notifier).deleteNote(note.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(SyncraColors c, String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : c.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: isSelected ? c.primary.withValues(alpha: 0.2) : c.border.withValues(alpha: 0.5)),
        boxShadow: isSelected ? [BoxShadow(color: c.primary.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
      ),
      child: Text(label, style: AppTypography.label.copyWith(color: isSelected ? c.primary : c.textSecondary, fontSize: 13)),
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
        transform: _hovered ? (Matrix4.identity()..setTranslationRaw(0.0, -4.0, 0.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          boxShadow: _hovered ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('WORK', style: AppTypography.label.copyWith(color: c.textSecondary, fontSize: 11, letterSpacing: 1)),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: c.textMuted, size: 20),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'pin') widget.onTogglePinned();
                        if (v == 'delete') widget.onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'pin', child: Text(widget.note.isPinned ? 'Unpin' : 'Pin')),
                        const PopupMenuItem(value: 'delete', child: const Text('Delete')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.note.title, style: AppTypography.h3.copyWith(color: c.textPrimary, fontSize: 18), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(widget.note.preview, style: AppTypography.bodyMedium.copyWith(color: c.textSecondary, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.3)))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatRelative(widget.note.updatedAt), style: TextStyle(color: c.textMuted, fontSize: 12)),
                        Icon(widget.note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: c.textMuted, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
