import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';

import '../app/providers.dart';
import '../shared/platform_keys.dart';
import 'widgets/file_explorer.dart';
import 'widgets/quick_switcher.dart';
import 'widgets/command_palette.dart';

/// Desktop shell with Obsidian-like layout:
/// File Explorer (left) | Content (center) | Inspector (right, optional)
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  bool _showSidebar = true;

  void _createNewNote() {
    final vault = ref.read(vaultProvider);
    if (vault == null) return;
    context.push('/editor/path?path=${Uri.encodeComponent('Untitled.md')}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vault = ref.watch(vaultProvider);

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
        // Cmd/Ctrl+O: Quick Switcher
        PlatformKeys.activate(LogicalKeyboardKey.keyO): () {
          QuickSwitcher.show(context);
        },
        // Cmd/Ctrl+K: Command Palette
        PlatformKeys.activate(LogicalKeyboardKey.keyK): () {
          CommandPalette.show(context);
        },
        // Cmd/Ctrl+N: New Note
        PlatformKeys.activate(LogicalKeyboardKey.keyN): () {
          _createNewNote();
        },
      },
      child: Scaffold(
        body: Row(
          children: [
            // Left sidebar: File Explorer
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _showSidebar ? AppContentWidth.sidebar : 0,
              child: _showSidebar
                  ? Container(
                      width: AppContentWidth.sidebar,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surface,
                        border: Border(
                          right: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.border,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // App title bar
                          _TitleBar(isDark: isDark, hasVault: vault != null),
                          // File explorer
                          const Expanded(child: FileExplorer()),
                          // Bottom status bar
                          _StatusBar(isDark: isDark),
                        ],
                      ),
                    )
                  : null,
            ),
            // Content area
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

/// App title bar at top of sidebar.
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.isDark, required this.hasVault});

  final bool isDark;
  final bool hasVault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: 24,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'MVision',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Graph view button
          _SidebarIconButton(
            icon: Icons.hub_rounded,
            tooltip: '关系图谱',
            isDark: isDark,
            onTap: () => context.go('/graph'),
          ),
          const SizedBox(width: 4),
          // Search button
          _SidebarIconButton(
            icon: Icons.search_rounded,
            tooltip: '搜索',
            isDark: isDark,
            onTap: () => context.go('/search'),
          ),
          const SizedBox(width: 4),
          // Settings button
          _SidebarIconButton(
            icon: Icons.settings_rounded,
            tooltip: '设置',
            isDark: isDark,
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

/// Bottom status bar showing sync/vault status.
class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vault = ref.watch(vaultProvider);
    final documents = ref.watch(documentsProvider);
    final scanState = ref.watch(scanStateProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Icon(
              scanState.isScanning
                  ? Icons.sync_rounded
                  : (vault != null
                      ? Icons.check_circle_rounded
                      : Icons.folder_rounded),
              size: 14,
              color: scanState.isScanning
                  ? AppColors.warning
                  : (vault != null
                      ? AppColors.success
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                scanState.isScanning
                    ? (scanState.message ?? '扫描中...')
                    : (vault != null
                        ? '${documents.length} 个笔记'
                        : '未打开知识库'),
                style: theme.textTheme.labelSmall?.copyWith(
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
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
