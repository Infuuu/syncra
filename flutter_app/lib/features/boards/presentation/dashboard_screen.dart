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
                  // Top Row: Tasks, Recent Notes, Stats
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTasksCard(c)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildRecentNotesCard(c, notes)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildStatsCard(c)),
                      ],
                    )
                  else ...[
                    _buildTasksCard(c),
                    const SizedBox(height: 24),
                    _buildRecentNotesCard(c, notes),
                    const SizedBox(height: 24),
                    _buildStatsCard(c),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Boards Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Boards', style: Theme.of(context).textTheme.headlineSmall),
                      TextButton(onPressed: () {}, child: const Text('See All')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBoardsGrid(c),
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
      height: 320,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Today\'s Tasks', style: AppTypography.h3.copyWith(color: c.textPrimary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.surfaceHighest, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_tasks.length}', style: AppTypography.label.copyWith(color: c.textSecondary)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text('See All', style: TextStyle(fontSize: 13)),
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
                        opacity: task.isDone ? 0.3 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _toggleTask(task),
                                child: Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: task.isDone ? c.success : c.borderStrong, width: 2),
                                    color: task.isDone ? c.success : Colors.transparent,
                                  ),
                                  child: task.isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                    const SizedBox(height: 2),
                                    Text('Syncra Workspace', style: TextStyle(color: c.primary, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          TextButton.icon(
            onPressed: _addTask,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Task'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotesCard(SyncraColors c, List<NoteModel> notes) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Recent Notes', style: AppTypography.h3.copyWith(color: c.textPrimary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.surfaceHighest, borderRadius: BorderRadius.circular(10)),
                    child: Text('${notes.length}', style: AppTypography.label.copyWith(color: c.textSecondary)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/notes'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text('See All', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notes.isEmpty
                ? Center(child: Text('No notes yet', style: TextStyle(color: c.textMuted)))
                : ListView.builder(
                    itemCount: notes.take(3).length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () => context.push('/notes/${note.id}'),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: c.secondaryFixed,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.description_rounded, color: c.secondary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(note.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/notes/new'),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Note'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(SyncraColors c) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overview', style: AppTypography.h3.copyWith(color: c.textPrimary)),
            ],
          ),
          const Spacer(),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140, height: 140,
                  child: CircularProgressIndicator(
                    value: 0.7,
                    strokeWidth: 20,
                    backgroundColor: c.surfaceHighest,
                    color: c.primarySoft,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_boards.length}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    Text('Boards', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatDot(c.primarySoft, 'Active'),
              _buildStatDot(c.surfaceHighest, 'Archived'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildBoardsGrid(SyncraColors c) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_boards.isEmpty) return const Center(child: Text('No boards created.'));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _boards.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) {
        final board = _boards[index];
        return InkWell(
          onTap: () => context.push('/boards/${board.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border.withValues(alpha: 0.5)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 28,
                      child: Stack(
                        children: [
                          const Positioned(
                            left: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=1'),
                            ),
                          ),
                          const Positioned(
                            left: 18,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=5'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(8)),
                      child: Text('Active', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(board.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(height: 4, decoration: BoxDecoration(color: c.surfaceHighest, borderRadius: BorderRadius.circular(2))),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: Container(height: 4, decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress', style: TextStyle(fontSize: 11, color: c.textMuted)),
                    Text('60%', style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
