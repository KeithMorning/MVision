import 'package:flutter/material.dart';

/// A TextEditingController that provides Markdown syntax highlighting.
class MarkdownHighlightController extends TextEditingController {
  final bool isDark;

  MarkdownHighlightController({this.isDark = false, super.text});

  // Colors for syntax highlighting
  Color get _headingColor => isDark ? const Color(0xFF7EB6FF) : const Color(0xFF0550AE);
  Color get _boldColor => isDark ? const Color(0xFFFFA657) : const Color(0xFF953800);
  Color get _italicColor => isDark ? const Color(0xFFD2A8FF) : const Color(0xFF8250DF);
  Color get _codeColor => isDark ? const Color(0xFF7EE787) : const Color(0xFF116329);
  Color get _linkColor => isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA);
  Color get _quoteColor => isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7781);
  Color get _listColor => isDark ? const Color(0xFFFF7B72) : const Color(0xFFCF222E);
  Color get _hrColor => isDark ? const Color(0xFF6E7681) : const Color(0xFF8C959F);
  Color get _wikiLinkColor => isDark ? const Color(0xFF56D4DD) : const Color(0xFF0891B2);
  Color get _tagColor => isDark ? const Color(0xFFFFA198) : const Color(0xFFE16F24);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    // For very large documents, skip per-line parsing: buildTextSpan runs on
    // every keystroke, and parsing tens of thousands of lines each keypress
    // freezes the caret (the editor feels like it ignores input).
    if (text.length > 40000) {
      return TextSpan(text: text, style: style);
    }

    final spans = <TextSpan>[];
    final lines = text.split('\n');
    bool inCodeBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Track code blocks
      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        spans.add(TextSpan(
          text: line,
          style: style?.copyWith(color: _codeColor, fontFamily: 'monospace'),
        ));
        if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      if (inCodeBlock) {
        spans.add(TextSpan(
          text: line,
          style: style?.copyWith(color: _codeColor, fontFamily: 'monospace'),
        ));
        if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
        continue;
      }

      // Parse line for syntax
      spans.add(_parseLine(line, style));
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }

    return TextSpan(children: spans, style: style);
  }

  TextSpan _parseLine(String line, TextStyle? baseStyle) {
    // Empty line
    if (line.isEmpty) {
      return TextSpan(text: line, style: baseStyle);
    }

    // Headings (# to ######).
    // Keep the base font size: enlarging the heading font inside a wrapping
    // EditableText (maxLines: null) breaks caret offset mapping, so typing at
    // the end of a heading line freezes the caret / inserts the char invisibly.
    // Obsidian's source mode likewise keeps headings at body size and only
    // colors them; the rendered (larger) size comes from the preview pane.
    final headingMatch = RegExp(r'^(#{1,6})\s').firstMatch(line);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      return TextSpan(
        text: line,
        style: baseStyle?.copyWith(
          color: _headingColor,
          fontWeight: level <= 2 ? FontWeight.bold : FontWeight.w600,
        ),
      );
    }

    // Horizontal rule
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(line.trim())) {
      return TextSpan(
        text: line,
        style: baseStyle?.copyWith(color: _hrColor),
      );
    }

    // Blockquote
    if (line.trimLeft().startsWith('>')) {
      return TextSpan(
        text: line,
        style: baseStyle?.copyWith(color: _quoteColor, fontStyle: FontStyle.italic),
      );
    }

    // List items
    final listMatch = RegExp(r'^(\s*)([-*+]|\d+\.)\s').firstMatch(line);
    if (listMatch != null) {
      final indent = listMatch.group(1)!;
      final marker = listMatch.group(2)!;
      final rest = line.substring(listMatch.end);
      
      // Check for task list
      final taskMatch = RegExp(r'^\[([ xX])\]\s').firstMatch(rest);
      if (taskMatch != null) {
        final checked = taskMatch.group(1) != ' ';
        final taskRest = rest.substring(taskMatch.end);
        return TextSpan(
          children: [
            TextSpan(text: indent, style: baseStyle),
            TextSpan(text: marker, style: baseStyle?.copyWith(color: _listColor)),
            TextSpan(text: ' ', style: baseStyle),
            TextSpan(
              text: taskMatch.group(0),
              style: baseStyle?.copyWith(color: checked ? _codeColor : _listColor),
            ),
            _parseInline(taskRest, baseStyle, checked),
          ],
        );
      }
      
      return TextSpan(
        children: [
          TextSpan(text: indent, style: baseStyle),
          TextSpan(text: marker, style: baseStyle?.copyWith(color: _listColor)),
          TextSpan(text: ' ', style: baseStyle),
          _parseInline(rest, baseStyle, false),
        ],
      );
    }

    // Regular line with inline formatting
    return _parseInline(line, baseStyle, false);
  }

  TextSpan _parseInline(String text, TextStyle? baseStyle, bool strikethrough) {
    if (text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int pos = 0;

    // Patterns to match (order matters)
    final patterns = [
      // Code span
      (RegExp(r'`[^`]+`'), _codeColor, 'monospace'),
      // Bold
      (RegExp(r'\*\*[^*]+\*\*'), _boldColor, null),
      (RegExp(r'__[^_]+__'), _boldColor, null),
      // Italic
      (RegExp(r'\*[^*]+\*'), _italicColor, null),
      (RegExp(r'_[^_]+_'), _italicColor, null),
      // Strikethrough
      (RegExp(r'~~[^~]+~~'), _hrColor, null),
      // Wiki links [[target]] or [[target|display]]
      (RegExp(r'\[\[[^\]]+\]\]'), _wikiLinkColor, null),
      // Markdown links [text](url)
      (RegExp(r'\[[^\]]+\]\([^)]+\)'), _linkColor, null),
      // Tags #tag
      (RegExp(r'#[a-zA-Z\u4e00-\u9fa5][a-zA-Z0-9\u4e00-\u9fa5_/-]*'), _tagColor, null),
    ];

    while (pos < text.length) {
      int earliestStart = text.length;
      Match? earliestMatch;
      Color? earliestColor;
      String? earliestFont;

      for (final (pattern, color, font) in patterns) {
        final match = pattern.matchAsPrefix(text, pos) ?? 
                      _findNext(pattern, text, pos);
        if (match != null && match.start < earliestStart) {
          earliestStart = match.start;
          earliestMatch = match;
          earliestColor = color;
          earliestFont = font;
        }
      }

      if (earliestMatch == null) {
        // No more matches, add rest of text
        spans.add(TextSpan(
          text: text.substring(pos),
          style: baseStyle?.copyWith(
            decoration: strikethrough ? TextDecoration.lineThrough : null,
          ),
        ));
        break;
      }

      // Add text before match
      if (earliestStart > pos) {
        spans.add(TextSpan(
          text: text.substring(pos, earliestStart),
          style: baseStyle?.copyWith(
            decoration: strikethrough ? TextDecoration.lineThrough : null,
          ),
        ));
      }

      // Add matched text with highlighting
      final baseFontFamily = baseStyle?.fontFamily;
      spans.add(TextSpan(
        text: earliestMatch.group(0),
        style: baseStyle?.copyWith(
          color: earliestColor,
          fontFamily: earliestFont ?? baseFontFamily,
          fontWeight: earliestColor == _boldColor ? FontWeight.bold : null,
          fontStyle: earliestColor == _italicColor ? FontStyle.italic : null,
          decoration: strikethrough || earliestColor == _hrColor 
              ? TextDecoration.lineThrough 
              : null,
        ),
      ));

      pos = earliestMatch.end;
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  Match? _findNext(Pattern pattern, String text, int start) {
    if (pattern is RegExp) {
      return pattern.matchAsPrefix(text, start) ?? 
             pattern.allMatches(text, start).firstOrNull;
    }
    return null;
  }
}
