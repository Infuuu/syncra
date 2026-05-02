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
  bool _editingTitle = false;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
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
          _titleController.text = board.name;
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
      builder: (ctx) => AlertDialog(
        title: Text('New List', style: Theme.of(ctx).textTheme.headlineSmall),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    try {
      final list = await boardService.createList(
        boardId: widget.boardId, title: ctrl.text.trim(), orderIndex: _lists.length,
      );
      if (mounted) setState(() { _lists.add(list); _cards[list.id] = []; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create list')));
    }
  }

  Future<void> _addCard(BoardList list) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Card', style: Theme.of(ctx).textTheme.headlineSmall),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'Card title'),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    try {
      final card = await boardService.createCard(
        boardId: widget.boardId, listId: list.id,
        title: ctrl.text.trim(), orderIndex: _cards[list.id]?.length ?? 0,
      );
      if (mounted) setState(() => _cards[list.id] = [...?_cards[list.id], card]);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add card')));
    }
  }

  Future<void> _moveCard(model.Card card, String targetListId) async {
    if (card.listId == targetListId) return;
    final sourceListId = card.listId;
    setState(() {
      _cards[sourceListId]?.remove(card);
      _cards[targetListId] = [...?_cards[targetListId], card.copyWith(listId: targetListId)];
    });
    try {
      await boardService.moveCard(cardId: card.id, newListId: targetListId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _cards[targetListId]?.removeWhere((c) => c.id == card.id);
          _cards[sourceListId] = [...?_cards[sourceListId], card];
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to move card')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Container(
      color: c.surfaceLow,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: _editingTitle
                      ? TextField(
                          controller: _titleController, autofocus: true,
                          style: Theme.of(context).textTheme.headlineSmall,
                          decoration: const InputDecoration(border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
                          onSubmitted: (_) => setState(() => _editingTitle = false),
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _editingTitle = true),
                          child: Text(_board?.name ?? 'Board',
                            style: Theme.of(context).textTheme.headlineSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                TextButton.icon(
                  onPressed: _addList,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add List'),
                ),
              ]),
            ),
          ),
          Expanded(child: _buildBody(c)),
        ]),
      ),
    );
  }

  Widget _buildBody(SyncraColors c) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: c.primary));
    if (_error != null) return Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium));
    if (_lists.isEmpty) {
      return Center(child: GlassPanel(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.view_column_outlined, size: 52, color: c.textMuted),
          const SizedBox(height: 16),
          Text('No lists yet', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Add a list to start organizing', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          ElevatedButton.icon(onPressed: _addList, icon: const Icon(Icons.add_rounded), label: const Text('Add List')),
        ]),
      )));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      itemCount: _lists.length,
      itemBuilder: (context, index) {
        final list = _lists[index];
        final accent = AppPalette.columnAccentForIndex(index);
        return _KanbanColumn(
          list: list, cards: _cards[list.id] ?? [],
          accent: accent, allLists: _lists,
          onAddCard: () => _addCard(list),
          onMoveCard: _moveCard,
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final BoardList list;
  final List<model.Card> cards;
  final Color accent;
  final List<BoardList> allLists;
  final VoidCallback onAddCard;
  final Future<void> Function(model.Card, String) onMoveCard;

  const _KanbanColumn({
    required this.list, required this.cards, required this.accent,
    required this.allLists, required this.onAddCard, required this.onMoveCard,
  });

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return DragTarget<model.Card>(
      onWillAcceptWithDetails: (d) => d.data.listId != list.id,
      onAcceptWithDetails: (d) => onMoveCard(d.data, list.id),
      builder: (context, candidateData, _) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          width: 300, margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isHovered ? accent.withValues(alpha: 0.08) : c.glass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered ? accent.withValues(alpha: 0.4) : c.border,
              width: isHovered ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column header with accent
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: accent, shape: BoxShape.circle,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: Text(list.title, style: AppTypography.h3.copyWith(color: c.textPrimary),
                      overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${cards.length}', style: AppTypography.label.copyWith(color: accent)),
                  ),
                ]),
              ),
              // Cards
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: cards.length,
                itemBuilder: (_, i) => _CardTile(card: cards[i], accent: accent),
              )),
              // Add card
              InkWell(
                onTap: onAddCard,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Icon(Icons.add, size: 16, color: c.textMuted),
                    const SizedBox(width: 6),
                    Text('Add card', style: AppTypography.bodySmall.copyWith(color: c.textMuted)),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  final model.Card card;
  final Color accent;
  const _CardTile({required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Draggable<model.Card>(
      data: card,
      feedback: Material(color: Colors.transparent, child: _buildContent(c, isDragging: true)),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildContent(c)),
      child: _buildContent(c),
    );
  }

  Widget _buildContent(SyncraColors c, {bool isDragging = false}) {
    return Container(
      width: isDragging ? 270 : null,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDragging ? accent.withValues(alpha: 0.5) : c.border),
        boxShadow: isDragging ? [BoxShadow(color: c.shadow, blurRadius: 16, offset: const Offset(0, 8))] : null,
      ),
      child: Row(children: [
        Container(width: 4, height: 56, decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.7),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12), bottomLeft: Radius.circular(12),
          ),
        )),
        Expanded(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.title, style: AppTypography.bodyMedium.copyWith(color: c.textPrimary, fontWeight: FontWeight.w500)),
            if (card.description != null && card.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(card.description!, style: AppTypography.bodySmall.copyWith(color: c.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        )),
      ]),
    );
  }
}
