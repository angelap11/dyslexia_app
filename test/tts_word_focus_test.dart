import 'package:dyslexia_app/core/theme.dart';
import 'package:dyslexia_app/features/ocr/ocr_widgets/extracted_text_box.dart';
import 'package:dyslexia_app/features/settings/provider.dart';
import 'package:dyslexia_app/features/tts/tts_screen.dart';
import 'package:dyslexia_app/widgets/ui/word_focus_controls.dart';
import 'package:dyslexia_app/widgets/ui/word_focus_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_tts_service.dart';
import 'helpers/word_focus_helpers.dart';

typedef _FakeTts = FakeTtsService;

const _emptyHint = 'Внеси или залепи текст за да користиш фокус на збор.';

/// Whitespace, punctuation, tabs and paragraphs that must survive exactly.
const _pasted =
    '  „Здраво“, рече мама.\n\n\tМама и тато  читаат…  мама!\n'
    'Ѓорѓи, ќерка, љубов, њива, џеб, ѕвезда?  ';

Future<_FakeTts> _pumpTts(
  WidgetTester tester, {
  Size size = const Size(360, 780),
  bool dark = false,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final tts = _FakeTts();
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>(
      create: (_) => SettingsProvider(),
      child: MaterialApp(
        theme: buildAppTheme(dyslexiaFont: true, isDark: dark),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: TtsScreen(ttsService: tts),
          ),
        ),
      ),
    ),
  );
  return tts;
}

String _editorText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

