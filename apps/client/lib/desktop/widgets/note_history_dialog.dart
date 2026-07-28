import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// Dialog showing note edit history with restore capability.
class NoteHistoryDialog extends ConsumerStatefulWidget {
  const NoteHistoryDialog({super.key, required this.documentId});

  final String documentId;

  /// Show the history dialog.
  static Future<String?> show(BuildContext context, String documentId) {
    return showDialog<String>(
      context: context,
      builder: (_) => NoteHistoryDialog(documentId: documentId),
    );
  }

  @override
  ConsumerState<NoteHistoryDialog> createState() => _NoteHistoryDialogState();
}

class _NoteHistoryDialogState extends ConsumerState<NoteHistoryDialog> {
  List<Map<String, dynamic>> _snapshots = [];
  int? _selectedId;
  String _previewContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final db = ref.read(databaseProvider);
    final snapshots = db.getHistorySnapshots(widget.documentId, limit: 30);
    setState(() {
      _snapshots = snapshots;
      _isLoading = false;
    });
  }

  void _selectSnapshot(Map<String, dynamic> snapshot) {
    setState(() {
      _selectedId = snapshot['id'] as int;
      _previewContent = snapshot['content'] as String;
    });
  }

  void _restore() {
    if (_selectedId == null) return;
    Navigator.of(context).pop(_previewContent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 700,
        height: 500,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '编辑历史',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Content
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_snapshots.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 48,
                        color: isDark
                            ? AppColors.textSecondaryDark.withValues(alpha: 0.4)
                            : AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '暂无历史记录',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '每次保存笔记时会自动记录历史版本',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                              : AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Row(
                  children: [
                    // Snapshot list
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_snapshots.length} 个版本',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _snapshots.length,
                              itemBuilder: (context, index) {
                                final snapshot = _snapshots[index];
                                final id = snapshot['id'] as int;
                                final savedAt = snapshot['saved_at'] as int;
                                final isSelected = _selectedId == id;
                                final date = DateTime.fromMillisecondsSinceEpoch(savedAt);
                                final dateStr = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                                return InkWell(
                                  onTap: () => _selectSnapshot(snapshot),
                                  borderRadius: BorderRadius.circular(AppRadius.button),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: AppSpacing.sm,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(AppRadius.button),
                                      border: isSelected
                                          ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.article_outlined,
                                          size: 16,
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors.textSecondary),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dateStr,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  fontWeight: isSelected ? FontWeight.w600 : null,
                                                  color: isSelected ? AppColors.primary : null,
                                                ),
                                              ),
                                              Text(
                                                '${(snapshot['content'] as String).length} 字符',
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: isDark
                                                      ? AppColors.textSecondaryDark
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Preview pane
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.border,
                          ),
                        ),
                        child: _selectedId == null
                            ? Center(
                                child: Text(
                                  '选择一个版本预览',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    _previewContent,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            // Footer
            if (_selectedId != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _restore,
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('恢复此版本'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
