import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';

import '../app/providers.dart';
import '../shared/platform_keys.dart';

/// Desktop shell with sidebar navigation and content area.
///
/// Layout follows the requirement:
/// Navigation | Content | (optional inspector)
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  bool _showSidebar = true;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/library')) return 1;
    if (location.startsWith('/ai')) return 2;
    if (location.startsWith('/search')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0; // home
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/library');
      case 2:
        context.go('/ai');
      case 3:
        context.go('/search');
      case 4:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sources = ref.watch(sourcesProvider);

    return CallbackShortcuts(
      bindings: {
        // Cmd/Ctrl+\: Toggle sidebar
        PlatformKeys.activate(LogicalKeyboardKey.backslash): () {
          setState(() => _showSidebar = !_showSidebar);
        },
        // Cmd/Ctrl+,: Settings
        PlatformKeys.activate(LogicalKeyboardKey.comma): () {
          context.go('/settings');
        },
        // Cmd/Ctrl+Shift+F: Global search
        PlatformKeys.activate(LogicalKeyboardKey.keyF, shift: true): () {
          context.go('/search');
        },
        // Cmd/Ctrl+1-4: Navigate to sections
        PlatformKeys.activate(LogicalKeyboardKey.digit1): () {
          context.go('/home');
        },
        PlatformKeys.activate(LogicalKeyboardKey.digit2): () {
          context.go('/library');
        },
        PlatformKeys.activate(LogicalKeyboardKey.digit3): () {
          context.go('/ai');
        },
        PlatformKeys.activate(LogicalKeyboardKey.digit4): () {
          context.go('/search');
        },
      },
      child: Scaffold(
        body: Row(
          children: [
            // Sidebar navigation (collapsible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _showSidebar ? AppContentWidth.sidebar : 0,
              child: _showSidebar
                  ? _Sidebar(
                      selectedIndex: _selectedIndex(context),
                      onDestinationSelected: (i) => _onDestinationSelected(context, i),
                      isDark: isDark,
                      sources: sources,
                    )
                  : null,
            ),
            // Divider
            if (_showSidebar)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
            // Content area
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isDark,
    required this.sources,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isDark;
  final List<KnowledgeSource> sources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: AppContentWidth.sidebar,
      color: isDark ? AppColors.surfaceDark : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App title
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'MVision',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: '首页',
                  shortcut: PlatformKeys.label('1'),
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                _NavItem(
                  icon: Icons.library_books_rounded,
                  label: '知识库',
                  shortcut: PlatformKeys.label('2'),
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI',
                  shortcut: PlatformKeys.label('3'),
                  isSelected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  label: '搜索',
                  shortcut: PlatformKeys.label('4'),
                  isSelected: selectedIndex == 3,
                  onTap: () => onDestinationSelected(3),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Section divider
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    '管理',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: '设置',
                  shortcut: PlatformKeys.label(','),
                  isSelected: selectedIndex == 4,
                  onTap: () => onDestinationSelected(4),
                ),
              ],
            ),
          ),
          // Bottom status
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  Icon(
                    sources.isNotEmpty
                        ? Icons.check_circle_rounded
                        : Icons.folder_rounded,
                    size: 18,
                    color: sources.isNotEmpty
                        ? AppColors.success
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      sources.isNotEmpty
                          ? '${sources.length} 个知识源已连接'
                          : '未连接知识源',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.shortcut,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primaryContainer)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary)
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (shortcut != null)
                  Text(
                    shortcut!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark.withValues(alpha: 0.6)
                          : AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
