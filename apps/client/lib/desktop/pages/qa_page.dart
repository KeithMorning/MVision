import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';

import '../../app/providers.dart';
import '../../services/ai_service.dart';
import 'ai_page.dart';

/// Knowledge Q&A page - ask questions about your knowledge base.
class QaPage extends ConsumerStatefulWidget {
  const QaPage({super.key});

  @override
  ConsumerState<QaPage> createState() => _QaPageState();
}

class _QaPageState extends ConsumerState<QaPage> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_QaMessage> _messages = [];
  bool _isThinking = false;

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isThinking) return;

    _questionController.clear();
    setState(() {
      _messages.add(_QaMessage(role: 'user', content: question));
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final db = ref.read(databaseProvider);
      final aiService = ref.read(aiServiceProvider);

      // Gather context from recent documents (up to 5)
      final docs = db.getDocuments(limit: 5);
      final contextDocs = <String>[];
      for (final doc in docs) {
        final source = db.getSourceById(doc['source_id'] as String);
        if (source != null) {
          final rootPath = source['root_path'] as String;
          final path = doc['path'] as String;
          final file = File('$rootPath/$path');
          if (file.existsSync()) {
            final content = file.readAsStringSync();
            // Limit content length per doc
            contextDocs.add(content.length > 3000
                ? content.substring(0, 3000)
                : content);
          }
        }
      }

      final result = await aiService.askQuestion(
        question: question,
        contextDocuments: contextDocs,
      );

      setState(() {
        _isThinking = false;
        _messages.add(_QaMessage(
          role: 'assistant',
          content: result.answer,
          sources: result.sources,
          confidence: result.confidence,
        ));
      });
    } catch (e) {
      setState(() {
        _isThinking = false;
        _messages.add(_QaMessage(
          role: 'assistant',
          content: '抱歉，发生了错误: $e',
          confidence: 'low',
        ));
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = ref.watch(aiConfigProvider);
    final isConfigured = config?.isConfigured ?? false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.md,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/ai'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.question_answer_rounded, color: AppColors.aiIndicator),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '知识问答',
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
          else ...[
            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(theme, isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: _messages.length + (_isThinking ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isThinking) {
                          return _ThinkingIndicator(isDark: isDark);
                        }
                        return _MessageBubble(
                          message: _messages[index],
                          isDark: isDark,
                        );
                      },
                    ),
            ),
            // Input bar
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      onSubmitted: (_) => _ask(),
                      decoration: InputDecoration(
                        hintText: '输入问题，基于知识库回答...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  IconButton.filled(
                    onPressed: _isThinking ? null : _ask,
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_rounded, size: 64,
            color: isDark ? AppColors.textSecondaryDark.withValues(alpha: 0.3) : AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.lg),
          Text('基于你的知识库提问',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Text('AI 会引用来源文档回答',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xxl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _SuggestionChip(label: '总结最近添加的文档', onTap: () {
                _questionController.text = '总结最近添加的文档';
                _ask();
              }),
              _SuggestionChip(label: '这些文档有什么共同主题？', onTap: () {
                _questionController.text = '这些文档有什么共同主题？';
                _ask();
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _QaMessage {
  final String role;
  final String content;
  final List<String> sources;
  final String confidence;

  const _QaMessage({
    required this.role,
    required this.content,
    this.sources = const [],
    this.confidence = 'medium',
  });
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isDark});

  final _QaMessage message;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.aiIndicator.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.aiIndicator),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(message.content, style: theme.textTheme.bodyLarge)
                  else
                    MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme),
                    ),
                  if (message.sources.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Text('来源引用', style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.xs),
                    ...message.sources.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.insert_drive_file_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(s, style: theme.textTheme.labelSmall),
                        ],
                      ),
                    )),
                  ],
                  if (!isUser) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '置信度: ${message.confidence == "high" ? "高" : message.confidence == "medium" ? "中" : "低"}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: message.confidence == 'high' ? AppColors.success
                            : message.confidence == 'medium' ? AppColors.warning
                            : AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.aiIndicator.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.aiIndicator),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: AppSpacing.sm),
                Text('思考中...'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
