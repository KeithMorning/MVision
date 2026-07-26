import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';

/// Markdown reader page.
class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);

    final doc = db.getDocument(documentId);
    if (doc == null) {
      return Scaffold(
        body: Center(child: Text('Document not found')),
      );
    }

    final title = doc['title'] as String;
    final path = doc['path'] as String;
    final sourceId = doc['source_id'] as String;

    // Get source root path
    final sources = db.getSources();
    final source = sources.where((s) => s['id'] == sourceId).firstOrNull;
    final rootPath = source?['root_path'] as String? ?? '';
    final fullPath = p.join(rootPath, path);

    // Read file content
    String content = '';
    try {
      final file = File(fullPath);
      if (file.existsSync()) {
        content = file.readAsStringSync();
      } else {
        content = '*File not found: $fullPath*';
      }
    } catch (e) {
      content = '*Error reading file: $e*';
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Reveal in Finder',
            onPressed: () {
              // Could use url_launcher or Process.run to reveal
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppContentWidth.reading,
              ),
              child: Markdown(
                data: content,
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
              ),
            ),
          );
        },
      ),
    );
  }
}