Future<void> _setFocus(WidgetTester tester) async {
  await tester.tap(wordFocusSwitch());
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  testWidgets('empty or whitespace input disables the switch with a hint', (
    tester,
  ) async {
    await _pumpTts(tester);

    expect(find.text(WordFocusSwitchRow.label), findsOneWidget);
    expect(tester.widget<Switch>(wordFocusSwitch()).onChanged, isNull);
    expect(find.text(_emptyHint), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  \n\t  ');
    await tester.pump();
    expect(tester.widget<Switch>(wordFocusSwitch()).onChanged, isNull);
    expect(find.text(_emptyHint), findsOneWidget);
    expect(find.byType(WordFocusText), findsNothing);
  });

  testWidgets('pasted text survives ON/OFF and «Уреди текст» exactly', (
    tester,
  ) async {
    await _pumpTts(tester);
    await tester.enterText(find.byType(TextField), _pasted);
    await tester.pump();
    expect(find.text(_emptyHint), findsNothing);
    expect(tester.widget<Switch>(wordFocusSwitch()).value, isFalse);

    for (var round = 0; round < 3; round++) {
      await _setFocus(tester);
      expect(find.byType(TextField), findsNothing);
      expect(
        tester.widget<WordFocusText>(find.byType(WordFocusText)).text,
        _pasted,
      );
      expect(find.text('Уреди текст'), findsOneWidget);

      if (round.isEven) {
        await _setFocus(tester);
      } else {
        await tester.tap(find.text('Уреди текст'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(WordFocusText), findsNothing);
      expect(_editorText(tester), _pasted);
      expect(tester.widget<Switch>(wordFocusSwitch()).value, isFalse);
    }
  });

  testWidgets('turning focus on hides the keyboard', (tester) async {
    await _pumpTts(tester);
    await tester.enterText(find.byType(TextField), _pasted);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await _setFocus(tester);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('word selection, moving and clearing on «Слушај текст»', (
    tester,
  ) async {
    await _pumpTts(tester);
    await _type(tester, _pasted);
    await _setFocus(tester);

    await tapWordOccurrence(tester, _pasted, 'мама!');
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.text('Тргни фокус'), findsOneWidget);

    await tapWordOccurrence(tester, _pasted, 'тато');
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(
      sharpParagraph(tester).text.toPlainText(),
      _pasted,
      reason: 'the read-only view renders the controller text verbatim',
    );

    await tapWordOccurrence(tester, _pasted, 'тато');
    expect(find.byType(ImageFiltered), findsNothing);

    await tapWordOccurrence(tester, _pasted, 'Мама');
    await tester.tap(find.text('Тргни фокус'));
    await tester.pump();
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(WordFocusText), findsOneWidget);
    expect(tester.widget<Switch>(wordFocusSwitch()).value, isTrue);
  });

  testWidgets('focus never starts speech; mode switches stop it', (
    tester,
  ) async {
    final tts = await _pumpTts(tester);
    await _type(tester, _pasted);
    await _setFocus(tester);
    await tapWordOccurrence(tester, _pasted, 'мама!');
    expect(tts.speakCalls, 0);

    await tester.tap(find.text('Слушај'));
    await tester.pump();
    expect(tts.speakCalls, 1);
    expect(find.text('Слуша'), findsOneWidget);

    final stopsBefore = tts.stopCalls;
    await _setFocus(tester);
    expect(tts.stopCalls, greaterThan(stopsBefore));
    expect(find.text('Слушај'), findsOneWidget);
    expect(_editorText(tester), _pasted);
    expect(tts.speakCalls, 1);

    await tester.tap(find.text('Слушај'));
    await tester.pump();
    expect(tts.speakCalls, 2);
    final stopsBeforeOn = tts.stopCalls;
    await _setFocus(tester);
    expect(tts.stopCalls, greaterThan(stopsBeforeOn));
    expect(
      tester.widget<WordFocusText>(find.byType(WordFocusText)).text,
      _pasted,
    );
  });

  testWidgets('each screen keeps its own focus switch', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var ocrFocusOn = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: MaterialApp(
          home: Row(
            children: [
              SizedBox(width: 600, child: TtsScreen(ttsService: _FakeTts())),
              Expanded(
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => ExtractedTextBox(
                      text: 'Скениран текст за читање.',
                      isLoading: false,
                      dyslexiaMode: false,
                      wordFocusOn: ocrFocusOn,
                      onWordFocusChanged: (on) =>
                          setState(() => ocrFocusOn = on),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Switch switchAt(int index) =>
        tester.widget<Switch>(wordFocusSwitch().at(index));

    await _type(tester, _pasted);
    await tester.tap(wordFocusSwitch().at(0));
    await tester.pumpAndSettle();
    expect(switchAt(0).value, isTrue);
    expect(switchAt(1).value, isFalse);
    expect(find.byType(WordFocusText), findsOneWidget);

    await tester.tap(wordFocusSwitch().at(0));
    await tester.pumpAndSettle();
    await tester.tap(wordFocusSwitch().at(1));
    await tester.pumpAndSettle();
    expect(switchAt(0).value, isFalse);
    expect(switchAt(1).value, isTrue);
  });

  // Narrow phones at maximum text size already overflow in ReadingControls
  // and the screen column without word focus, so that combination is covered
  // by the isolated switch-row test below.
  const layouts = [(Size(360, 780), 1.0), (Size(800, 1280), 1.53)];
  for (final dark in [false, true]) {
    for (final (size, scale) in layouts) {
      testWidgets(
        'no overflow: ${dark ? 'dark' : 'light'} ${size.width.toInt()}w, '
        'text ×$scale, both modes',
        (tester) async {
          await _pumpTts(tester, size: size, dark: dark, textScale: scale);
          expect(tester.takeException(), isNull);

          await _type(tester, _pasted);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await _setFocus(tester);
          await tapWordOccurrence(tester, _pasted, 'мама.');
          expect(tester.takeException(), isNull);
          expect(find.text('Уреди текст'), findsOneWidget);
        },
      );
    }
  }

  for (final dark in [false, true]) {
    testWidgets('switch row wraps on a narrow card with large text '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      Widget row({required bool on, String? hint}) => MaterialApp(
        theme: buildAppTheme(dyslexiaFont: true, isDark: dark),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 600),
            textScaler: TextScaler.linear(1.62),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 280,
                child: WordFocusSwitchRow(
                  value: on,
                  onChanged: hint == null ? (_) {} : null,
                  hint: hint,
                  action: on
                      ? TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Уреди текст'),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(row(on: false, hint: _emptyHint));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(row(on: true));
      expect(tester.takeException(), isNull);
      expect(find.text('Уреди текст'), findsOneWidget);
    });
  }
}
