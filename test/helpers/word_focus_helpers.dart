import 'package:dyslexia_app/widgets/ui/word_focus_controls.dart';
import 'package:dyslexia_app/widgets/ui/word_focus_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Finder wordFocusParagraphs() => find.descendant(
  of: find.byType(WordFocusText),
  matching: find.byType(RichText),
);

/// The sharp (semantic) layer is always painted last.
RenderParagraph sharpParagraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(wordFocusParagraphs().last);

Finder wordFocusSwitch() => find.descendant(
  of: find.byType(WordFocusSwitchRow),
  matching: find.byType(Switch),
);

Offset centerOfRange(WidgetTester tester, int start, int end) {
  final paragraph = sharpParagraph(tester);
  final box = paragraph
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))
      .first
      .toRect();
  return paragraph.localToGlobal(box.center);
}

/// Taps the [occurrence]-th (0-based) occurrence of [word] in [text].
Future<void> tapWordOccurrence(
  WidgetTester tester,
  String text,
  String word, {
  int occurrence = 0,
}) async {
  var start = -1;
  for (var i = 0; i <= occurrence; i++) {
    start = text.indexOf(word, start + 1);
  }
  await tester.tapAt(centerOfRange(tester, start, start + word.length));
  await tester.pump();
}
