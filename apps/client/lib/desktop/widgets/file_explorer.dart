import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:design_system/design_system.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';

/// File Explorer sidebar - shows vault folder tree (like Obsidian).
class FileExplorer extends ConsumerStatefulWidget {
  const FileExplorer({super.key});

  @override
  ConsumerState<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends ConsumerState<FileExplorer> {
  final Set<String> _expandedDirs = {};
  String? _selectedPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vault = ref.watch(vaultProvider);
    final fileTree = ref.watch(fileTreeProvider);

    if (vault == null) {
      return _NoVault(isDark: isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vault name header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  vault.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Refresh button
              InkWell(
                onTap: () => ref.read(fileTreeProvider.notifier).refresh(),
                borderRadius: BorderRadius.circular(AppRadius.button),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Starred section
        _StarredSection(isDark: isDark),
        // File tree
        Expanded(
          child: fileTree.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      '空目录',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: _buildTreeNodes(fileTree, 0, isDark),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildTreeNodes(
    List<FileTreeNode> nodes,
    int depth,
    bool isDark,
  ) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      if (node.isDirectory) {
        final isExpanded = _expandedDirs.contains(node.relativePath);
        widgets.add(
          _DirectoryTile(
            node: node,
            depth: depth,
            isExpanded: isExpanded,
            isDark: isDark,
            onToggle: () {
              setState(() {
                if (isExpanded) {
                  _expandedDirs.remove(node.relativePath);
                } else {
                  _expandedDirs.add(node.relativePath);
                }
              });
            },
            onNewNote: () => _createNoteInDir(node.relativePath),
            onNewFolder: () => _createFolder(node.relativePath),
          ),
        );
        if (isExpanded && node.children.isNotEmpty) {
          widgets.addAll(_buildTreeNodes(node.children, depth + 1, isDark));
        }
      } else {
        widgets.add(
          _FileTile(
            node: node,
            depth: depth,
            isDark: isDark,
            isSelected: _selectedPath == node.relativePath,
            onTap: () => _openFile(node),
            onRename: () => _renameFile(node),
            onDelete: () => _deleteFile(node),
          ),
        );
      }
    }
    return widgets;
  }

  void _openFile(FileTreeNode node) {
    setState(() => _selectedPath = node.relativePath);

    // Find document in DB by path
    final db = ref.read(databaseProvider);
    final vault = ref.read(vaultProvider);
    if (vault == null) return;

    // Search for document with matching relative path
    final docs = db.getAllDocumentTitles();
    final match = docs.where((d) => d['path'] == node.relativePath).firstOrNull;
    if (match != null) {
      final id = match['id'] as String;
      db.recordFileOpened(id);
      ref.read(recentFilesProvider.notifier).refresh();
      context.push('/reader/$id');
    } else {
      // File not indexed yet - open in editor directly via path
      context.push('/editor/path?path=${Uri.encodeComponent(node.relativePath)}');
    }
  }

  Future<void> _createNoteInDir(String dirPath) async {
    final vault = ref.read(vaultProvider);
    if (vault == null) return;

    final controller = TextEditingController(text: 'Untitled');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建笔记'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '文件名',
            suffixText: '.md',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final fileName = name.endsWith('.md') ? name : '$name.md';
      final fullPath = p.join(vault.rootPath, dirPath, fileName);
      final file = File(fullPath);
      await file.create(recursive: true);
      await file.writeAsString('# ${name.replaceAll('.md', '')}\n\n');

      // Refresh tree and re-scan
      ref.read(fileTreeProvider.notifier).refresh();
      await scanVault(ref);

      // Open the new file
      final db = ref.read(databaseProvider);
      final relPath = dirPath.isEmpty ? fileName : '$dirPath/$fileName';
      final docs = db.getAllDocumentTitles();
      final match = docs.where((d) => d['path'] == relPath).firstOrNull;
      if (match != null && mounted) {
        context.push('/editor/${match['id']}');
      }
    }
  }

  Future<void> _createFolder(String parentPath) async {
    final vault = ref.read(vaultProvider);
    if (vault == null) return;

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '文件夹名'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final fullPath = p.join(vault.rootPath, parentPath, name);
      await Directory(fullPath).create(recursive: true);
      ref.read(fileTreeProvider.notifier).refresh();
    }
  }

  Future<void> _renameFile(FileTreeNode node) async {
    final vault = ref.read(vaultProvider);
    if (vault == null) return;

    final controller = TextEditingController(
      text: p.basenameWithoutExtension(node.name),
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '新名称',
            suffixText: p.extension(node.name),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('重命名'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final ext = p.extension(node.name);
      final newFileName = newName.endsWith(ext) ? newName : '$newName$ext';
      final dir = p.dirname(node.relativePath);
      final newRelPath = dir == '.' ? newFileName : '$dir/$newFileName';
      final oldFull = p.join(vault.rootPath, node.relativePath);
      final newFull = p.join(vault.rootPath, newRelPath);

      // Check if file exists
      if (File(newFull).existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('目标文件已存在')),
          );
        }
        return;
      }

      try {
        final db = ref.read(databaseProvider);
        final oldTitle = p.basenameWithoutExtension(node.name);
        final newTitle = p.basenameWithoutExtension(newFileName);
        
        // Get document ID before rename
        final doc = db.getDocumentByPath(node.relativePath);
        
        // Rename the file
        await File(oldFull).rename(newFull);
        
        // Update database record
        if (doc != null) {
          final docId = doc['id'] as String;
          db.updateDocumentPath(docId, newRelPath, newTitle);
          
          // Update links in other files that reference this file
          if (ext == '.md') {
            await _updateLinksInOtherFiles(db, vault, oldTitle, newTitle);
          }
        }
        
        ref.read(fileTreeProvider.notifier).refresh();
        await scanVault(ref);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已重命名为 "$newFileName"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('重命名失败: $e')),
          );
        }
      }
    }
  }

  /// Update [[wiki links]] in other files that reference the renamed file.
  Future<void> _updateLinksInOtherFiles(
    dynamic db,
    dynamic vault,
    String oldTitle,
    String newTitle,
  ) async {
    // Find all documents that might link to this file
    final allDocs = db.getAllDocumentTitles();
    
    for (final doc in allDocs) {
      final path = doc['path'] as String;
      final fullPath = p.join(vault.rootPath, path);
      final file = File(fullPath);
      
      if (!file.existsSync()) continue;
      
      try {
        var content = await file.readAsString();
        
        // Check if content contains links to old title
        // Match [[oldTitle]] or [[oldTitle|display]]
        final wikiLinkPattern = RegExp('\\[\\[$oldTitle(\\|[^\\]]+)?\\]\\]');
        
        if (wikiLinkPattern.hasMatch(content)) {
          // Replace [[oldTitle]] with [[newTitle]]
          // Replace [[oldTitle|display]] with [[newTitle|display]]
          content = content.replaceAllMapped(
            wikiLinkPattern,
            (match) {
              final display = match.group(1); // |display part or null
              return '[[$newTitle${display ?? ''}]]';
            },
          );
          
          await file.writeAsString(content);
        }
      } catch (e) {
        // Skip files that can't be read/written
        continue;
      }
    }
  }

  Future<void> _deleteFile(FileTreeNode node) async {
    final vault = ref.read(vaultProvider);
    if (vault == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定要删除 "${node.name}" 吗？\n文件将移至回收站。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final fullPath = p.join(vault.rootPath, node.relativePath);
      try {
        // Move to .mvision/trash/ instead of permanent delete
        final trashDir = Directory(p.join(vault.rootPath, '.mvision', 'trash'));
        if (!trashDir.existsSync()) trashDir.createSync(recursive: true);
        final trashPath = p.join(
          trashDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_${node.name}',
        );
        await File(fullPath).rename(trashPath);
        ref.read(fileTreeProvider.notifier).refresh();
        await scanVault(ref);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }
}

class _DirectoryTile extends StatelessWidget {
  const _DirectoryTile({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.isDark,
    required this.onToggle,
    required this.onNewNote,
    required this.onNewFolder,
  });

  final FileTreeNode node;
  final int depth;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onNewNote;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onToggle,
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Padding(
        padding: EdgeInsets.only(
          left: depth * 16.0 + 8,
          top: 3,
          bottom: 3,
          right: 8,
        ),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_right_rounded,
              size: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 2),
            Icon(
              isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
              size: 16,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: [
        const PopupMenuItem(value: 'new_note', child: Text('新建笔记')),
        const PopupMenuItem(value: 'new_folder', child: Text('新建文件夹')),
      ],
    ).then((value) {
      if (value == 'new_note') onNewNote();
      if (value == 'new_folder') onNewFolder();
    });
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.node,
    required this.depth,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final FileTreeNode node;
  final int depth;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  IconData _iconForFile(String name) {
    final ext = p.extension(name).toLowerCase();
    return switch (ext) {
      '.md' || '.markdown' => Icons.description_rounded,
      '.png' || '.jpg' || '.jpeg' || '.gif' || '.svg' => Icons.image_rounded,
      '.pdf' => Icons.picture_as_pdf_rounded,
      '.txt' => Icons.text_snippet_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        padding: EdgeInsets.only(
          left: depth * 16.0 + 24,
          top: 3,
          bottom: 3,
          right: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          children: [
            Icon(
              _iconForFile(node.name),
              size: 15,
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p.basenameWithoutExtension(node.name),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? AppColors.primary
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('重命名')),
        const PopupMenuItem(value: 'delete', child: Text('删除')),
        const PopupMenuItem(value: 'reveal', child: Text('在 Finder 中显示')),
      ],
    ).then((value) {
      if (value == 'rename') onRename();
      if (value == 'delete') onDelete();
      if (value == 'reveal') {
        // Reveal in Finder handled by parent
      }
    });
  }
}

class _NoVault extends StatelessWidget {
  const _NoVault({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 40,
              color: isDark
                  ? AppColors.textSecondaryDark.withValues(alpha: 0.4)
                  : AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '未打开知识库',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '在设置中打开一个目录作为 Vault',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                    : AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Starred documents section in sidebar.
class _StarredSection extends ConsumerStatefulWidget {
  const _StarredSection({required this.isDark});
  final bool isDark;

  @override
  ConsumerState<_StarredSection> createState() => _StarredSectionState();
}

class _StarredSectionState extends ConsumerState<_StarredSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final starred = db.getStarredDocuments();

    if (starred.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 16,
                  color: widget.isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  '收藏',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${starred.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.isDark
                        ? AppColors.textSecondaryDark.withValues(alpha: 0.6)
                        : AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Starred items
        if (_isExpanded)
          ...starred.take(10).map((doc) => _StarredTile(
                doc: doc,
                isDark: widget.isDark,
              )),
        const SizedBox(height: AppSpacing.sm),
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Divider(
            height: 1,
            color: widget.isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _StarredTile extends StatelessWidget {
  const _StarredTile({required this.doc, required this.isDark});

  final Map<String, dynamic> doc;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = doc['title'] as String;
    final id = doc['id'] as String;

    return InkWell(
      onTap: () => context.push('/reader/$id'),
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Padding(
        padding: const EdgeInsets.only(
          left: 36,
          top: 3,
          bottom: 3,
          right: 8,
        ),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
