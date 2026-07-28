import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// Backlinks and outgoing links panel (shown in reader/editor right side).
class BacklinksPanel extends ConsumerWidget {
  const BacklinksPanel({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);

    final backlinks = db.getBacklinks(documentId);
    final outgoing = db.getOutgoingLinks(documentId);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        border: Border(
          left: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Backlinks section
          _SectionHeader(
            icon: Icons.link_rounded,
            title: '反向链接',
            count: backlinks.length,
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (backlinks.isEmpty)
            _EmptyHint(text: '暂无反向链接', isDark: isDark)
          else
            ...backlinks.map((link) => _LinkTile(
                  title: link['source_title'] as String? ?? '未知',
                  context: link['context'] as String? ?? '',
                  linkType: link['link_type'] as String? ?? 'wiki',
                  isDark: isDark,
                  onTap: () {
                    final sourceId = link['source_doc_id'] as String;
                    context.push('/reader/$sourceId');
                  },
                )),
          const SizedBox(height: AppSpacing.xl),
          // Outgoing links section
          _SectionHeader(
            icon: Icons.open_in_new_rounded,
            title: '出站链接',
            count: outgoing.length,
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (outgoing.isEmpty)
            _EmptyHint(text: '暂无出站链接', isDark: isDark)
          else
            ...outgoing.map((link) => _LinkTile(
                  title: link['target_title'] as String? ?? '未知',
                  context: link['link_text'] as String? ?? '',
                  linkType: link['link_type'] as String? ?? 'wiki',
                  isDark: isDark,
                  onTap: () {
                    final targetId = link['target_doc_id'] as String;
                    context.push('/reader/$targetId');
                  },
                )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.title,
    required this.context,
    required this.linkType,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String context;
  final String linkType;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext buildContext) {
    final theme = Theme.of(buildContext);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      linkType == 'wiki'
                          ? Icons.double_arrow_rounded
                          : Icons.insert_link_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
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
                if (context.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: Text(
                      context,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text, required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark
              ? AppColors.textSecondaryDark.withValues(alpha: 0.6)
              : AppColors.textSecondary.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
