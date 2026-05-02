import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/token_storage.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/boards/presentation/dashboard_screen.dart';
import '../../features/boards/presentation/board_detail_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/notes/presentation/note_editor_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final hasToken = await TokenStorage.hasToken();
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!hasToken && !isAuthRoute) return '/login';
      if (hasToken && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(
        path: '/boards/:boardId',
        builder: (context, state) {
          final boardId = state.pathParameters['boardId']!;
          return BoardDetailScreen(boardId: boardId);
        },
      ),
      GoRoute(path: '/notes', builder: (context, state) => const NotesScreen()),
      GoRoute(
        path: '/notes/new',
        builder: (context, state) => const NoteEditorScreen(),
      ),
      GoRoute(
        path: '/notes/:noteId',
        builder: (context, state) {
          final noteId = state.pathParameters['noteId']!;
          return NoteEditorScreen(noteId: noteId);
        },
      ),
    ],
  );
});
