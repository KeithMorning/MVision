import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../widgets/backlinks_panel.dart';
import '../widgets/tag_panel.dart';

/// Markdown reader page with TOC and Wiki Link support.
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final _scrollController = ScrollController();
  final _markdownKey = GlobalKey();
  
  Map<String, dynamic>? _doc;
  String _content = '';
  String _fullPath = '';
  List<_TocItem> _toc = [];
  bool _showToc = true;
  bool _showBacklinks = false;
  bool _isStarred = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadDocument() {
    final db = ref.read(databaseProvider);
    final doc = db.getDocument(widget.documentId);
    if (doc == null) return;

    setState(() {
      _doc = doc;
      _isStarred = db.isStarred(widget.documentId);
    });

    final path = doc['path'] as String;
    final sourceId = doc['source_id'] as String;

    // Get source root path
    final sources = db.getSources();
    final source = sources.where((s) => s['id'] == sourceId).firstOrNull;
    final rootPath = source?['root_path'] as String? ?? '';
    _fullPath = p.join(rootPath, path);

    // Read file content
    try {
      final file = File(_fullPath);
      if (file.existsSync()) {
        _content = file.readAsStringSync();
        _extractToc();
      } else {
        _content = '*File not found: $_fullPath*';
      }
    } catch (e) {
      _content = '*Error reading file: $e*';
    }
  }

  void _extractToc() {
    final lines = _content.split('\n');
    final items = <_TocItem>[];
    bool inCodeBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Track code blocks
      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }
      if (inCodeBlock) continue;

      // Match headings
      final match = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (match != null) {
        final level = match.group(1)!.length;
        final text = match.group(2)!.trim();
        items.add(_TocItem(level: level, text: text, lineIndex: i));
      }
    }

    setState(() => _toc = items);
  }

  void _scrollToHeading(int lineIndex) {
    // Approximate scroll position based on line index
    final totalLines = _content.split('\n').length;
    if (totalLines > 0 && _scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetScroll = (lineIndex / totalLines) * maxScroll;
      _scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleStar() {
    final db = ref.read(databaseProvider);
    db.toggleStar(widget.documentId);
    setState(() => _isStarred = !_isStarred);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_doc == null) {
      return Scaffold(
        body: Center(child: Text('Document not found')),
      );
    }

    final title = _doc!['title'] as String;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Star button
          IconButton(
            icon: Icon(
              _isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isStarred ? AppColors.warning : null,
            ),
            tooltip: _isStarred ? '取消收藏' : '收藏',
            onPressed: _toggleStar,
          ),
          // Backlinks toggle
          IconButton(
            icon: Icon(
              _showBacklinks ? Icons.link_rounded : Icons.link_outlined,
              color: _showBacklinks ? AppColors.primary : null,
            ),
            tooltip: '反向链接',
            onPressed: () => setState(() => _showBacklinks = !_showBacklinks),
          ),
          // TOC toggle
          if (_toc.isNotEmpty)
            IconButton(
              icon: Icon(
                _showToc ? Icons.toc_rounded : Icons.toc_outlined,
                color: _showToc ? AppColors.primary : null,
              ),
              tooltip: '目录',
              onPressed: () => setState(() => _showToc = !_showToc),
            ),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: '编辑',
            onPressed: () => context.push('/editor/${widget.documentId}'),
          ),
          // Split view button
          IconButton(
            icon: const Icon(Icons.vertical_split_rounded),
            tooltip: '分屏打开',
            onPressed: () {
              ref.read(splitViewProvider.notifier).openInSplit(widget.documentId);
            },
          ),
          // Reveal in Finder
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: '在 Finder 中显示',
            onPressed: () {
              Process.run('open', ['-R', _fullPath]);
            },
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Row(
        children: [
          // TOC sidebar
          if (_showToc && _toc.isNotEmpty)
            SizedBox(
              width: 220,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(
                      '目录',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ..._toc.map((item) => _TocTile(
                          item: item,
                          isDark: isDark,
                          onTap: () => _scrollToHeading(item.lineIndex),
                        )),
                  ],
                ),
              ),
            ),
          // Content
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppContentWidth.reading,
                ),
                child: Column(
                  children: [
                    // Tag chips header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0,
                      ),
                      child: TagChips(documentId: widget.documentId),
                    ),
                    // Markdown content
                    Expanded(
                      child: Markdown(
                        key: _markdownKey,
                        controller: _scrollController,
                        data: _processWikiLinks(_content),
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                          p: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
                          h1: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          h2: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          h3: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          code: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            backgroundColor: isDark
                                ? AppColors.surfaceVariantDark
                                : AppColors.surfaceVariant,
                          ),
                        ),
                        onTapLink: (text, href, title) {
                          // Handle Wiki Links
                          if (href != null && href.startsWith('wiki://')) {
                            final linkTarget = href.replaceFirst('wiki://', '');
                            _navigateToWikiLink(linkTarget);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Backlinks panel (right side)
          if (_showBacklinks)
            BacklinksPanel(documentId: widget.documentId),
        ],
      ),
    );
  }

  /// Process [[Wiki Link]] syntax into Markdown links.
  String _processWikiLinks(String content) {
    // First process embeds ![[note]]
    var processed = _processEmbeds(content);
    
    // Then process regular wiki links [[target]] or [[target|display]]
    return processed.replaceAllMapped(
      RegExp(r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'),
      (match) {
        final target = match.group(1)!.trim();
        final display = match.group(2)?.trim() ?? target;
        return '[$display](wiki://${Uri.encodeComponent(target)})';
      },
    );
  }

  /// Process ![[embed]] syntax to inline note content.
  String _processEmbeds(String content) {
    final db = ref.read(databaseProvider);
    final vault = ref.read(vaultProvider);
    if (vault == null) return content;

    return content.replaceAllMapped(
      RegExp(r'!\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'),
      (match) {
        final target = match.group(1)!.trim();
        
        // Search for the document
        final results = db.search(target, limit: 1);
        if (results.isEmpty) {
          return '*未找到嵌入内容: $target*';
        }

        final doc = results.first;
        final path = doc['path'] as String;
        final fullPath = p.join(vault.rootPath, path);

        try {
          final file = File(fullPath);
          if (file.existsSync()) {
            var embedContent = file.readAsStringSync();
            
            // Remove YAML frontmatter if present
            if (embedContent.startsWith('---')) {
              final endIndex = embedContent.indexOf('---', 3);
              if (endIndex != -1) {
                embedContent = embedContent.substring(endIndex + 3).trim();
              }
            }
            
            // Add a subtle border/quote style by prefixing with >
            final lines = embedContent.split('\n');
            final quotedLines = lines.map((line) => '> $line').join('\n');
            return '\n$quotedLines\n';
          }
        } catch (e) {
          return '*嵌入错误: $e*';
        }
        
        return '*未找到嵌入内容: $target*';
      },
    );
  }

  void _navigateToWikiLink(String target) {
    // Search for document with matching title
    final db = ref.read(databaseProvider);
    final results = db.search(target, limit: 1);
    if (results.isNotEmpty) {
      final id = results.first['id'] as String;
      context.push('/reader/$id');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未找到链接目标: $target')),
      );
    }
  }
}

class _TocItem {
  final int level;
  final String text;
  final int lineIndex;

  const _TocItem({
    required this.level,
    required this.text,
    required this.lineIndex,
  });
}

class _TocTile extends StatelessWidget {
  const _TocTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  final _TocItem item;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Padding(
        padding: EdgeInsets.only(
          left: (item.level - 1) * 12.0,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
          right: AppSpacing.xs,
        ),
        child: Text(
          item.text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: item.level <= 2
                ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
            fontWeight: item.level <= 2 ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
