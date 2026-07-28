import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:design_system/design_system.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../app/providers.dart';
import '../../shared/platform_keys.dart';
import '../widgets/markdown_highlight_controller.dart';

/// View mode for the editor.
enum EditorViewMode { edit, preview, split }

/// Markdown editor page with edit/preview toggle and autosave.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.documentId, this.filePath});

  final String documentId;
  final String? filePath;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  late MarkdownHighlightController _controller;
  final _scrollController = ScrollController();
  final _previewScrollController = ScrollController();
  final _focusNode = FocusNode();

  EditorViewMode _viewMode = EditorViewMode.edit;
  bool _isDirty = false;
  bool _isSaving = false;
  String _filePath = '';
  String _title = '';
  Timer? _autosaveTimer;
  String? _recoveryPath;
  bool _showRecoveryBanner = false;
  String? _appSupportPath;

  // Word count
  int _wordCount = 0;

  // Wiki link autocomplete
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _autocompleteOverlay;
  List<String> _autocompleteSuggestions = [];
  int _autocompleteIndex = 0;
  bool _showAutocomplete = false;

  // Undo/redo stacks
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  static const _maxUndoSteps = 50;

  @override
  void initState() {
    super.initState();
    // Initialize controller FIRST before loading document
    _controller = MarkdownHighlightController(
      isDark: WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
    );
    _controller.addListener(_onTextChanged);
    _initAppSupport();
    _loadDocument();
    _updateWordCount();
  }

  Future<void> _initAppSupport() async {
    final dir = await getApplicationSupportDirectory();
    _appSupportPath = dir.path;
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _autocompleteOverlay?.remove();
    _controller.dispose();
    _scrollController.dispose();
    _previewScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final text = _controller.text;
    setState(() {
      // Count words (split by whitespace, filter empty)
      _wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    });
  }

  String get _readingTime {
    // Average reading speed: 200 words per minute
    final minutes = (_wordCount / 200).ceil();
    if (minutes < 1) return '< 1 分钟';
    return '$minutes 分钟';
  }

  void _loadDocument() {
    // If opened by direct file path (from file explorer)
    if (widget.filePath != null && widget.filePath!.isNotEmpty) {
      final vault = ref.read(vaultProvider);
      if (vault == null) return;
      _filePath = p.join(vault.rootPath, widget.filePath!);
      _title = p.basenameWithoutExtension(widget.filePath!);
      try {
        final file = File(_filePath);
        if (file.existsSync()) {
          _controller.text = file.readAsStringSync();
        }
      } catch (e) {
        _controller.text = '';
      }
      return;
    }

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

    // Check for crash recovery file
    _checkRecovery();

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

  /// Check if a recovery file exists from a previous crash.
  void _checkRecovery() {
    try {
      if (_appSupportPath == null) return;
      final recoveryDir = Directory(p.join(_appSupportPath!, 'recovery'));
      if (!recoveryDir.existsSync()) return;

      final hash = sha256.convert(utf8.encode(_filePath)).toString().substring(0, 16);
      final recoveryFile = File(p.join(recoveryDir.path, '$hash.md'));
      if (recoveryFile.existsSync()) {
        _recoveryPath = recoveryFile.path;
        _showRecoveryBanner = true;
      }
    } catch (_) {}
  }

  /// Save recovery file for crash recovery.
  void _saveRecoveryFile() {
    try {
      if (_appSupportPath == null) return;
      final recoveryDir = Directory(p.join(_appSupportPath!, 'recovery'));
      if (!recoveryDir.existsSync()) recoveryDir.createSync(recursive: true);

      final hash = sha256.convert(utf8.encode(_filePath)).toString().substring(0, 16);
      File(p.join(recoveryDir.path, '$hash.md')).writeAsStringSync(_controller.text);
    } catch (_) {}
  }

  /// Remove recovery file after successful save.
  void _clearRecoveryFile() {
    try {
      if (_recoveryPath != null) {
        final f = File(_recoveryPath!);
        if (f.existsSync()) f.deleteSync();
        _recoveryPath = null;
      }
    } catch (_) {}
  }

  /// Recover from crash file.
  void _recover() {
    try {
      if (_recoveryPath != null) {
        final content = File(_recoveryPath!).readAsStringSync();
        _controller.text = content;
        setState(() {
          _isDirty = true;
          _showRecoveryBanner = false;
        });
      }
    } catch (_) {}
  }

  /// Dismiss recovery banner.
  void _dismissRecovery() {
    _clearRecoveryFile();
    setState(() => _showRecoveryBanner = false);
  }

  void _onTextChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
    // Save recovery file immediately for crash safety
    _saveRecoveryFile();
    // Update word count
    _updateWordCount();
    // Check for wiki link autocomplete
    _checkWikiLinkAutocomplete();
    // Schedule autosave (2 seconds after last edit)
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 2), _save);
  }

  void _checkWikiLinkAutocomplete() {
    final selection = _controller.selection;
    if (!selection.isCollapsed) {
      _hideAutocomplete();
      return;
    }

    final text = _controller.text;
    final cursorPos = selection.baseOffset;
    
    // Find [[ before cursor
    final textBefore = text.substring(0, cursorPos);
    final wikiMatch = RegExp(r'\[\[([^\]]*)$').firstMatch(textBefore);
    
    if (wikiMatch != null) {
      final query = wikiMatch.group(1) ?? '';
      _showAutocompleteSuggestions(query);
    } else {
      _hideAutocomplete();
    }
  }

  void _showAutocompleteSuggestions(String query) {
    final db = ref.read(databaseProvider);
    final docs = db.getAllDocumentTitles();
    
    // Filter and sort by relevance
    _autocompleteSuggestions = docs
        .map((d) => d['title'] as String)
        .where((title) => 
            query.isEmpty || title.toLowerCase().contains(query.toLowerCase()))
        .take(8)
        .toList();

    if (_autocompleteSuggestions.isEmpty) {
      _hideAutocomplete();
      return;
    }

    _autocompleteIndex = 0;
    _showAutocomplete = true;
    _updateAutocompleteOverlay();
  }

  void _updateAutocompleteOverlay() {
    _autocompleteOverlay?.remove();
    
    if (!_showAutocomplete || _autocompleteSuggestions.isEmpty) return;

    _autocompleteOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 24),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AppSpacing.xs),
                itemCount: _autocompleteSuggestions.length,
                itemBuilder: (context, index) {
                  final title = _autocompleteSuggestions[index];
                  final isSelected = index == _autocompleteIndex;
                  return InkWell(
                    onTap: () => _insertWikiLink(title),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      color: isSelected 
                          ? AppColors.primary.withValues(alpha: 0.1) 
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? AppColors.primary : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_autocompleteOverlay!);
  }

  void _hideAutocomplete() {
    _showAutocomplete = false;
    _autocompleteOverlay?.remove();
    _autocompleteOverlay = null;
  }

  void _insertWikiLink(String title) {
    final selection = _controller.selection;
    final text = _controller.text;
    final cursorPos = selection.baseOffset;
    
    // Find [[ before cursor and replace
    final textBefore = text.substring(0, cursorPos);
    final wikiMatch = RegExp(r'\[\[([^\]]*)$').firstMatch(textBefore);
    
    if (wikiMatch != null) {
      final start = wikiMatch.start;
      final newText = '${text.substring(0, start)}[[$title]]${text.substring(cursorPos)}';
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: start + title.length + 4, // [[title]]
      );
    }
    
    _hideAutocomplete();
    _focusNode.requestFocus();
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
      // Ensure parent directory exists (for new notes)
      final parentDir = file.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }
      // Atomic write: temp file + rename
      final tempPath = '$_filePath.tmp';
      await File(tempPath).writeAsString(_controller.text);
      await File(tempPath).rename(_filePath);

      // Re-index will happen on next scan

      setState(() {
        _isDirty = false;
        _isSaving = false;
      });
      // Clear recovery file after successful save
      _clearRecoveryFile();
      // Refresh file tree to show new note
      ref.read(fileTreeProvider.notifier).refresh();
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
          // Edit/Preview/Split toggle
          SegmentedButton<EditorViewMode>(
            segments: const [
              ButtonSegment(value: EditorViewMode.edit, icon: Icon(Icons.edit_rounded, size: 18)),
              ButtonSegment(value: EditorViewMode.split, icon: Icon(Icons.view_column_rounded, size: 18)),
              ButtonSegment(value: EditorViewMode.preview, icon: Icon(Icons.visibility_rounded, size: 18)),
            ],
            selected: {_viewMode},
            onSelectionChanged: (v) => setState(() => _viewMode = v.first),
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
          // Recovery banner
          if (_showRecoveryBanner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              color: AppColors.warning.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(child: Text('检测到上次未保存的编辑内容', style: TextStyle(fontSize: 13))),
                  TextButton(onPressed: _recover, child: const Text('恢复')),
                  TextButton(onPressed: _dismissRecovery, child: const Text('忽略')),
                ],
              ),
            ),
          // Toolbar (edit mode only)
          if (_viewMode != EditorViewMode.preview) _buildToolbar(isDark),
          // Content
          Expanded(
            child: _buildContent(theme, isDark),
          ),
          // Status bar
          _buildStatusBar(isDark),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    switch (_viewMode) {
      case EditorViewMode.edit:
        return _buildEditor(theme, isDark);
      case EditorViewMode.preview:
        return _buildPreview(theme, isDark);
      case EditorViewMode.split:
        return Row(
          children: [
            Expanded(child: _buildEditor(theme, isDark)),
            Container(
              width: 1,
              color: isDark ? AppColors.borderDark : AppColors.border,
            ),
            Expanded(child: _buildPreview(theme, isDark)),
          ],
        );
    }
  }

  Widget _buildStatusBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.text_fields_rounded, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$_wordCount 字',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '阅读 $_readingTime',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          if (_isDirty)
            Row(
              children: [
                Icon(Icons.circle_rounded, size: 8, color: AppColors.warning),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '未保存',
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '已保存',
                  style: TextStyle(fontSize: 12, color: AppColors.success),
                ),
              ],
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: CallbackShortcuts(
        bindings: {
          PlatformKeys.activate(LogicalKeyboardKey.keyZ): _undo,
          PlatformKeys.activate(LogicalKeyboardKey.keyZ, shift: true): _redo,
          PlatformKeys.activate(LogicalKeyboardKey.keyS): _save,
        },
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: _handleKeyEvent,
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
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!_showAutocomplete) return;
    
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _autocompleteIndex = (_autocompleteIndex + 1) % _autocompleteSuggestions.length;
        });
        _updateAutocompleteOverlay();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _autocompleteIndex = (_autocompleteIndex - 1 + _autocompleteSuggestions.length) % _autocompleteSuggestions.length;
        });
        _updateAutocompleteOverlay();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_autocompleteSuggestions.isNotEmpty) {
          _insertWikiLink(_autocompleteSuggestions[_autocompleteIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideAutocomplete();
      }
    }
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
