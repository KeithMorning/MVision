import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvision_client/desktop/widgets/markdown_highlight_controller.dart';

/// Diagnoses the "space inserted but invisible" issue: checks whether the
/// caret actually advances past a trailing space when the controller builds
/// its highlighted TextSpan (which splits text into per-line spans joined by
/// explicit '\n' spans), and that no spaces are dropped.
void main() {
  final baseStyle = TextStyle(fontFamily: 'monospace', height: 1.7, fontSize: 16);

  Future<BuildContext> bootstrap(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    return tester.element(find.byType(Scaffold));
  }

  TextSpan buildSpan(BuildContext context, MarkdownHighlightController c) {
    return c.buildTextSpan(
      context: context,
      style: baseStyle,
      withComposing: false,
    );
  }

  double caretX(BuildContext context, String text, int offset) {
    final c = MarkdownHighlightController(text: text);
    final span = buildSpan(context, c);
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    return tp.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dx;
  }

  testWidgets('caret advances past trailing space on a heading line',
      (tester) async {
    final context = await bootstrap(tester);

    final beforeSpace = caretX(context, '# xxx', 5);
    final afterSpace = caretX(context, '# xxx ', 6);
    final atFiveWithSpace = caretX(context, '# xxx ', 5);

    expect(afterSpace, greaterThan(atFiveWithSpace),
        reason: 'caret must advance past the trailing space');
    expect(atFiveWithSpace, closeTo(beforeSpace, 0.01),
        reason: 'offset 5 should be the same with/without the trailing space');
  });

  testWidgets('caret advances past trailing space on a normal line',
      (tester) async {
    final context = await bootstrap(tester);

    final atEnd = caretX(context, 'hello world', 11);
    final afterTrailing = caretX(context, 'hello world ', 12);
    final beforeTrailing = caretX(context, 'hello world ', 11);

    expect(afterTrailing, greaterThan(beforeTrailing),
        reason: 'caret must advance past trailing space on a normal line');
    expect(beforeTrailing, closeTo(atEnd, 0.01));
  });

  testWidgets('renders composing region (IME) instead of dropping it',
      (tester) async {
    final context = await bootstrap(tester);

    final controller = MarkdownHighlightController(text: '# nihao 标题');
    controller.value = controller.value.copyWith(
      composing: const TextRange(start: 2, end: 7),
    );

    final span = controller.buildTextSpan(
      context: context,
      style: baseStyle,
      withComposing: true,
    );

    expect(span.toPlainText(), contains('nihao'));
  });

  testWidgets('buildTextSpan preserves all spaces (no drops)', (tester) async {
    final context = await bootstrap(tester);

    final cases = <String>[
      '# xxx ',
      '# xxx\n',
      '# hello world ',
      '**bold text** ',
      '`code` more ',
      '- list item ',
      '> quote ',
      'a  b   c',
      '  leading',
    ];

    for (final input in cases) {
      final c = MarkdownHighlightController(text: input);
      final span = c.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: false,
      );
      expect(span.toPlainText(), input,
          reason: 'spaces dropped for input: ${jsonEncode(input)}');
    }
  });
}
