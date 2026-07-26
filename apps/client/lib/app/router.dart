import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../desktop/pages/home_page.dart';
import '../desktop/pages/library_page.dart';
import '../desktop/pages/ai_page.dart';
import '../desktop/pages/search_page.dart';
import '../desktop/pages/settings_page.dart';
import '../desktop/pages/reader_page.dart';
import '../desktop/pages/editor_page.dart';
import '../desktop/desktop_shell.dart';

/// Application router configuration.
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => DesktopShell(child: child),
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
          path: '/reader/:id',
          name: 'reader',
          builder: (context, state) => ReaderPage(
            documentId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/editor/:id',
          name: 'editor',
          builder: (context, state) => EditorPage(
            documentId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/ai',
          name: 'ai',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AiPage(),
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
