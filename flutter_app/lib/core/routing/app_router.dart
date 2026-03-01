import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/boards/presentation/dashboard_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/notes/presentation/note_editor_screen.dart';

/// Riverpod provider for GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login', // TODO: Dynamically set based on Auth state
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/notes', builder: (context, state) => const NotesScreen()),
      GoRoute(
        path: '/notes/new',
        builder: (context, state) {
          final initialJson = state.extra as String?;
          return NoteEditorScreen(initialJson: initialJson);
        },
      ),
    ],
  );
});
