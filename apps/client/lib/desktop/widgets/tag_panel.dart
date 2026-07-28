import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// Tags panel widget - shows all tags with counts, click to filter.
class TagsPanel extends ConsumerStatefulWidget {
  const TagsPanel({super.key});

  @override
  ConsumerState<TagsPanel> createState() => _TagsPanelState();
}

class _TagsPanelState extends ConsumerState<TagsPanel> {
  int? _selectedTagId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tags = ref.watch(tagsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.tag_rounded,
                size: 16,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '标签',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_selectedTagId != null)
                InkWell(
                  onTap: () => setState(() => _selectedTagId = null),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Tags list
        if (tags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              '暂无标签',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark.withValues(alpha: 0.6)
                    : AppColors.textSecondary.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: tags.map((tag) {
                final tagId = tag['id'] as int;
                final name = tag['name'] as String;
                final count = tag['doc_count'] as int;
                final isSelected = _selectedTagId == tagId;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Material(
                    color: isSelected
                        ? (isDark
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.primaryContainer.withValues(alpha: 0.5))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTagId = isSelected ? null : tagId;
                        });
                      },
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs + 2,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '#',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isSelected
                                      ? (isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimary)
                                      : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondary),
                                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$count',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                                    : AppColors.textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        // Show documents with selected tag
        if (_selectedTagId != null) ...[
          const Divider(height: 1),
          _TagDocumentsList(tagId: _selectedTagId!),
        ],
      ],
    );
  }
}

/// List of documents that have the selected tag.
class _TagDocumentsList extends ConsumerWidget {
  const _TagDocumentsList({required this.tagId});

  final int tagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final docs = db.getDocumentsByTag(tagId, limit: 20);

    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '此标签下暂无文档',
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
      );
    }

    return Flexible(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: docs.map((doc) {
          final id = doc['id'] as String;
          final title = doc['title'] as String;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: InkWell(
                onTap: () => context.push('/reader/$id'),
                borderRadius: BorderRadius.circular(AppRadius.button),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs + 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Tag chips widget for showing tags in reader/editor header.
class TagChips extends ConsumerWidget {
  const TagChips({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final tags = db.getTagsForDocument(documentId);

    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: tags.map((tag) {
        final name = tag['name'] as String;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Text(
            '#$name',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}
