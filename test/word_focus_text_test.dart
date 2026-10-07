import 'package:dyslexia_app/features/ocr/ocr_widgets/extracted_text_box.dart';
import 'package:dyslexia_app/features/settings/provider.dart';
import 'package:dyslexia_app/widgets/ui/word_focus_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/word_focus_helpers.dart';

const _style = TextStyle(fontSize: 20, height: 1.5, letterSpacing: 0.5);

Future<ValueNotifier<TextRange?>> _pumpWordFocus(
  WidgetTester tester,
  String text, {
  double width = 300,
}) async {
  final selection = ValueNotifier<TextRange?>(null);
  addTearDown(selection.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ValueListenableBuilder<TextRange?>(
              valueListenable: selection,
              builder: (context, value, _) => WordFocusText(
                text: text,
                style: _style,
                selection: value,
                onSelectionChanged: (range) => selection.value = range,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return selection;
}

/// OCR result card with screen-local focus state, like [OcrScreen].
class _OcrCardHarness extends StatefulWidget {
  final String text;
  final bool isEditing;

  const _OcrCardHarness({required this.text, this.isEditing = false});

  @override
  State<_OcrCardHarness> createState() => _OcrCardHarnessState();
}

class _OcrCardHarnessState extends State<_OcrCardHarness> {
  final TextEditingController _controller = TextEditingController();
  bool wordFocusOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExtractedTextBox(
      text: widget.text,
      isLoading: false,
      dyslexiaMode: false,
      isEditing: widget.isEditing,
      editController: _controller,
      wordFocusOn: wordFocusOn,
      onWordFocusChanged: (on) => setState(() => wordFocusOn = on),
    );
  }
}

Widget _ocrCard(String text, {bool isEditing = false}) {
  return ChangeNotifierProvider<SettingsProvider>(
    create: (_) => SettingsProvider(),
    child: MaterialApp(
      home: Scaffold(
        body: _OcrCardHarness(text: text, isEditing: isEditing),
      ),
    ),
  );
}

void main() {
  const text = 'мама и тато, мама и баба.';

  testWidgets('tap focuses a word, tap again clears it', (tester) async {
    final selection = await _pumpWordFocus(tester, text);
    expect(wordFocusParagraphs(), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);

    await tapWordOccurrence(tester, text, 'тато');
    expect(selection.value, const TextRange(start: 7, end: 12));
    expect(wordFocusParagraphs(), findsNWidgets(2));
    expect(find.byType(ImageFiltered), findsOneWidget);

    await tapWordOccurrence(tester, text, 'тато');
    expect(selection.value, isNull);
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('repeated words are focused by their own offsets', (
    tester,
  ) async {
    final selection = await _pumpWordFocus(tester, text);

    await tapWordOccurrence(tester, text, 'мама', occurrence: 1);
    expect(selection.value, const TextRange(start: 13, end: 17));

    await tapWordOccurrence(tester, text, 'мама');
    expect(selection.value, const TextRange(start: 0, end: 4));
  });

  testWidgets('blurred words stay tappable and move focus', (tester) async {
    final selection = await _pumpWordFocus(tester, text);

    await tapWordOccurrence(tester, text, 'мама');
    await tapWordOccurrence(tester, text, 'баба.');
    expect(selection.value, const TextRange(start: 20, end: 25));
  });

  testWidgets('focusing a word does not change text layout', (tester) async {
    const long =
        'Ѓорѓи и Ќерка читаат „Љубов и њива“, а џебот е полн со ѕвезди. '
        'Ова е подолг текст што се прелева во неколку редови.';
    await _pumpWordFocus(tester, long, width: 220);

    final before = sharpParagraph(tester);
    final sizeBefore = before.size;
    final originBefore = before.localToGlobal(Offset.zero);
    final lastBoxBefore = before
        .getBoxesForSelection(
          TextSelection(baseOffset: long.length - 7, extentOffset: long.length),
        )
        .map((b) => b.toRect())
        .toList();

    await tapWordOccurrence(tester, long, 'њива“,');

    final blurred = tester.renderObject<RenderParagraph>(
      wordFocusParagraphs().first,
    );
    final sharp = sharpParagraph(tester);
    expect(sharp.size, sizeBefore);
    expect(sharp.localToGlobal(Offset.zero), originBefore);
    expect(blurred.size, sizeBefore);
    expect(blurred.localToGlobal(Offset.zero), originBefore);

    final lastBoxAfter = sharp
        .getBoxesForSelection(
          TextSelection(baseOffset: long.length - 7, extentOffset: long.length),
        )
        .map((b) => b.toRect())
        .toList();
    expect(lastBoxAfter, lastBoxBefore);
  });

  testWidgets('screen readers get the full text exactly once', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpWordFocus(tester, text);
    await tapWordOccurrence(tester, text, 'тато');

    expect(find.bySemanticsLabel(text), findsOneWidget);
    handle.dispose();
  });

  group('OCR result card word focus', () {
    testWidgets('visible switch defaults off and toggles the reading view', (
      tester,
    ) async {
      await tester.pumpWidget(_ocrCard(text));

      expect(find.text('Фокус на збор'), findsOneWidget);
      expect(tester.widget<Switch>(wordFocusSwitch()).value, isFalse);
      expect(find.byType(WordFocusText), findsNothing);
      expect(find.text(text), findsOneWidget);

      await tester.tap(wordFocusSwitch());
      await tester.pump();
      expect(find.byType(WordFocusText), findsOneWidget);

      await tapWordOccurrence(tester, text, 'баба.');
      expect(find.byType(ImageFiltered), findsOneWidget);

      await tester.tap(wordFocusSwitch());
      await tester.pump();
      expect(find.byType(WordFocusText), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text(text), findsOneWidget);

      await tester.tap(wordFocusSwitch());
      await tester.pump();
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text('Тргни фокус'), findsNothing);
    });

    testWidgets('«Тргни фокус» clears the word but keeps focus enabled', (
      tester,
    ) async {
      await tester.pumpWidget(_ocrCard(text));
      await tester.tap(wordFocusSwitch());
      await tester.pump();

      await tapWordOccurrence(tester, text, 'тато');
      await tester.tap(find.text('Тргни фокус'));
      await tester.pump();

      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(WordFocusText), findsOneWidget);
      expect(tester.widget<Switch>(wordFocusSwitch()).value, isTrue);
    });

    testWidgets('changing displayed text clears the word, focus stays on', (
      tester,
    ) async {
      await tester.pumpWidget(_ocrCard(text));
      await tester.tap(wordFocusSwitch());
      await tester.pump();
      await tapWordOccurrence(tester, text, 'тато');
      expect(find.byType(ImageFiltered), findsOneWidget);

      const simplified = 'Мама и тато се дома.';
      await tester.pumpWidget(_ocrCard(simplified));
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text('Тргни фокус'), findsNothing);
      expect(
        tester.widget<WordFocusText>(find.byType(WordFocusText)).text,
        simplified,
      );
    });

    testWidgets('edit mode shows the existing editor', (tester) async {
      await tester.pumpWidget(_ocrCard(text));
      await tester.tap(wordFocusSwitch());
      await tester.pump();

      await tester.pumpWidget(_ocrCard(text, isEditing: true));
      expect(find.byType(WordFocusText), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
