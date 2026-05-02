import '../api/api_client.dart';
import '../models/board_model.dart';
import '../models/list_model.dart';
import '../models/card_model.dart';

class BoardService {
  final _dio = apiClient;

  // ── Boards ───────────────────────────────────────────────────────────────
  Future<List<Board>> getBoards() async {
    final resp = await _dio.get('/boards');
    final items = resp.data['items'] as List<dynamic>;
    return items.map((e) => Board.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Board> createBoard(String name) async {
    final resp = await _dio.post('/boards', data: {'name': name});
    return Board.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Board> getBoard(String boardId) async {
    final resp = await _dio.get('/boards/$boardId');
    return Board.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Lists ────────────────────────────────────────────────────────────────
  Future<List<BoardList>> getLists(String boardId) async {
    final resp = await _dio.get('/lists/board/$boardId');
    final items = resp.data['items'] as List<dynamic>;
    return items
        .map((e) => BoardList.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BoardList> createList({
    required String boardId,
    required String title,
    required int orderIndex,
  }) async {
    final resp = await _dio.post(
      '/lists',
      data: {'boardId': boardId, 'title': title, 'orderIndex': orderIndex},
    );
    return BoardList.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Cards ────────────────────────────────────────────────────────────────
  Future<List<Card>> getCards(String listId) async {
    final resp = await _dio.get('/cards/list/$listId');
    final items = resp.data['items'] as List<dynamic>;
    return items.map((e) => Card.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Card> createCard({
    required String boardId,
    required String listId,
    required String title,
    required int orderIndex,
  }) async {
    final resp = await _dio.post(
      '/cards',
      data: {
        'boardId': boardId,
        'listId': listId,
        'title': title,
        'orderIndex': orderIndex,
      },
    );
    return Card.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Card> moveCard({
    required String cardId,
    required String newListId,
  }) async {
    final resp = await _dio.patch(
      '/cards/$cardId',
      data: {'listId': newListId},
    );
    return Card.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Card> updateCard({
    required String cardId,
    String? title,
    String? description,
    String? listId,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title;
    if (description != null) patch['description'] = description;
    if (listId != null) patch['listId'] = listId;
    final resp = await _dio.patch('/cards/$cardId', data: patch);
    return Card.fromJson(resp.data as Map<String, dynamic>);
  }
}

final boardService = BoardService();
