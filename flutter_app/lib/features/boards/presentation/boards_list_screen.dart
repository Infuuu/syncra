import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/board_service.dart';
import '../../../core/models/board_model.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/theme/typography.dart';

class BoardsListScreen extends ConsumerStatefulWidget {
  const BoardsListScreen({super.key});
  @override
  ConsumerState<BoardsListScreen> createState() => _BoardsListScreenState();
}

class _BoardsListScreenState extends ConsumerState<BoardsListScreen> {
  List<Board> _boards = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBoards();
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
      setState(() => _error = 'Failed to load boards.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load boards.');
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

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Container(
      color: c.surfaceLow,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              if (isDesktop)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('All Boards', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary, fontSize: 32)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _loadBoards,
                          icon: Icon(Icons.refresh_rounded, color: c.textMuted),
                          tooltip: 'Refresh boards',
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
                      ],
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Boards', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary, fontSize: 28)),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _loadBoards,
                              icon: Icon(Icons.refresh_rounded, color: c.textMuted),
                            ),
                            ElevatedButton.icon(
                              onPressed: _createBoard,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('New'),
                              style: ElevatedButton.styleFrom(elevation: 0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              
              // Boards Grid
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: c.primary))
                    : _error != null
                        ? Center(child: Text(_error!, style: TextStyle(color: c.error)))
                        : _boards.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.dashboard_customize_outlined, size: 52, color: c.textMuted),
                                    const SizedBox(height: 16),
                                    Text('No boards yet', style: Theme.of(context).textTheme.headlineSmall),
                                    const SizedBox(height: 8),
                                    Text('Create a board to start organizing your tasks.', style: TextStyle(color: c.textSecondary)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadBoards,
                                color: c.primary,
                                backgroundColor: c.surface,
                                child: GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 320,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.5,
                                  ),
                                  itemCount: _boards.length,
                                  itemBuilder: (ctx, index) {
                                    final board = _boards[index];
                                    return _BoardCard(
                                      board: board,
                                      onOpen: () => context.push('/boards/${board.id}'),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardCard extends StatefulWidget {
  final Board board;
  final VoidCallback onOpen;

  const _BoardCard({required this.board, required this.onOpen});

  @override
  State<_BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<_BoardCard> {
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: c.primarySoft.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.view_kanban_rounded, color: c.primary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.board.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.h3.copyWith(color: c.textPrimary, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text('Updated recently', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
