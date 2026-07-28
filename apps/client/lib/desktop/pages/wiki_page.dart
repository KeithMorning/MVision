import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';
import '../../services/ai_service.dart';
import 'ai_page.dart';

/// Wiki compilation page - select sources, compile, review patches.
class WikiPage extends ConsumerStatefulWidget {
  const WikiPage({super.key});

  @override
  ConsumerState<WikiPage> createState() => _WikiPageState();
}

class _WikiPageState extends ConsumerState<WikiPage> {
  final _topicController = TextEditingController();
  final Set<String> _selectedDocIds = {};
  
  bool _isCompiling = false;
  WikiCompilationResult? _result;
  String? _error;
  final Set<int> _appliedPatches = {};
  bool _isApplying = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _compile() async {
    if (_selectedDocIds.isEmpty) {
      setState(() => _error = '请至少选择一个源文档');
      return;
    }
    if (_topicController.text.trim().isEmpty) {
      setState(() => _error = '请输入 Wiki 主题');
      return;
    }

    setState(() {
      _isCompiling = true;
      _error = null;
      _result = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final aiService = ref.read(aiServiceProvider);

      // Read selected document contents
      final contents = <String>[];
      for (final id in _selectedDocIds) {
        final doc = db.getDocument(id);
        if (doc != null) {
          final path = doc['path'] as String;
          final sourceId = doc['source_id'] as String;
          final source = db.getSourceById(sourceId);
          if (source != null) {
            final rootPath = source['root_path'] as String;
            final file = File('$rootPath/$path');
            if (file.existsSync()) {
              contents.add(file.readAsStringSync());
            }
          }
        }
      }

      if (contents.isEmpty) {
        setState(() {
          _isCompiling = false;
          _error = '无法读取选中的文档内容';
        });
        return;
      }

      final result = await aiService.compileWiki(
        sourceContents: contents,
        existingWikiPages: [],
        topic: _topicController.text.trim(),
      );

      setState(() {
        _isCompiling = false;
        _result = result;
      });
    } catch (e) {
      setState(() {
        _isCompiling = false;
        _error = 'Wiki 编译失败: $e';
      });
    }
  }

  Future<void> _applyPatch(int index) async {
    final patch = _result!.patches[index];
    final vault = ref.read(vaultProvider);
    if (vault == null) return;

    setState(() => _isApplying = true);

    try {
      final filePath = '${vault.rootPath}/${patch.path}';
      final file = File(filePath);

      // Create parent directory if needed
      final parentDir = file.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      if (patch.action == 'update' && file.existsSync()) {
        // Append new content for updates
        final existing = file.readAsStringSync();
        file.writeAsStringSync('$existing\n\n${patch.content}');
      } else {
        // Create new file
        file.writeAsStringSync(patch.content);
      }

      setState(() {
        _appliedPatches.add(index);
        _isApplying = false;
      });

      // Refresh file tree
      ref.read(fileTreeProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已应用: ${patch.path}')),
        );
      }
    } catch (e) {
      setState(() => _isApplying = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('应用失败: $e')),
        );
      }
    }
  }

  Future<void> _applyAllPatches() async {
    for (int i = 0; i < _result!.patches.length; i++) {
      if (!_appliedPatches.contains(i)) {
        await _applyPatch(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final documents = ref.watch(documentsProvider);
    final config = ref.watch(aiConfigProvider);
    final isConfigured = config?.isConfigured ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.lg,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/ai'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.auto_stories_rounded, color: AppColors.aiIndicator),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Wiki 编译',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          if (!isConfigured)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 48,
                      color: isDark ? AppColors.textSecondaryDark.withValues(alpha: 0.3) : AppColors.textSecondary.withValues(alpha: 0.3)),
                    const SizedBox(height: AppSpacing.md),
                    Text('请先在 AI 页面配置密钥', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context.go('/ai'),
                      child: const Text('去配置'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: source selection
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: TextField(
                            controller: _topicController,
                            decoration: const InputDecoration(
                              labelText: 'Wiki 主题',
                              hintText: '例如：深度学习笔记',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Text(
                            '选择源文档 (${_selectedDocIds.length})',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            itemCount: documents.length,
                            itemBuilder: (context, index) {
                              final doc = documents[index];
                              final isSelected = _selectedDocIds.contains(doc.id);
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedDocIds.add(doc.id);
                                    } else {
                                      _selectedDocIds.remove(doc.id);
                                    }
                                  });
                                },
                                title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isCompiling ? null : _compile,
                              icon: _isCompiling
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.play_arrow_rounded, size: 18),
                              label: Text(_isCompiling ? '编译中...' : '开始编译'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1,
                    color: isDark ? AppColors.borderDark : AppColors.border),
                  // Right: results
                  Expanded(
                    child: _buildResults(theme, isDark),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme, bool isDark) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_isCompiling) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text('AI 正在分析和编译 Wiki...'),
          ],
        ),
      );
    }

    if (_result == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded, size: 64,
              color: isDark ? AppColors.textSecondaryDark.withValues(alpha: 0.3) : AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.md),
            Text('选择文档并点击"开始编译"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
          ],
        ),
      );
    }

    // Show compilation results
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('编译摘要', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Text(_result!.summary, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Patches
        if (_result!.patches.isNotEmpty) ...[
          Text('生成的 Wiki 页面 (${_result!.patches.length})',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          ..._result!.patches.asMap().entries.map((entry) => _PatchCard(
            patch: entry.value,
            isDark: isDark,
            isApplied: _appliedPatches.contains(entry.key),
            isApplying: _isApplying,
            onApply: () => _applyPatch(entry.key),
          )),
          // Apply all button
          if (_result!.patches.length > 1 && _appliedPatches.length < _result!.patches.length)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: FilledButton.icon(
                onPressed: _isApplying ? null : _applyAllPatches,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('全部应用到知识库'),
              ),
            ),
        ],
        // Links
        if (_result!.links.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('发现的关联', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          ..._result!.links.map((link) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 16, color: AppColors.aiIndicator),
                const SizedBox(width: AppSpacing.xs),
                Text(link.join(' ↔ '), style: theme.textTheme.bodySmall),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

class _PatchCard extends StatelessWidget {
  const _PatchCard({
    required this.patch,
    required this.isDark,
    required this.isApplied,
    required this.isApplying,
    required this.onApply,
  });

  final WikiPatchItem patch;
  final bool isDark;
  final bool isApplied;
  final bool isApplying;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: patch.action == 'create'
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    patch.action == 'create' ? '新建' : '更新',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: patch.action == 'create' ? AppColors.success : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(patch.path, style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  )),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Preview content
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: MarkdownBody(
                data: patch.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme),
              ),
            ),
            // References
            if (patch.references.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: patch.references.map((ref) => Chip(
                  label: Text(ref, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            // Apply button
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isApplied)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                      const SizedBox(width: AppSpacing.xs),
                      Text('已应用', style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.success, fontWeight: FontWeight.w600)),
                    ],
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: isApplying ? null : onApply,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('应用'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
