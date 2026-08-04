import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvision_client/desktop/widgets/markdown_syntax_highlighter.dart';

/// Diagnoses the "gray blank" regression: ensures the syntax highlighter
/// (and its global `_highlight` init) never throws on realistic inputs.
void main() {
  TextSpan fmt(String src, {bool dark = false}) {
    return MarkdownSyntaxHighlighter(isDark: dark).format(src);
  }

  test('highlighter handles empty and trivial input', () {
    expect(() => fmt(''), returnsNormally);
    expect(() => fmt('a'), returnsNormally);
    expect(() => fmt(' '), returnsNormally);
  });

  test('highlighter handles common languages without throwing', () {
    final cases = <String>[
      "print('hello')",
      'const x = 1 + 2;',
      'function f() { return 42; }',
      'def f():\n    return 1',
      '{"a": 1, "b": [2, 3]}',
      'echo "hi"',
      '<div class="x">hi</div>',
      '.a { color: red; }',
      'SELECT * FROM t;',
      'key: value',
      '# heading\nsome text',
      '```code block```',
      '日本語のテスト',
      '中文代码注释',
    ];
    for (final c in cases) {
      expect(() => fmt(c), returnsNormally, reason: 'threw for: $c');
    }
  });

  test('highlighter handles large input without hanging or throwing', () {
    final big = List.filled(5000, 'x = 1').join('\n');
    expect(() => fmt(big), returnsNormally);
    expect(fmt(big).toPlainText(), big);
  });

  testWidgets('buildMarkdownStyleSheet does not throw (real theme)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: const SizedBox()));
    final theme = Theme.of(tester.element(find.byType(MaterialApp)));
    expect(() => buildMarkdownStyleSheet(theme, false), returnsNormally);
    expect(() => buildMarkdownStyleSheet(
        theme.copyWith(brightness: Brightness.dark), true), returnsNormally);
  });
}
