import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvision_client/desktop/widgets/markdown_highlight_controller.dart';

/// Measures buildTextSpan cost vs. document size. buildTextSpan runs on every
/// keystroke (EditableText re-renders the span each edit), so if it is slow on
/// large docs the caret appears frozen while typing (#6).
void main() {
  final baseStyle = const TextStyle(fontFamily: 'monospace', height: 1.7, fontSize: 16);

  String makeDoc(int lines) {
    final buf = StringBuffer();
    for (int i = 0; i < lines; i++) {
      switch (i % 5) {
        case 0:
          buf.writeln('# 标题 $i 一些中文内容 for testing');
          break;
        case 1:
          buf.writeln('- 列表项 $i with `inline code` and **bold** text');
          break;
        case 2:
          buf.writeln('普通段落 $i，contains a [[wiki-link]] and #tag here');
          break;
        case 3:
          buf.writeln('> 引用 $i quote line with some text');
          break;
        case 4:
          buf.writeln('```\ncode block line $i\nvar x = function() { return 1; }\n```');
          break;
      }
    }
    return buf.toString();
  }

  testWidgets('buildTextSpan latency vs document size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    final context = tester.element(find.byType(Scaffold));

    for (final lines in [100, 500, 2000, 5000]) {
      final doc = makeDoc(lines);
      final controller = MarkdownHighlightController(text: doc);
      // Warm up.
      controller.buildTextSpan(context: context, style: baseStyle, withComposing: false);

      final sw = Stopwatch()..start();
      controller.buildTextSpan(context: context, style: baseStyle, withComposing: false);
      sw.stop();
      // ignore: avoid_print
      print('buildTextSpan: $lines lines -> ${sw.elapsedMilliseconds} ms');
    }
  });
}
