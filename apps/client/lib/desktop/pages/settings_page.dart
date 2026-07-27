import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
          // Baidu Netdisk section
          _SectionHeader(title: '百度网盘'),
          const SizedBox(height: AppSpacing.md),
          _BaiduSection(isDark: isDark),
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

/// Baidu Netdisk connection section.
class _BaiduSection extends StatefulWidget {
  const _BaiduSection({required this.isDark});
  final bool isDark;

  @override
  State<_BaiduSection> createState() => _BaiduSectionState();
}

class _BaiduSectionState extends State<_BaiduSection> {
  final _codeController = TextEditingController();
  bool _showCodeInput = false;
  String? _status;
  bool _isSuccess = false;

  // TODO: Move to secure config. For now, user must register at
  // https://pan.baidu.com/union/doc/pksg0s9ns
  static const _clientId = 'YOUR_BAIDU_APP_KEY';
  static const _clientSecret = 'YOUR_BAIDU_SECRET_KEY';
  static const _redirectUri = 'http://localhost:8080/callback';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openAuthPage() async {
    final authUrl = 'https://openapi.baidu.com/oauth/2.0/authorize'
        '?response_type=code'
        '&client_id=$_clientId'
        '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
        '&scope=basic,netdisk'
        '&display=popup';

    final uri = Uri.parse(authUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() => _showCodeInput = true);
    } else {
      setState(() {
        _status = '无法打开浏览器';
        _isSuccess = false;
      });
    }
  }

  void _onConnect() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _status = '请输入授权码';
        _isSuccess = false;
      });
      return;
    }

    // TODO: Exchange code for token via BaiduOAuth service
    setState(() {
      _status = '授权码已收到，百度网盘连接器将在后续版本中完整集成';
      _isSuccess = true;
      _showCodeInput = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '百度网盘同步',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '连接百度网盘后，可以同步远端 Markdown 文件到本地阅读。\n'
              '需要先在百度开放平台注册应用获取 AppKey。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_status != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Text(_status!, style: theme.textTheme.bodySmall),
              ),
            if (_showCodeInput) ...[
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '授权码',
                  hintText: '从浏览器回调 URL 中复制 code 参数',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _openAuthPage,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('打开授权页面'),
                ),
                if (_showCodeInput) ...[
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: _onConnect,
                    child: const Text('连接'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
