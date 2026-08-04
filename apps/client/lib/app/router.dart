import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../desktop/pages/home_page.dart';
import '../desktop/pages/library_page.dart';
import '../desktop/pages/graph_page.dart';
import '../desktop/pages/ai_page.dart';
import '../desktop/pages/search_page.dart';
import '../desktop/pages/settings_page.dart';
import '../desktop/pages/reader_page.dart';
import '../desktop/pages/editor_page.dart';
import '../desktop/pages/wiki_page.dart';
import '../desktop/pages/qa_page.dart';
import '../desktop/desktop_shell.dart';
import '../mobile/mobile_shell.dart';

/// Responsive shell that picks Desktop or Mobile layout.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.child});

  final Widget child;

  static const double _mobileBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _mobileBreakpoint) {
          return MobileShell(child: child);
        }
        return DesktopShell(child: child);
      },
    );
  }
}

/// Custom fade transition page.
class FadeTransitionPage extends CustomTransitionPage<void> {
  FadeTransitionPage({required super.child})
      : super(
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}

/// Observes page-route push/pop so pages (e.g. ReaderPage) can refresh when
/// the user returns to them from a pushed route (e.g. coming back from the
/// editor). Subscribed via `RouteAware` in `didChangeDependencies`.
final routeObserver = RouteObserver<PageRoute<void>>();

/// Application router configuration.
final appRouter = GoRouter(
  initialLocation: '/home',
  observers: [routeObserver],
  routes: [
    ShellRoute(
      builder: (context, state, child) => ResponsiveShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomePage(),
          ),
        ),
        GoRoute(
          path: '/library',
          name: 'library',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LibraryPage(),
          ),
        ),
        GoRoute(
          path: '/graph',
          name: 'graph',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GraphPage(),
          ),
        ),
        GoRoute(
          path: '/reader/:id',
          name: 'reader',
          pageBuilder: (context, state) => FadeTransitionPage(
            child: ReaderPage(
              documentId: state.pathParameters['id']!,
            ),
          ),
        ),
        GoRoute(
          path: '/editor/:id',
          name: 'editor',
          pageBuilder: (context, state) => FadeTransitionPage(
            child: EditorPage(
              documentId: state.pathParameters['id']!,
            ),
          ),
        ),
        GoRoute(
          path: '/editor/path',
          name: 'editor-path',
          pageBuilder: (context, state) => FadeTransitionPage(
            child: EditorPage(
              documentId: '',
              filePath: state.uri.queryParameters['path'],
            ),
          ),
        ),
        // AI features (Phase 4 - preserved but deferred)
        GoRoute(
          path: '/ai',
          name: 'ai',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AiPage(),
          ),
        ),
        GoRoute(
          path: '/wiki',
          name: 'wiki',
          pageBuilder: (context, state) => FadeTransitionPage(
            child: const WikiPage(),
          ),
        ),
        GoRoute(
          path: '/qa',
          name: 'qa',
          pageBuilder: (context, state) => FadeTransitionPage(
            child: const QaPage(),
          ),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SearchPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsPage(),
          ),
        ),
      ],
    ),
  ],
);
