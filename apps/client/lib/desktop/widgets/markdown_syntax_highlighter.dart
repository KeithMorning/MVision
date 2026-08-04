import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:highlight/languages/all.dart' as hl_all;
import 'package:markdown/markdown.dart' as md;

/// A `highlight` instance restricted to common languages so auto-detection
/// (which tries every registered language) stays fast on every render.
final hl.Highlight _highlight = hl.Highlight()
  ..registerLanguages({
    for (final name in const [
      'dart', 'javascript', 'typescript', 'python', 'json', 'bash', 'shell',
      'xml', 'css', 'sql', 'yaml', 'markdown', 'java', 'go', 'rust', 'c', 'cpp',
      'kotlin', 'swift', 'php', 'ruby', 'plaintext',
    ])
      if (hl_all.allLanguages.containsKey(name)) name: hl_all.allLanguages[name]!,
  });

/// Syntax highlighter for fenced code blocks, used by `MarkdownWidget`.
///
/// `flutter_markdown_plus` exposes a [SyntaxHighlighter] hook that receives
/// only the raw code (no language hint), so we let the `highlight` package
/// auto-detect the language. Results are cached per source string so that
/// split-view re-renders (one per keystroke) stay cheap.
class MarkdownSyntaxHighlighter extends SyntaxHighlighter {
  MarkdownSyntaxHighlighter({
    required this.isDark,
    TextStyle? baseStyle,
  }) : _baseStyle = baseStyle ?? const TextStyle(fontFamily: 'monospace');

  final bool isDark;
  final TextStyle _baseStyle;
  final Map<String, TextSpan> _cache = {};

  /// GitHub-flavored token colors. Keys are `highlight` className values
  /// (no `hljs-` prefix). Unmapped tokens fall back to the base text color.
  static const _lightTheme = <String, Color>{
    'comment': Color(0xFF6a737d),
    'quote': Color(0xFF6a737d),
    'doctag': Color(0xFFd73a49),
    'keyword': Color(0xFFd73a49),
    'selector': Color(0xFFd73a49),
    'literal': Color(0xFF005cc5),
    'number': Color(0xFF005cc5),
    'built_in': Color(0xFF005cc5),
    'type': Color(0xFF6f42c1),
    'class': Color(0xFF6f42c1),
    'title': Color(0xFF6f42c1),
    'function': Color(0xFF6f42c1),
    'attr': Color(0xFF005cc5),
    'attribute': Color(0xFF005cc5),
    'string': Color(0xFF032f62),
    'regexp': Color(0xFF032f62),
    'meta': Color(0xFF6a737d),
    'tag': Color(0xFF22863a),
    'name': Color(0xFF22863a),
    'symbol': Color(0xFF005cc5),
    'bullet': Color(0xFF005cc5),
    'addition': Color(0xFF22863a),
    'deletion': Color(0xFFd73a49),
    'variable': Color(0xFFe36209),
    'params': Color(0xFF24292e),
    'property': Color(0xFF005cc5),
  };

  static const _darkTheme = <String, Color>{
    'comment': Color(0xFF8b949e),
    'quote': Color(0xFF8b949e),
    'doctag': Color(0xFFff7b72),
    'keyword': Color(0xFFff7b72),
    'selector': Color(0xFFff7b72),
    'literal': Color(0xFF79c0ff),
    'number': Color(0xFF79c0ff),
    'built_in': Color(0xFFffa657),
    'type': Color(0xFFffa657),
    'class': Color(0xFFd2a8ff),
    'title': Color(0xFFd2a8ff),
    'function': Color(0xFFd2a8ff),
    'attr': Color(0xFF79c0ff),
    'attribute': Color(0xFF79c0ff),
    'string': Color(0xFFa5d6ff),
    'regexp': Color(0xFFa5d6ff),
    'meta': Color(0xFF8b949e),
    'tag': Color(0xFF7ee787),
    'name': Color(0xFF7ee787),
    'symbol': Color(0xFF79c0ff),
    'bullet': Color(0xFF79c0ff),
    'addition': Color(0xFF7ee787),
    'deletion': Color(0xFFff7b72),
    'variable': Color(0xFFffa657),
    'params': Color(0xFFc9d1d9),
    'property': Color(0xFF79c0ff),
  };

  @override
  TextSpan format(String source) {
    final cached = _cache[source];
    if (cached != null) return cached;
    TextSpan span;
    try {
      // Skip highlighting for very large blocks: auto-detection parses the
      // source once per registered language, so cost is O(n * languages).
      if (source.isEmpty || source.length > 4000) {
        span = TextSpan(text: source, style: _baseStyle);
      } else {
        final result = _highlight.parse(source, autoDetection: true);
        span = _toSpan(result.nodes ?? [hl.Node(value: source)], null);
      }
    } catch (_) {
      // Never let a highlighter failure blank out the whole document.
      span = TextSpan(text: source, style: _baseStyle);
    }
    _cache[source] = span;
    return span;
  }

  TextSpan _toSpan(List<hl.Node> nodes, String? inheritedClass) {
    return TextSpan(
      style: _baseStyle,
      children: [
        for (final node in nodes) _nodeToSpan(node, inheritedClass),
      ],
    );
  }

  InlineSpan _nodeToSpan(hl.Node node, String? inheritedClass) {
    final className = node.className ?? inheritedClass;
    if (node.value != null) {
      return TextSpan(text: node.value, style: _styleFor(className));
    }
    if (node.children != null && node.children!.isNotEmpty) {
      return TextSpan(
        style: _styleFor(className),
        children: [
          for (final child in node.children!) _nodeToSpan(child, className),
        ],
      );
    }
    return const TextSpan(text: '');
  }

  TextStyle? _styleFor(String? className) {
    if (className == null) return null;
    final color = (isDark ? _darkTheme : _lightTheme)[className];
    return color == null ? null : TextStyle(color: color);
  }
}

/// Renders inline `` `code` `` as a padded, rounded chip (flutter_markdown's
/// default inline code is a tight background with no padding/rounded corners).
///
/// Registered under the `'code'` tag. Fenced code blocks (`pre`) are handled
/// separately by [MarkdownSyntaxHighlighter] - this builder only fires for
/// inline code, so there is no overlap.
class InlineCodeBuilder extends MarkdownElementBuilder {
  InlineCodeBuilder({required this.isDark, TextStyle? baseStyle})
      : _baseStyle = baseStyle ?? const TextStyle(fontFamily: 'monospace');

  final bool isDark;
  final TextStyle _baseStyle;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: _baseStyle.copyWith(
          fontSize: preferredStyle?.fontSize ?? 13,
          color: isDark ? const Color(0xFF7EE787) : const Color(0xFF116329),
        ),
      ),
    );
  }
}

/// Shared markdown style sheet for the reader and the editor preview.
///
/// Fixes the rendering issues vs. `flutter_markdown` defaults:
/// - blockquote: a left bar (Obsidian-style) instead of the light
///   `Colors.blue.shade100` background that turned near-white in dark mode
/// - code block: rounded, padded background (highlighting via
///   [MarkdownSyntaxHighlighter])
/// - inline code: styled by [InlineCodeBuilder] (padded, rounded chip)
MarkdownStyleSheet buildMarkdownStyleSheet(ThemeData theme, bool isDark) {
  final barColor = (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
      .withValues(alpha: 0.6);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
    h1: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
    ),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      fontStyle: FontStyle.italic,
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
    ),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: barColor, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 2, bottom: 2, right: 8),
    codeblockDecoration: BoxDecoration(
      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
  );
}
