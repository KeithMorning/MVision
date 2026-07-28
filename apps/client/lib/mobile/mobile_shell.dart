import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// Mobile shell with bottom tab navigation for iOS/Android.
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int _currentIndex = 0;

  static const _tabs = [
    '/home',
    '/library',
    '/graph',
    '/search',
    '/settings',
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_tabs[index]);
  }

  void _determineActiveTab(String location) {
    int newIndex = 0;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = newIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    _determineActiveTab(location);

    // Hide bottom nav on reader/editor pages for immersive reading
    final isImmersive = location.startsWith('/reader') ||
        location.startsWith('/editor');

    return Scaffold(
      body: widget.child,
      floatingActionButton: isImmersive
          ? null
          : FloatingActionButton(
              onPressed: () {
                final vault = ref.read(vaultProvider);
                if (vault == null) return;
                context.push('/editor/path?path=${Uri.encodeComponent('Untitled.md')}');
              },
              tooltip: '新建笔记',
              child: const Icon(Icons.edit_rounded),
            ),
      bottomNavigationBar: isImmersive
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books_rounded),
                  label: '知识库',
                ),
                NavigationDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub_rounded),
                  label: '图谱',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: '搜索',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: '设置',
                ),
              ],
            ),
    );
  }
}
