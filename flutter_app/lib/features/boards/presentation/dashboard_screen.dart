import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/board_service.dart';
import '../../../core/models/board_model.dart';
import '../../../core/models/note_model.dart';
import '../../../features/notes/application/notes_controller.dart';
import '../../../ui_kit/components/buttons/app_buttons.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/theme/typography.dart';

// Simple Task Model for Dashboard demo
class DashboardTask {
  String id;
  String title;
  bool isDone;
  DashboardTask(this.id, this.title, this.isDone);
}

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
  
  final List<DashboardTask> _tasks = [
    DashboardTask('1', 'Send final project plan', false),
    DashboardTask('2', 'Review wireframes with team', false),
    DashboardTask('3', 'Update backend documentation', false),
  ];

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
    setState(() { _isLoading = true; _error = null; });
    try {
      final boards = await boardService.getBoards();
      if (!mounted) return;
      setState(() => _boards = boards..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        if (mounted) context.go('/login');
        return;
      }
      if (!mounted) return;
      setState(() => _error = 'Failed to load workspace.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load workspace.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBoard() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Board', style: Theme.of(ctx).textTheme.headlineSmall),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Board name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;

    try {
      final board = await boardService.createBoard(result);
      try {
        await boardService.createList(boardId: board.id, title: 'To Do', orderIndex: 0);
        await boardService.createList(boardId: board.id, title: 'In Progress', orderIndex: 1);
        await boardService.createList(boardId: board.id, title: 'Done', orderIndex: 2);
      } catch (_) {}
      if (!mounted) return;
      context.push('/boards/${board.id}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create board.')));
    }
  }

  void _addTask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Task', style: Theme.of(ctx).textTheme.headlineSmall),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'What needs to be done?'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.isNotEmpty) {
      setState(() {
        _tasks.insert(0, DashboardTask(DateTime.now().toString(), title, false));
      });
    }
  }

  void _toggleTask(DashboardTask task) {
    setState(() {
      task.isDone = !task.isDone;
    });
    if (task.isDone) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _tasks.remove(task));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    final notesValue = ref.watch(notesControllerProvider);
    final notes = notesValue.asData?.value ?? const <NoteModel>[];
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      color: c.surfaceLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border.withValues(alpha: 0.5)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search something or use AI',
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _createBoard,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Board'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.notifications_none_rounded, color: c.textSecondary, size: 20),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('JS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ],
            ),
          ),
          
          // ── Scrollable Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back, Sarah', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary, fontSize: 32)),
                      const SizedBox(height: 8),
                      Text('Here\'s what\'s happening today.', style: AppTypography.bodyLarge.copyWith(color: c.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Top Row: Overview Chart + Mini Stats
                  if (isDesktop)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 8, child: _buildOverviewChart(c)),
                          const SizedBox(width: 24),
                          Expanded(flex: 4, child: _buildMiniStats(c)),
                        ],
                      ),
                    )
                  else ...[
                    _buildOverviewChart(c),
                    const SizedBox(height: 24),
                    _buildMiniStats(c),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Bottom Row: Today's Tasks + Recent Notes
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: _buildTasksCard(c)),
                        const SizedBox(width: 24),
                        Expanded(flex: 6, child: _buildRecentNotesCard(c, notes)),
                      ],
                    )
                  else ...[
                    _buildTasksCard(c),
                    const SizedBox(height: 24),
                    _buildRecentNotesCard(c, notes),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksCard(SyncraColors c) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Today\'s Tasks', style: AppTypography.h2.copyWith(color: c.textPrimary, fontSize: 20)),
              IconButton(
                onPressed: _addTask,
                icon: const Icon(Icons.add),
                color: c.primary,
                hoverColor: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tasks.isEmpty
                ? Center(child: Text('All caught up!', style: TextStyle(color: c.textMuted)))
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return AnimatedOpacity(
                        key: ValueKey(task.id),
                        opacity: task.isDone ? 0.6 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.border.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _toggleTask(task),
                                child: Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: c.borderStrong, width: 1.5),
                                    color: task.isDone ? c.primarySoft : Colors.transparent,
                                  ),
                                  child: task.isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        color: c.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (!task.isDone) ...[
                                      const SizedBox(height: 4),
                                      Text('Due Today', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ),
                              if (!task.isDone && index == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('High', style: TextStyle(color: Color(0xFF93000A), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotesCard(SyncraColors c, List<NoteModel> notes) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Notes', style: AppTypography.h2.copyWith(color: c.textPrimary, fontSize: 20)),
              TextButton(
                onPressed: () => context.go('/notes'),
                child: Text('View All', style: TextStyle(color: c.primary, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notes.isEmpty
                ? Center(child: Text('No notes yet', style: TextStyle(color: c.textMuted)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: notes.take(4).length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return InkWell(
                        onTap: () => context.push('/notes/${note.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.border.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.description, color: index % 2 == 0 ? const Color(0xFF8455EF) : const Color(0xFF6063EE), size: 20),
                                  Text('2h ago', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(note.preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewChart(SyncraColors c) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overview Activity', style: AppTypography.h2.copyWith(color: c.textPrimary, fontSize: 20)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: c.primarySoft.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                child: Text('Weekly', style: AppTypography.label.copyWith(color: c.primary, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBar(c, 0.4, false),
                _buildBar(c, 0.6, false),
                _buildBar(c, 0.3, false),
                _buildBar(c, 0.8, true),
                _buildBar(c, 0.5, false),
                _buildBar(c, 0.7, false),
                _buildBar(c, 0.45, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(SyncraColors c, double heightFactor, bool isPeak) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isPeak ? c.primary.withValues(alpha: 0.8) : c.primary.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  boxShadow: isPeak ? [BoxShadow(color: c.primary.withValues(alpha: 0.3), blurRadius: 15)] : null,
                ),
              ),
              if (isPeak)
                Positioned(
                  top: -28,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: c.textPrimary, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Peak', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStats(SyncraColors c) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFF2170E4), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.task_alt, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text('Completed', style: AppTypography.bodyLarge.copyWith(color: c.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('128', style: AppTypography.display.copyWith(color: c.textPrimary, fontSize: 40, height: 1.1, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('+12% from last week', style: AppTypography.label.copyWith(color: const Color(0xFF8455EF), fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFF494BD6), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.schedule, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text('Hours Logged', style: AppTypography.bodyLarge.copyWith(color: c.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('34.5', style: AppTypography.display.copyWith(color: c.textPrimary, fontSize: 40, height: 1.1, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
