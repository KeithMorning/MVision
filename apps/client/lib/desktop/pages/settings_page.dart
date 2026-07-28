import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';

/// Settings page - vault config, appearance, sync.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vault = ref.watch(vaultProvider);

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
          // Vault section
          _SectionHeader(title: '知识库'),
          const SizedBox(height: AppSpacing.md),
          // Open vault button
          FilledButton.icon(
            onPressed: () => _openVault(context, ref),
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Text(vault != null ? '切换知识库' : '打开知识库'),
          ),
          const SizedBox(height: AppSpacing.md),
          // Current vault info
          if (vault != null)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: const Icon(Icons.auto_stories_rounded),
                title: Text(vault.name),
                subtitle: Text(
                  vault.rootPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: '扫描',
                      onPressed: () => scanVault(ref),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '尚未打开知识库',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
          // Baidu Netdisk section
          _SectionHeader(title: '百度网盘'),
          const SizedBox(height: AppSpacing.md),
          _BaiduSection(isDark: isDark),
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

  Future<void> _openVault(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择知识库目录',
    );
    if (result != null) {
      ref.read(vaultProvider.notifier).openVault(result);
      // Auto-scan after opening
      if (context.mounted) {
        scanVault(ref);
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

/// Baidu Netdisk connection section (OAuth + BDUSS support).
class _BaiduSection extends StatefulWidget {
  const _BaiduSection({required this.isDark});
  final bool isDark;

  @override
  State<_BaiduSection> createState() => _BaiduSectionState();
}

class _BaiduSectionState extends State<_BaiduSection> {
  final _appKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _bdussController = TextEditingController();
  String? _status;
  bool _isSuccess = false;
  bool _useOAuth = true;

  @override
  void dispose() {
    _appKeyController.dispose();
    _secretKeyController.dispose();
    _bdussController.dispose();
    super.dispose();
  }

  void _onConnect() {
    if (_useOAuth) {
      _connectOAuth();
    } else {
      _connectBduss();
    }
  }

  void _connectOAuth() {
    final appKey = _appKeyController.text.trim();
    final secretKey = _secretKeyController.text.trim();
    
    if (appKey.isEmpty || secretKey.isEmpty) {
      setState(() {
        _status = '请输入 AppKey 和 SecretKey';
        _isSuccess = false;
      });
      return;
    }

    // TODO: Implement OAuth flow
    // 1. Open browser for authorization
    // 2. Capture redirect with auth code
    // 3. Exchange code for access token
    setState(() {
      _status = 'OAuth 配置已保存。完整同步功能开发中...';
      _isSuccess = true;
    });
  }

  void _connectBduss() {
    final bduss = _bdussController.text.trim();
    if (bduss.isEmpty) {
      setState(() {
        _status = '请输入 BDUSS';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _status = 'BDUSS 已保存。完整同步功能开发中...';
      _isSuccess = true;
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
            const SizedBox(height: AppSpacing.md),
            // Auth method toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('OAuth'), icon: Icon(Icons.key_rounded, size: 16)),
                ButtonSegment(value: false, label: Text('BDUSS'), icon: Icon(Icons.cookie_rounded, size: 16)),
              ],
              selected: {_useOAuth},
              onSelectionChanged: (v) => setState(() => _useOAuth = v.first),
              showSelectedIcon: false,
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
            if (_useOAuth) ...[
              Text(
                '使用百度开放平台 OAuth 授权。\n'
                '前往 openapi.baidu.com 创建应用获取凭证。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: widget.isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _appKeyController,
                decoration: const InputDecoration(
                  labelText: 'AppKey (Client ID)',
                  hintText: '百度开放平台 AppKey',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _secretKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'SecretKey',
                  hintText: '百度开放平台 SecretKey',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ] else ...[
              Text(
                '使用 BDUSS Cookie 认证（类似 BaiduPCS-Go）。\n'
                '登录 pan.baidu.com → F12 → Application → Cookies → 复制 BDUSS',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: widget.isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _bdussController,
                decoration: const InputDecoration(
                  labelText: 'BDUSS',
                  hintText: '从浏览器 Cookies 中复制 BDUSS 值',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _onConnect,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }
}
