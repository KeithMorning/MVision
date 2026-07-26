import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// Settings page - data sources, AI config, appearance, sync.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sources = ref.watch(sourcesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          Text(
            '设置',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Data sources section
          _SectionHeader(title: '数据源'),
          const SizedBox(height: AppSpacing.md),
          // Add source button
          FilledButton.icon(
            onPressed: () => _addLocalSource(context, ref),
            icon: const Icon(Icons.create_new_folder_rounded, size: 18),
            label: const Text('添加本地目录'),
          ),
          const SizedBox(height: AppSpacing.md),
          // Connected sources
          if (sources.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '尚未连接任何知识源',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            )
          else
            ...sources.map((source) => Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(source.name),
                    subtitle: Text(
                      source.rootPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          tooltip: '扫描',
                          onPressed: () => scanSource(
                            ref,
                            sourceId: source.id,
                            rootPath: source.rootPath,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          tooltip: '移除',
                          onPressed: () {
                            ref.read(sourcesProvider.notifier).removeSource(source.id);
                            ref.read(documentsProvider.notifier).refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: AppSpacing.xxl),
          // AI section
          _SectionHeader(title: 'AI'),
          const SizedBox(height: AppSpacing.md),
          _SettingTile(
            icon: Icons.key_rounded,
            title: '模型配置',
            subtitle: 'BYOK - 自带密钥',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Appearance section
          _SectionHeader(title: '外观'),
          const SizedBox(height: AppSpacing.md),
          _SettingTile(
            icon: Icons.dark_mode_rounded,
            title: '主题模式',
            subtitle: '跟随系统',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.xxl),
          // About
          _SectionHeader(title: '关于'),
          const SizedBox(height: AppSpacing.md),
          _SettingTile(
            icon: Icons.info_outline_rounded,
            title: 'MVision',
            subtitle: 'v0.0.1 - Phase 1',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Future<void> _addLocalSource(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择知识库目录',
    );
    if (result != null) {
      await ref.read(sourcesProvider.notifier).addLocalSource(result);
      // Auto-scan after adding
      final sources = ref.read(sourcesProvider);
      final source = sources.firstWhere((s) => s.rootPath == result);
      if (context.mounted) {
        scanSource(ref, sourceId: source.id, rootPath: result);
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondary,
        ),
        title: Text(title, style: theme.textTheme.bodyLarge),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
