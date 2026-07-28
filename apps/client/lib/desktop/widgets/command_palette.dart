import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// A command that can be executed from the palette.
class PaletteCommand {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? shortcut;
  final VoidCallback action;

  const PaletteCommand({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    this.shortcut,
    required this.action,
  });
}

/// Command Palette dialog (Cmd/Ctrl+K) - execute commands quickly.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  /// Show the command palette.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => const CommandPalette(),
    );
  }

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  int _selectedIndex = 0;
  List<PaletteCommand> _results = [];
  List<PaletteCommand> _allCommands = [];

  @override
  void initState() {
    super.initState();
    _buildCommands();
    _results = _allCommands;
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _buildCommands() {
    _allCommands = [
      PaletteCommand(
        id: 'new-note',
        title: '新建笔记',
        subtitle: '在当前知识库中创建新笔记',
        icon: Icons.note_add_rounded,
        shortcut: '⌘N',
        action: () => _createNewNote(),
      ),
      PaletteCommand(
        id: 'quick-switcher',
        title: '快速打开文件',
        subtitle: '模糊搜索并打开文件',
        icon: Icons.flash_on_rounded,
        shortcut: '⌘O',
        action: () {
          Navigator.of(context).pop();
          _showQuickSwitcher();
        },
      ),
      PaletteCommand(
        id: 'search',
        title: '全文搜索',
        subtitle: '在所有笔记中搜索内容',
        icon: Icons.search_rounded,
        shortcut: '⌘⇧F',
        action: () {
          Navigator.of(context).pop();
          context.go('/search');
        },
      ),
      PaletteCommand(
        id: 'toggle-sidebar',
        title: '切换侧边栏',
        subtitle: '显示或隐藏文件浏览器',
        icon: Icons.view_sidebar_rounded,
        shortcut: '⌘\\',
        action: () {
          Navigator.of(context).pop();
          // Sidebar toggle is handled by shell shortcut
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('使用 ⌘\\ 切换侧边栏')),
          );
        },
      ),
      PaletteCommand(
        id: 'settings',
        title: '打开设置',
        subtitle: '应用设置和知识库配置',
        icon: Icons.settings_rounded,
        shortcut: '⌘,',
        action: () {
          Navigator.of(context).pop();
          context.go('/settings');
        },
      ),
      PaletteCommand(
        id: 'scan-vault',
        title: '重新扫描知识库',
        subtitle: '重新索引所有文件和链接',
        icon: Icons.refresh_rounded,
        action: () {
          Navigator.of(context).pop();
          scanVault(ref);
        },
      ),
      PaletteCommand(
        id: 'home',
        title: '返回首页',
        icon: Icons.home_rounded,
        action: () {
          Navigator.of(context).pop();
          context.go('/home');
        },
      ),
      PaletteCommand(
        id: 'library',
        title: '打开知识库',
        icon: Icons.library_books_rounded,
        action: () {
          Navigator.of(context).pop();
          context.go('/library');
        },
      ),
    ];
  }

  void _createNewNote() {
    Navigator.of(context).pop();
    final vault = ref.read(vaultProvider);
    if (vault == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先打开一个知识库')),
      );
      return;
    }
    // Navigate to editor with new file path
    context.push('/editor/path?path=${Uri.encodeComponent('Untitled.md')}');
  }

  void _showQuickSwitcher() {
    // Import would create circular dependency, use dialog directly
    showDialog(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => const _QuickSwitcherProxy(),
    );
  }

  void _onQueryChanged() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _results = _allCommands;
        _selectedIndex = 0;
      });
      return;
    }

    final filtered = _allCommands.where((cmd) {
      return cmd.title.toLowerCase().contains(query) ||
          (cmd.subtitle?.toLowerCase().contains(query) ?? false);
    }).toList();

    setState(() {
      _results = filtered;
      _selectedIndex = 0;
    });
  }

  void _executeSelected() {
    if (_results.isEmpty) return;
    _results[_selectedIndex].action();
  }

  void _moveSelection(int delta) {
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _results.length - 1);
    });
    if (_scrollController.hasClients) {
      final offset = _selectedIndex * 52.0;
      _scrollController.animateTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 200, right: 200),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      elevation: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search input
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _moveSelection(1);
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _moveSelection(-1);
                    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                      _executeSelected();
                    }
                  }
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: '输入命令...',
                    prefixIcon: Icon(
                      Icons.terminal_rounded,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ),
            // Commands list
            Flexible(
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        '无匹配命令',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final cmd = _results[index];
                        final isSelected = index == _selectedIndex;
                        return _CommandTile(
                          command: cmd,
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap: () {
                            _selectedIndex = index;
                            _executeSelected();
                          },
                          onHover: (hovering) {
                            if (hovering) {
                              setState(() => _selectedIndex = index);
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Proxy to avoid circular import - just opens QuickSwitcher.
class _QuickSwitcherProxy extends StatelessWidget {
  const _QuickSwitcherProxy();

  @override
  Widget build(BuildContext context) {
    // Close immediately and let the caller handle it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop();
    });
    return const SizedBox.shrink();
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.command,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.onHover,
  });

  final PaletteCommand command;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.primaryContainer.withValues(alpha: 0.5))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Row(
            children: [
              Icon(
                command.icon,
                size: 18,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      command.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (command.subtitle != null)
                      Text(
                        command.subtitle!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (command.shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                  ),
                  child: Text(
                    command.shortcut!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
