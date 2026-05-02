import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/board_service.dart';
import '../../../core/models/board_model.dart';
import '../../../core/models/card_model.dart' as model;
import '../../../core/models/list_model.dart';
import '../../../ui_kit/components/layout/ambient_background.dart';
import '../../../ui_kit/components/surfaces/glass_panel.dart';
import '../../../ui_kit/theme/app_colors.dart';
import '../../../ui_kit/theme/typography.dart';

class BoardDetailScreen extends StatefulWidget {
  final String boardId;

  const BoardDetailScreen({super.key, required this.boardId});

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  Board? _board;
  List<BoardList> _lists = [];
  Map<String, List<model.Card>> _cards = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final board = await boardService.getBoard(widget.boardId);
      final lists = await boardService.getLists(widget.boardId);
      final cardsMap = <String, List<model.Card>>{};
      for (final list in lists) {
        cardsMap[list.id] = await boardService.getCards(list.id);
      }
      if (mounted) {
        setState(() {
          _board = board;
          _lists = lists;
          _cards = cardsMap;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load board.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addList() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('New List', style: AppTypography.h3),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'List name (e.g., To Do)',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Create',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;

    try {
      final list = await boardService.createList(
        boardId: widget.boardId,
        title: ctrl.text.trim(),
        orderIndex: _lists.length,
      );
      if (mounted) {
        setState(() {
          _lists.add(list);
          _cards[list.id] = [];
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to create list')));
      }
    }
  }

  Future<void> _addCard(BoardList list) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('New Card in "${list.title}"', style: AppTypography.h3),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Card title',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Add',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;

    try {
      final card = await boardService.createCard(
        boardId: widget.boardId,
        listId: list.id,
        title: ctrl.text.trim(),
        orderIndex: _cards[list.id]?.length ?? 0,
      );
      if (mounted) {
        setState(() => _cards[list.id] = [...?_cards[list.id], card]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add card')));
      }
    }
  }

  /// Called when a card is dragged to a different list
  Future<void> _moveCard(model.Card card, String targetListId) async {
    if (card.listId == targetListId) return;
    final sourceListId = card.listId;

    // Optimistic update
    setState(() {
      _cards[sourceListId]?.remove(card);
      final moved = card.copyWith(listId: targetListId);
      _cards[targetListId] = [...?_cards[targetListId], moved];
    });

    try {
      await boardService.moveCard(cardId: card.id, newListId: targetListId);
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _cards[targetListId]?.removeWhere((c) => c.id == card.id);
          _cards[sourceListId] = [...?_cards[sourceListId], card];
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to move card')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Text(
                          _board?.name ?? 'Board',
                          style: Theme.of(context).textTheme.headlineSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addList,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add List'),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildBoardBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: AppTypography.bodyMedium));
    }
    if (_lists.isEmpty) {
      return Center(
        child: GlassPanel(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.view_column_outlined,
                  size: 58,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 20),
                const Text('No lists yet', style: AppTypography.h2),
                const SizedBox(height: 8),
                const Text(
                  'Add a list to start organizing your work',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _addList,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add First List'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      itemCount: _lists.length,
      itemBuilder: (context, index) {
        final list = _lists[index];
        final cards = _cards[list.id] ?? [];
        return _KanbanColumn(
          list: list,
          cards: cards,
          allLists: _lists,
          onAddCard: () => _addCard(list),
          onMoveCard: _moveCard,
        );
      },
    );
  }
}

// ── Kanban Column ─────────────────────────────────────────────────────────────
class _KanbanColumn extends StatelessWidget {
  final BoardList list;
  final List<model.Card> cards;
  final List<BoardList> allLists;
  final VoidCallback onAddCard;
  final Future<void> Function(model.Card, String) onMoveCard;

  const _KanbanColumn({
    required this.list,
    required this.cards,
    required this.allLists,
    required this.onAddCard,
    required this.onMoveCard,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<model.Card>(
      onWillAcceptWithDetails: (details) => details.data.listId != list.id,
      onAcceptWithDetails: (details) => onMoveCard(details.data, list.id),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color:
                isHovered
                    ? AppColors.primaryFixed.withValues(alpha: 0.75)
                    : AppColors.glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isHovered
                      ? AppColors.primarySoft.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.8),
              width: isHovered ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        list.title,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cards.length}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              // Cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cards.length,
                  itemBuilder:
                      (context, index) => _CardTile(card: cards[index]),
                ),
              ),
              // Add card button
              InkWell(
                onTap: onAddCard,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Add card',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Draggable Card Tile ───────────────────────────────────────────────────────
class _CardTile extends StatelessWidget {
  final model.Card card;

  const _CardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Draggable<model.Card>(
      data: card,
      feedback: Material(
        color: Colors.transparent,
        child: _CardContent(card: card, isDragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _CardContent(card: card)),
      child: _CardContent(card: card),
    );
  }
}

class _CardContent extends StatelessWidget {
  final model.Card card;
  final bool isDragging;

  const _CardContent({required this.card, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isDragging ? 256 : null,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDragging
                ? AppColors.surface.withValues(alpha: 0.98)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isDragging
                  ? AppColors.primarySoft.withValues(alpha: 0.55)
                  : AppColors.border,
        ),
        boxShadow:
            isDragging
                ? [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (card.description != null && card.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              card.description!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
