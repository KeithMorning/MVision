import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvision_client/desktop/widgets/markdown_highlight_controller.dart';

/// Most runtime-accurate reproduction: pumps the full editor widget structure
/// (CallbackShortcuts + ScrollConfiguration + Scrollbar + TextField) and drives
/// the text via the platform text-input channel (testTextInput) - the real path
/// a keyboard uses - then reads the caret rect from the actual RenderEditable.
void main() {
  testWidgets('full editor: space inserts and caret advances (real input path)',
      (tester) async {
    final controller = MarkdownHighlightController(text: '# xxx');
    final focusNode = FocusNode();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallbackShortcuts(
            bindings: const {},
            child: ScrollConfiguration(
              behavior:
                  const MaterialScrollBehavior().copyWith(scrollbars: false),
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  scrollController: scrollController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.7),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();

    // Real keyboard path: the platform sends a new editing value with the
    // trailing space inserted and the caret moved past it.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '# xxx ',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();

    expect(controller.text, '# xxx ');

    final editable = tester.renderObject<RenderEditable>(
      find.byElementPredicate(
        (e) => e is RenderObjectElement && e.renderObject is RenderEditable,
      ),
    );
    final r5 = editable.getLocalRectForCaret(const TextPosition(offset: 5));
    final r6 = editable.getLocalRectForCaret(const TextPosition(offset: 6));

    expect(r6.left, greaterThan(r5.left),
        reason: 'caret must advance past the trailing space');
  });
}
