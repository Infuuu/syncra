import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/note_model.dart';
import '../../../ui_kit/components/buttons/app_buttons.dart';
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
    final notesValue = ref.watch(notesControllerProvider);

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _NotesTopBar(onBack: () => context.go('/')),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                SliverToBoxAdapter(
                  child: _NotesHero(
                    controller: _searchController,
                    noteCount: notesValue.asData?.value.length ?? 0,
                    onChanged: (value) => setState(() => _query = value),
                    onCreateNote: _createNote,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
                notesValue.when(
                  loading:
                      () => const SliverToBoxAdapter(
                        child: _StatusPanel(
                          icon: Icons.hourglass_top_rounded,
                          title: 'Loading notes',
                          message: 'Your local notes library is opening.',
                        ),
                      ),
                  error:
                      (error, _) => SliverToBoxAdapter(
                        child: _StatusPanel(
                          icon: Icons.error_outline_rounded,
                          title: 'Notes unavailable',
                          message: error.toString(),
                        ),
                      ),
                  data: (notes) {
                    final filtered = _filterNotes(notes);
                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _StatusPanel(
                          icon: Icons.note_alt_outlined,
                          title:
                              _query.trim().isEmpty
                                  ? 'No notes yet'
                                  : 'No matching notes',
                          message:
                              _query.trim().isEmpty
                                  ? 'Create a note and it will autosave locally while you write.'
                                  : 'Try a different title or body search.',
                          action: PrimaryButton(
                            onPressed: _createNote,
                            label: 'Create Note',
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ),
                      );
                    }

                    return SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 360,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.08,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final note = filtered[index];
                        return _NoteCard(
                          note: note,
                          onOpen: () => context.push('/notes/${note.id}'),
                          onTogglePinned:
                              () => ref
                                  .read(notesControllerProvider.notifier)
                                  .togglePinned(note.id),
                          onDelete:
                              () => ref
                                  .read(notesControllerProvider.notifier)
                                  .deleteNote(note.id),
                        );
                      }, childCount: filtered.length),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNote,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Note'),
      ),
    );
  }

  List<NoteModel> _filterNotes(List<NoteModel> notes) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return notes;
    return notes
        .where(
          (note) =>
              note.title.toLowerCase().contains(query) ||
              note.preview.toLowerCase().contains(query),
        )
        .toList();
  }
}

class _NotesTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _NotesTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to dashboard',
          ),
          Text('Notes', style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          Row(
            children: [
              const _SyncDot(),
              const SizedBox(width: 8),
              Text(
                'Local autosave',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotesHero extends StatelessWidget {
  final TextEditingController controller;
  final int noteCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onCreateNote;

  const _NotesHero({
    required this.controller,
    required this.noteCount,
    required this.onChanged,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 10),
          Text(
            '$noteCount notes in your workspace',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          GlassPanel(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search note titles and body text...',
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onCreateNote,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Write'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onOpen;
  final VoidCallback onTogglePinned;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onOpen,
    required this.onTogglePinned,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          note.isPinned
                              ? const Color(0x1AF7BD3E)
                              : const Color(0x14818CF8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      note.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.description_outlined,
                      color:
                          note.isPinned
                              ? AppColors.tertiary
                              : AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Note actions',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) {
                      if (value == 'pin') onTogglePinned();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(
                              note.isPinned ? 'Unpin note' : 'Pin note',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete note'),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                note.title,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  note.preview,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '${note.wordCount} words',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    _formatRelative(note.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 34),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

class _SyncDot extends StatelessWidget {
  const _SyncDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
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
