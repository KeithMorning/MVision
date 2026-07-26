import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// AI page - Wiki compilation, Q&A, and patch review.
class AiPage extends StatelessWidget {
  const AiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: isDark
                      ? AppColors.aiIndicatorDark
                      : AppColors.aiIndicator,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'AI',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Wiki 编译、知识问答与 Patch 审核',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy_rounded,
                      size: 64,
                      color: isDark
                          ? AppColors.aiIndicatorDark.withValues(alpha: 0.3)
                          : AppColors.aiIndicator.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '尚未配置 AI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '在设置中配置模型密钥以启用 AI 功能',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
