import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../services/ai_service.dart';

/// AI provider.
final aiServiceProvider = Provider<AiService>((ref) => AiService());

/// AI config state.
final aiConfigProvider = StateNotifierProvider<AiConfigNotifier, AiConfig?>((ref) {
  return AiConfigNotifier(ref.watch(aiServiceProvider));
});

class AiConfigNotifier extends StateNotifier<AiConfig?> {
  final AiService _service;

  AiConfigNotifier(this._service) : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await _service.loadConfig();
  }

  Future<void> save(AiConfig config) async {
    await _service.saveConfig(config);
    state = config;
  }

  Future<void> delete() async {
    await _service.deleteConfig();
    state = null;
  }
}

/// AI page - BYOK configuration and AI features.
class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load config after first frame to ensure provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _loadConfig() {
    final config = ref.read(aiConfigProvider);
    if (config != null && !_configLoaded) {
      _baseUrlController.text = config.baseUrl;
      _apiKeyController.text = config.apiKey;
      _modelController.text = config.model;
      _configLoaded = true;
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final config = AiConfig(
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
    );

    final service = ref.read(aiServiceProvider);
    final result = await service.testConnection(config);

    setState(() {
      _isTesting = false;
      _testSuccess = result.success;
      _testResult = result.success ? '连接成功！' : result.errorMessage;
    });
  }

  Future<void> _saveConfig() async {
    final config = AiConfig(
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
    );

    await ref.read(aiConfigProvider.notifier).save(config);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 配置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = ref.watch(aiConfigProvider);
    final isConfigured = config?.isConfigured ?? false;

    // React to async config load
    if (config != null && !_configLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _baseUrlController.text = config.baseUrl;
          _apiKeyController.text = config.apiKey;
          _modelController.text = config.model;
          _configLoaded = true;
        }
      });
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 32,
                color: AppColors.aiIndicator,
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isConfigured ? '已配置 · ${config!.model}' : '未配置',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isConfigured ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          
          // Configuration section
          _SectionHeader(title: '模型配置 (BYOK)'),
          const SizedBox(height: AppSpacing.md),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Base URL
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText: 'https://api.openai.com/v1',
                      prefixIcon: Icon(Icons.link_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // API Key
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      prefixIcon: Icon(Icons.key_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Model
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      hintText: 'gpt-4, claude-3, etc.',
                      prefixIcon: Icon(Icons.smart_toy_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Test result
                  if (_testResult != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _testSuccess
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testSuccess
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            size: 18,
                            color: _testSuccess ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering_rounded, size: 18),
                        label: const Text('测试连接'),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _saveConfig,
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('保存配置'),
                      ),
                      if (isConfigured) ...[
                        const SizedBox(width: AppSpacing.md),
                        TextButton(
                          onPressed: () async {
                            await ref.read(aiConfigProvider.notifier).delete();
                            _baseUrlController.clear();
                            _apiKeyController.clear();
                            _modelController.clear();
                            setState(() {
                              _testResult = null;
                            });
                          },
                          child: const Text('清除', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          
          // AI Features section
          _SectionHeader(title: 'AI 功能'),
          const SizedBox(height: AppSpacing.md),
          
          if (!isConfigured)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 48,
                      color: isDark
                          ? AppColors.textSecondaryDark.withValues(alpha: 0.3)
                          : AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '配置 AI 密钥后解锁以下功能',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _FeatureCard(
              icon: Icons.auto_stories_rounded,
              title: 'Wiki 编译',
              subtitle: '将原始资料自动整理成结构化 Wiki',
              isDark: isDark,
              onTap: () => context.go('/wiki'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _FeatureCard(
              icon: Icons.question_answer_rounded,
              title: '知识问答',
              subtitle: '基于知识库回答问题，附带来源引用',
              isDark: isDark,
              onTap: () => context.go('/qa'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _FeatureCard(
              icon: Icons.link_rounded,
              title: '智能链接',
              subtitle: '自动发现文档间的关联',
              isDark: isDark,
              onTap: () {
                // TODO: Navigate to smart links
              },
            ),
          ],
          
          const SizedBox(height: AppSpacing.xxl),
          
          // Privacy notice
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.privacy_tip_rounded,
                  size: 18,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'API Key 存储在系统安全存储中，不会上传到任何服务器。AI 请求只发送完成任务所需的最小上下文。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.aiIndicator.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Icon(icon, size: 22, color: AppColors.aiIndicator),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
