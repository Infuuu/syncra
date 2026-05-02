import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/board_service.dart';
import '../../../core/models/board_model.dart';
import '../../../core/models/note_model.dart';
import '../../../features/notes/application/notes_controller.dart';
import '../../../ui_kit/components/buttons/app_buttons.dart';
import '../../../ui_kit/components/layout/ambient_background.dart';
import '../../../ui_kit/components/surfaces/glass_panel.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/theme/typography.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Board> _boards = [];
  bool _isLoading = true;
  String? _error;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBoards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final boards = await boardService.getBoards();
      if (!mounted) return;
      setState(() {
        _boards = boards..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      });
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        if (mounted) context.go('/login');
        return;
      }
      if (!mounted) return;
      setState(() => _error = 'Failed to load your workspace.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load your workspace.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBoard() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Create board',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Board name'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || result.isEmpty) return;

    try {
      final board = await boardService.createBoard(result);
      if (!mounted) return;
      setState(() => _boards = [board, ..._boards]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create board.')));
    }
  }

  void _handleSideNavTap(int index) {
    setState(() => _selectedNavIndex = index);
    if (index == 1) context.go('/notes');
  }

  @override
  Widget build(BuildContext context) {
    final notesValue = ref.watch(notesControllerProvider);
    final notes = notesValue.asData?.value ?? const <NoteModel>[];
    final query = _searchController.text.trim().toLowerCase();
    final visibleBoards =
        query.isEmpty
            ? _boards
            : _boards
                .where((board) => board.name.toLowerCase().contains(query))
                .toList();
    final visibleNotes =
        query.isEmpty
            ? notes
            : notes
                .where(
                  (note) =>
                      note.title.toLowerCase().contains(query) ||
                      note.preview.toLowerCase().contains(query),
                )
                .toList();

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1080;
    final stats = _DashboardStats.fromData(_boards, notes);
    final activity = _buildActivity(_boards, notes).take(6).toList();

    return Scaffold(
      body: AmbientBackground(
        child: Stack(
          children: [
            if (isDesktop)
              _DashboardSidebar(
                selectedIndex: _selectedNavIndex,
                boardCount: _boards.length,
                noteCount: notes.length,
                onSelect: _handleSideNavTap,
              ),
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    _DashboardTopBar(
                      isDesktop: isDesktop,
                      onCreateNote: () => context.push('/notes/new'),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 304 : 16,
                          24,
                          16,
                          isDesktop ? 40 : 120,
                        ),
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: _HeroSection(
                                controller: _searchController,
                                boardCount: _boards.length,
                                noteCount: notes.length,
                                onChanged: (_) => setState(() {}),
                                onCreateBoard: _createBoard,
                                onCreateNote: () => context.push('/notes/new'),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: const SizedBox(height: 24),
                            ),
                            SliverToBoxAdapter(
                              child: _StatsGrid(
                                stats: stats,
                                isDesktop: isDesktop,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: const SizedBox(height: 24),
                            ),
                            SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: 'Recent Boards',
                                actionLabel: 'Open Notes',
                                onActionPressed: () => context.go('/notes'),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: const SizedBox(height: 16),
                            ),
                            SliverToBoxAdapter(
                              child: _buildBoardSection(
                                visibleBoards,
                                query,
                                isDesktop,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: const SizedBox(height: 28),
                            ),
                            SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: 'Recent Notes',
                                actionLabel: 'New Note',
                                onActionPressed: () => context.push('/notes/new'),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: const SizedBox(height: 16),
                            ),
                            SliverToBoxAdapter(
                              child: _RecentNotesPanel(
                                notes: visibleNotes.take(4).toList(),
                                query: query,
                                onOpenNote:
                                    (note) => context.push('/notes/${note.id}'),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: const SizedBox(height: 28),
                            ),
                            SliverToBoxAdapter(
                              child: _SectionHeader(
                                title: 'Activity',
                                actionLabel: 'Refresh',
                                onActionPressed: _loadBoards,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: const SizedBox(height: 16),
                            ),
                            SliverToBoxAdapter(
                              child: _ActivityPanel(
                                items: activity,
                                isLoading: _isLoading,
                                error: _error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isDesktop)
              _MobileBottomNav(
                selectedIndex: _selectedNavIndex,
                onSelect: _handleSideNavTap,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardSection(List<Board> boards, String query, bool isDesktop) {
    if (_isLoading) {
      return const _StatusCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Loading workspace',
        message: 'Fetching your latest boards and notes overview.',
      );
    }
    if (_error != null) {
      return _StatusCard(
        icon: Icons.error_outline_rounded,
        title: 'Workspace unavailable',
        message: _error!,
      );
    }
    if (boards.isEmpty) {
      return _StatusCard(
        icon: Icons.dashboard_outlined,
        title: query.isEmpty ? 'No boards yet' : 'No matching boards',
        message:
            query.isEmpty
                ? 'Create your first board to start organizing collaborative work.'
                : 'Try a different search term or clear the search field.',
      );
    }

    final featured = boards.first;
    final secondary = boards.skip(1).take(2).toList();
    while (secondary.length < math.min(2, boards.length)) {
      secondary.add(featured);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!isDesktop) {
          return Column(
            children:
                boards
                    .map(
                      (board) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _BoardCard(
                          board: board,
                          featured: false,
                          onTap: () => context.push('/boards/${board.id}'),
                        ),
                      ),
                    )
                    .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _BoardCard(
                board: featured,
                featured: true,
                onTap: () => context.push('/boards/${featured.id}'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children:
                    secondary
                        .map(
                          (board) => Padding(
                            padding: EdgeInsets.only(
                              bottom: board == secondary.last ? 0 : 16,
                            ),
                            child: _BoardCard(
                              board: board,
                              featured: false,
                              onTap: () => context.push('/boards/${board.id}'),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_ActivityItem> _buildActivity(
    List<Board> boards,
    List<NoteModel> notes,
  ) {
    final items = <_ActivityItem>[
      ...boards.map(
        (board) => _ActivityItem(
          icon: Icons.space_dashboard_rounded,
          title: 'Board updated',
          subtitle: board.name,
          timestamp: board.updatedAt,
        ),
      ),
      ...notes.map(
        (note) => _ActivityItem(
          icon: Icons.edit_note_rounded,
          title: note.title,
          subtitle: note.preview,
          timestamp: note.updatedAt,
        ),
      ),
    ];
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }
}

class _DashboardStats {
  final int boardCount;
  final int noteCount;
  final int pinnedNotes;
  final String latestUpdate;

  const _DashboardStats({
    required this.boardCount,
    required this.noteCount,
    required this.pinnedNotes,
    required this.latestUpdate,
  });

  factory _DashboardStats.fromData(List<Board> boards, List<NoteModel> notes) {
    final latestTimes = [
      ...boards.map((board) => board.updatedAt),
      ...notes.map((note) => note.updatedAt),
    ]..sort((a, b) => b.compareTo(a));
    return _DashboardStats(
      boardCount: boards.length,
      noteCount: notes.length,
      pinnedNotes: notes.where((note) => note.isPinned).length,
      latestUpdate:
          latestTimes.isEmpty
              ? 'No activity yet'
              : _formatRelative(latestTimes.first),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final int boardCount;
  final int noteCount;
  final ValueChanged<int> onSelect;

  const _DashboardSidebar({
    required this.selectedIndex,
    required this.boardCount,
    required this.noteCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.folder_copy_outlined, 'Notebooks', boardCount),
      (Icons.description_outlined, 'All Notes', noteCount),
      (Icons.sell_outlined, 'Tags', null),
      (Icons.delete_outline_rounded, 'Trash', null),
      (Icons.archive_outlined, 'Archive', null),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(top: 12, bottom: 12),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [AppColors.primarySoft, AppColors.secondary],
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Workspace',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$noteCount notes across $boardCount boards',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              ...List.generate(items.length, (index) {
                final item = items[index];
                final selected = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelect(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? const Color(0x1A818CF8)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.$1,
                            color:
                                selected
                                    ? AppColors.primarySoft
                                    : AppColors.textMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.$2,
                              style: AppTypography.bodyMedium.copyWith(
                                color:
                                    selected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                fontWeight:
                                    selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (item.$3 != null)
                            Text('${item.$3}', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              Text(
                'Syncra.',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback onCreateNote;

  const _DashboardTopBar({required this.isDesktop, required this.onCreateNote});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 304 : 16, 12, 16, 0),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        child: Row(
          children: [
            if (!isDesktop)
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.menu_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: onCreateNote,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Note'),
            ),
            const SizedBox(width: 12),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final TextEditingController controller;
  final int boardCount;
  final int noteCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onCreateBoard;
  final VoidCallback onCreateNote;

  const _HeroSection({
    required this.controller,
    required this.boardCount,
    required this.noteCount,
    required this.onChanged,
    required this.onCreateBoard,
    required this.onCreateNote,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            'A unified workspace for boards, notes, and collaborative context.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
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
                      hintText:
                          'Search notes, boards, and workspace context...',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onCreateBoard,
                  icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
                  label: const Text('New Board'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onCreateNote,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('New Note'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniPill(label: '$boardCount boards active'),
              _MiniPill(label: '$noteCount notes synced locally'),
              const _MiniPill(label: 'Offline-first workspace ready'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;

  const _MiniPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final _DashboardStats stats;
  final bool isDesktop;

  const _StatsGrid({required this.stats, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Boards', '${stats.boardCount}', Icons.dashboard_outlined),
      ('Notes', '${stats.noteCount}', Icons.edit_note_rounded),
      ('Pinned', '${stats.pinnedNotes}', Icons.push_pin_outlined),
      ('Latest', stats.latestUpdate, Icons.bolt_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 1.55 : 1.3,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x14818CF8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.$3, color: AppColors.primary),
              ),
              const Spacer(),
              Text(item.$2, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(item.$1, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onActionPressed;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        GhostButton(onPressed: onActionPressed, label: actionLabel),
      ],
    );
  }
}

class _BoardCard extends StatelessWidget {
  final Board board;
  final bool featured;
  final VoidCallback onTap;

  const _BoardCard({
    required this.board,
    required this.featured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientFor(board.id);
    return GlassPanel(
      height: featured ? 320 : 152,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: featured ? 5 : 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  gradient: gradient,
                ),
                padding: const EdgeInsets.all(22),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      featured ? 'Featured Board' : 'Board',
                      style: AppTypography.label.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      board.name,
                      maxLines: featured ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Updated ${_formatRelative(board.updatedAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (featured) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Open the board to manage lists, cards, and real-time collaboration state.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _gradientFor(String seed) {
    final palettes = [
      const [Color(0xFF818CF8), Color(0xFF4953BC)],
      const [Color(0xFFF7BD3E), Color(0xFFB26D00)],
      const [Color(0xFF87D4C1), Color(0xFF1D7C58)],
      const [Color(0xFFFFB7C8), Color(0xFFB54868)],
    ];
    final palette =
        palettes[seed.codeUnits.fold<int>(0, (sum, char) => sum + char) %
            palettes.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: palette,
    );
  }
}

class _RecentNotesPanel extends StatelessWidget {
  final List<NoteModel> notes;
  final String query;
  final ValueChanged<NoteModel> onOpenNote;

  const _RecentNotesPanel({
    required this.notes,
    required this.query,
    required this.onOpenNote,
  });

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return _StatusCard(
        icon: Icons.note_alt_outlined,
        title: query.isEmpty ? 'No notes yet' : 'No matching notes',
        message:
            query.isEmpty
                ? 'Notes you create in the editor will appear here automatically.'
                : 'Try a different search term to find the right note.',
      );
    }

    return Column(
      children:
          notes
              .map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassPanel(
                    child: ListTile(
                      onTap: () => onOpenNote(note),
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
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
                      title: Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        note.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Text(
                        _formatRelative(note.updatedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
}

class _ActivityPanel extends StatelessWidget {
  final List<_ActivityItem> items;
  final bool isLoading;
  final String? error;

  const _ActivityPanel({
    required this.items,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const _StatusCard(
        icon: Icons.hourglass_empty_rounded,
        title: 'Activity is loading',
        message: 'Recent changes will appear here in a moment.',
      );
    }
    if (error != null && items.isEmpty) {
      return _StatusCard(
        icon: Icons.error_outline_rounded,
        title: 'Activity unavailable',
        message: error!,
      );
    }
    if (items.isEmpty) {
      return const _StatusCard(
        icon: Icons.bolt_outlined,
        title: 'No recent activity',
        message:
            'Start editing boards or notes to build your workspace timeline.',
      );
    }

    return GlassPanel(
      child: Column(
        children:
            items
                .asMap()
                .entries
                .map(
                  (entry) => Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0x14818CF8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            entry.value.icon,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          entry.value.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          entry.value.subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          _formatRelative(entry.value.timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (entry.key != items.length - 1)
                        Divider(color: AppColors.border.withValues(alpha: 0.6)),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, size: 42, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _MobileBottomNav({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.description_outlined, 'Notes'),
      (Icons.search_rounded, 'Search'),
      (Icons.settings_outlined, 'Settings'),
    ];

    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: Center(
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          borderRadius: BorderRadius.circular(999),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == selectedIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color:
                      selected ? const Color(0x1A818CF8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onSelect(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.$1,
                            size: 20,
                            color:
                                selected
                                    ? AppColors.primarySoft
                                    : AppColors.textMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: AppTypography.label.copyWith(
                              color:
                                  selected
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
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
