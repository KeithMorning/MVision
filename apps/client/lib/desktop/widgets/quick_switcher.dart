import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// Quick Switcher dialog (Cmd/Ctrl+O) - fuzzy search to open files.
class QuickSwitcher extends ConsumerStatefulWidget {
  const QuickSwitcher({super.key});

  /// Show the quick switcher dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => const QuickSwitcher(),
    );
  }

  @override
  ConsumerState<QuickSwitcher> createState() => _QuickSwitcherState();
}

class _QuickSwitcherState extends ConsumerState<QuickSwitcher> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  int _selectedIndex = 0;
  List<_FileEntry> _results = [];
  List<_FileEntry> _allFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _controller.addListener(_onQueryChanged);
    // Focus the text field after build
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

  void _loadFiles() {
    final db = ref.read(databaseProvider);
    final recentFiles = db.getRecentFiles(limit: 10);
    final allDocs = db.getAllDocumentTitles();

    // Recent files first, then all others
    final recentIds = recentFiles.map((r) => r['id'] as String).toSet();
    final entries = <_FileEntry>[];

    // Add recent files section
    for (final doc in recentFiles) {
      entries.add(_FileEntry(
        id: doc['id'] as String,
        title: doc['title'] as String,
        path: doc['path'] as String,
        isRecent: true,
      ));
    }

    // Add remaining documents
    for (final doc in allDocs) {
      final id = doc['id'] as String;
      if (!recentIds.contains(id)) {
        entries.add(_FileEntry(
          id: id,
          title: doc['title'] as String,
          path: doc['path'] as String,
          isRecent: false,
        ));
      }
    }

    _allFiles = entries;
    _results = entries;
  }

  void _onQueryChanged() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _results = _allFiles;
        _selectedIndex = 0;
      });
      return;
    }

    // Fuzzy match
    final scored = <_ScoredEntry>[];
    for (final entry in _allFiles) {
      final score = _fuzzyScore(query, entry.title.toLowerCase()) +
          _fuzzyScore(query, entry.path.toLowerCase()) * 0.5;
      if (score > 0) {
        scored.add(_ScoredEntry(entry: entry, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    setState(() {
      _results = scored.map((s) => s.entry).toList();
      _selectedIndex = 0;
    });
  }

  /// Simple fuzzy scoring: consecutive character matches score higher.
  double _fuzzyScore(String query, String target) {
    if (target.contains(query)) return 100.0 + query.length;

    double score = 0;
    int targetIdx = 0;
    int consecutive = 0;

    for (int i = 0; i < query.length && targetIdx < target.length; i++) {
      final char = query[i];
      final found = target.indexOf(char, targetIdx);
      if (found == -1) return 0; // Character not found, no match

      if (found == targetIdx) {
        consecutive++;
        score += consecutive * 2; // Bonus for consecutive matches
      } else {
        consecutive = 0;
        score += 1;
      }
      targetIdx = found + 1;
    }

    // Bonus for matching at word boundaries
    if (target.startsWith(query[0])) score += 5;

    return score;
  }

  void _openSelected() {
    if (_results.isEmpty) return;
    final entry = _results[_selectedIndex];
    Navigator.of(context).pop();
    context.push('/reader/${entry.id}');
  }

  void _moveSelection(int delta) {
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _results.length - 1);
    });
    // Scroll to selected item
    if (_scrollController.hasClients) {
      final offset = _selectedIndex * 48.0;
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
                      _openSelected();
                    }
                  }
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: '搜索文件...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
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
            // Results list
            Flexible(
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        '无匹配文件',
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
                        final entry = _results[index];
                        final isSelected = index == _selectedIndex;
                        return _FileTile(
                          entry: entry,
                          isSelected: isSelected,
                          isDark: isDark,
                          onTap: () {
                            _selectedIndex = index;
                            _openSelected();
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
            // Footer hint
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _KeyHint(label: '↑↓', description: '导航', isDark: isDark),
                  const SizedBox(width: AppSpacing.lg),
                  _KeyHint(label: '↵', description: '打开', isDark: isDark),
                  const SizedBox(width: AppSpacing.lg),
                  _KeyHint(label: 'esc', description: '关闭', isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileEntry {
  final String id;
  final String title;
  final String path;
  final bool isRecent;

  const _FileEntry({
    required this.id,
    required this.title,
    required this.path,
    required this.isRecent,
  });
}

class _ScoredEntry {
  final _FileEntry entry;
  final double score;

  const _ScoredEntry({required this.entry, required this.score});
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.entry,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.onHover,
  });

  final _FileEntry entry;
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
          height: 44,
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
                entry.isRecent ? Icons.access_time_rounded : Icons.description_outlined,
                size: 16,
                color: entry.isRecent
                    ? AppColors.warning
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  entry.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                entry.path,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                      : AppColors.textSecondary.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({
    required this.label,
    required this.description,
    required this.isDark,
  });

  final String label;
  final String description;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          description,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
