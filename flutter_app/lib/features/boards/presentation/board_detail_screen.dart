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
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Icon(Icons.arrow_back, color: c.textPrimary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _editingTitle
                        ? TextField(
                            controller: _titleController, autofocus: true,
                            style: AppTypography.h1.copyWith(color: c.textPrimary, fontSize: 32, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
                            onSubmitted: (_) => setState(() => _editingTitle = false),
                          )
                        : GestureDetector(
                            onTap: () => setState(() => _editingTitle = true),
                            child: Text(_board?.name ?? 'Board',
                              style: AppTypography.h1.copyWith(color: c.textPrimary, fontSize: 32, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                  InkWell(
                    onTap: _addList,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, color: c.primary, size: 18),
                          const SizedBox(width: 8),
                          Text('Add List', style: AppTypography.label.copyWith(color: c.primary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(c)),
          ],
        ),
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
          width: 320,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isHovered ? c.primary.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(list.title, style: AppTypography.h2.copyWith(color: c.textPrimary, fontSize: 16)),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c.surfaceHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${cards.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.more_horiz, color: c.textMuted, size: 20),
                  ],
                ),
              ),
              // Cards
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cards.length,
                  itemBuilder: (_, i) => _CardTile(card: cards[i], accent: accent),
                ),
              ),
              // Add card button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: InkWell(
                  onTap: onAddCard,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: c.textMuted.withValues(alpha: 0.3), style: BorderStyle.none),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 18, color: c.textMuted),
                        const SizedBox(width: 8),
                        Text('Add Task', style: AppTypography.label.copyWith(color: c.textMuted, fontSize: 14)),
                      ],
                    ),
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

class _CardTile extends StatefulWidget {
  final model.Card card;
  final Color accent;
  const _CardTile({required this.card, required this.accent});

  @override
  State<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<_CardTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Draggable<model.Card>(
      data: widget.card,
      feedback: Material(color: Colors.transparent, child: _buildContent(c, isDragging: true)),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildContent(c)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: _buildContent(c),
      ),
    );
  }

  Widget _buildContent(SyncraColors c, {bool isDragging = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: _hovered ? (Matrix4.identity()..setTranslationRaw(0.0, -2.0, 0.0)) : Matrix4.identity(),
      width: isDragging ? 280 : null,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: _hovered || isDragging
            ? [BoxShadow(color: c.primary.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD6),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('HIGH PRIORITY', style: TextStyle(color: Color(0xFF93000A), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.card.title, style: AppTypography.label.copyWith(color: _hovered ? c.primary : c.textPrimary, fontSize: 14)),
          if (widget.card.description != null && widget.card.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.card.description!, style: AppTypography.bodyMedium.copyWith(color: c.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 16, color: c.textMuted),
                  const SizedBox(width: 4),
                  Text('3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textMuted)),
                  const SizedBox(width: 12),
                  Icon(Icons.attachment, size: 16, color: c.textMuted),
                  const SizedBox(width: 4),
                  Text('1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textMuted)),
                ],
              ),
              const CircleAvatar(
                radius: 12,
                backgroundImage: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuCsjm9E5SrW4wBtnQiUOd7hvBBUJrxKMKGAvPQTZqcKFkXSzu4RN0ti1Nzzof8WQB1QWoKPYncVl3sW0h5mhe5ZnYZ7u4wx0wr7jh1VUP-TA84FibCNziLm7GwjALb-F0hvCZ5Hz-LfoTjnUkSQz6iAfED2qha9Cw7uDHtpNKErhR-jACV6_PmdzmpwU0IPoJIeiOAgZqBCbesgvQ6RJHgV3rED-BRcuIlf4yrw9bPJJG5VyToqcYe17JZSqH5LzFaoC2NvhiFcM9lv'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
