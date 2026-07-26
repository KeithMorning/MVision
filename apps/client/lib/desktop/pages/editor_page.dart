import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';

/// Markdown editor page with edit/preview toggle and autosave.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _isPreview = false;
  bool _isDirty = false;
  bool _isSaving = false;
  String _filePath = '';
  String _title = '';
  Timer? _autosaveTimer;

  // Undo/redo stacks
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  static const _maxUndoSteps = 50;

  @override
  void initState() {
    super.initState();
    _loadDocument();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadDocument() {
    final db = ref.read(databaseProvider);
    final doc = db.getDocument(widget.documentId);
    if (doc == null) return;

    _title = doc['title'] as String;
    final path = doc['path'] as String;
    final sourceId = doc['source_id'] as String;

    // Get source root path
    final sources = db.getSources();
    final source = sources.where((s) => s['id'] == sourceId).firstOrNull;
    final rootPath = source?['root_path'] as String? ?? '';
    _filePath = p.join(rootPath, path);

    // Read file content
    try {
      final file = File(_filePath);
      if (file.existsSync()) {
        _controller.text = file.readAsStringSync();
      }
    } catch (e) {
      _controller.text = '';
    }
  }

  void _onTextChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
    // Schedule autosave (2 seconds after last edit)
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 2), _save);
  }

  void _pushUndo() {
    _undoStack.add(_controller.text);
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_controller.text);
    final prev = _undoStack.removeLast();
    _controller.text = prev;
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_controller.text);
    final next = _redoStack.removeLast();
    _controller.text = next;
  }

  Future<void> _save() async {
    if (!_isDirty || _filePath.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final file = File(_filePath);
      // Atomic write: temp file + rename
      final tempPath = '$_filePath.tmp';
      await File(tempPath).writeAsString(_controller.text);
      await File(tempPath).rename(_filePath);

      // Update database hash
      final db = ref.read(databaseProvider);
      final doc = db.getDocument(widget.documentId);
      if (doc != null) {
        final sourceId = doc['source_id'] as String;
        final path = doc['path'] as String;
        // Re-index will happen on next scan
      }

      setState(() {
        _isDirty = false;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  void _insertText(String before, String after, String placeholder) {
    _pushUndo();
    final selection = _controller.selection;
    final text = _controller.text;

    if (selection.isCollapsed) {
      final newText = text.substring(0, selection.start) +
          before + placeholder + after +
          text.substring(selection.end);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: selection.start + before.length + placeholder.length,
      );
    } else {
      final selected = text.substring(selection.start, selection.end);
      final newText = text.substring(0, selection.start) +
          before + selected + after +
          text.substring(selection.end);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: selection.end + before.length + after.length,
      );
    }
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                _title,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isDirty)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  _isSaving ? Icons.sync_rounded : Icons.circle_rounded,
                  size: 10,
                  color: _isSaving ? AppColors.warning : AppColors.primary,
                ),
              ),
          ],
        ),
        actions: [
          // Undo/Redo
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            onPressed: _undoStack.isNotEmpty ? _undo : null,
            tooltip: '撤销',
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            onPressed: _redoStack.isNotEmpty ? _redo : null,
            tooltip: '重做',
          ),
          const SizedBox(width: AppSpacing.sm),
          // Edit/Preview toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.edit_rounded, size: 18)),
              ButtonSegment(value: true, icon: Icon(Icons.visibility_rounded, size: 18)),
            ],
            selected: {_isPreview},
            onSelectionChanged: (v) => setState(() => _isPreview = v.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Save button
          FilledButton.icon(
            onPressed: _isDirty ? _save : null,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('保存'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          // Toolbar (edit mode only)
          if (!_isPreview) _buildToolbar(isDark),
          // Content
          Expanded(
            child: _isPreview ? _buildPreview(theme, isDark) : _buildEditor(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          _ToolbarButton(icon: Icons.format_bold_rounded, tooltip: '粗体', onPressed: () => _insertText('**', '**', '粗体')),
          _ToolbarButton(icon: Icons.format_italic_rounded, tooltip: '斜体', onPressed: () => _insertText('*', '*', '斜体')),
          _ToolbarButton(icon: Icons.strikethrough_s_rounded, tooltip: '删除线', onPressed: () => _insertText('~~', '~~', '删除线')),
          const SizedBox(width: AppSpacing.sm),
          _ToolbarButton(icon: Icons.title_rounded, tooltip: '标题', onPressed: () => _insertText('## ', '', '标题')),
          _ToolbarButton(icon: Icons.format_quote_rounded, tooltip: '引用', onPressed: () => _insertText('> ', '', '引用')),
          _ToolbarButton(icon: Icons.code_rounded, tooltip: '代码', onPressed: () => _insertText('`', '`', '代码')),
          _ToolbarButton(icon: Icons.data_object_rounded, tooltip: '代码块', onPressed: () => _insertText('\n```\n', '\n```\n', '代码')),
          const SizedBox(width: AppSpacing.sm),
          _ToolbarButton(icon: Icons.format_list_bulleted_rounded, tooltip: '列表', onPressed: () => _insertText('- ', '', '列表项')),
          _ToolbarButton(icon: Icons.check_box_rounded, tooltip: '任务', onPressed: () => _insertText('- [ ] ', '', '任务')),
          _ToolbarButton(icon: Icons.link_rounded, tooltip: '链接', onPressed: () => _insertText('[', '](url)', '链接文字')),
          _ToolbarButton(icon: Icons.image_rounded, tooltip: '图片', onPressed: () => _insertText('![', '](url)', '描述')),
        ],
      ),
    );
  }

  Widget _buildEditor(ThemeData theme, bool isDark) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _scrollController,
        maxLines: null,
        expands: true,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontFamily: 'monospace',
          height: 1.7,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppSpacing.xxl),
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppContentWidth.reading),
        child: Markdown(
          data: _controller.text,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
            h1: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            code: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
