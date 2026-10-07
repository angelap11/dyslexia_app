import 'package:dyslexia_app/app.dart';
import 'package:dyslexia_app/features/ocr/ocr_widgets/extracted_text_box.dart';
import 'package:dyslexia_app/features/settings/provider.dart';
import 'package:dyslexia_app/features/tts/tts_screen.dart';
import 'package:dyslexia_app/widgets/ui/reading_ruler_overlay.dart';
import 'package:dyslexia_app/widgets/ui/word_focus_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_tts_service.dart';
import 'helpers/settings_sync_fakes.dart';
import 'helpers/word_focus_helpers.dart';

class _FakeUser implements User {
  @override
  String get uid => 'ruler-test-user';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _pasted =
    '  „Здраво“, рече мама.\n\n\tМама и тато  читаат…  мама!\n'
    'Ѓорѓи, ќерка, љубов, њива, џеб, ѕвезда?  ';

const _homeLabel = 'session-home';

/// Pumps the real [MyApp] + auth gate. Like FirebaseAuth, every call to the
/// auth factory returns a *new* stream.
Future<SettingsProvider> _pumpApp(
  WidgetTester tester, {
  required WidgetBuilder screen,
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final user = _FakeUser();
  // Real provider; the auth gate loads this account's settings itself.
  final settings = SettingsProvider(
    localStore: MemorySettingsLocalStore(),
    currentUid: () => user.uid,
  );
  await tester.pumpWidget(
    MyApp(
      settingsProvider: settings,
      authStateChanges: () => Stream<User?>.value(user),
      sessionHomeBuilder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: screen)),
            child: const Text(_homeLabel),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(_homeLabel));
  await tester.pumpAndSettle();
  return settings;
}

String _ttsText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

class _OcrResultPage extends StatefulWidget {
  final String text;

  const _OcrResultPage({required this.text});

  @override
  State<_OcrResultPage> createState() => _OcrResultPageState();
}

class _OcrResultPageState extends State<_OcrResultPage> {
  bool _wordFocusOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ExtractedTextBox(
        text: widget.text,
        isLoading: false,
        dyslexiaMode: false,
        expand: true,
        onCopy: () {},
        wordFocusOn: _wordFocusOn,
        onWordFocusChanged: (on) => setState(() => _wordFocusOn = on),
      ),
    );
  }
}

void main() {
  testWidgets('«Слушај текст»: ruler ON/OFF/ON keeps screen and exact text', (
    tester,
  ) async {
    final settings = await _pumpApp(
      tester,
      screen: (_) => TtsScreen(ttsService: FakeTtsService()),
    );
    expect(find.byType(TtsScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), _pasted);
    await tester.pump();

    for (final expected in [true, false, true]) {
      await tester.tap(find.widgetWithText(FilterChip, 'Линијар'));
      await tester.pumpAndSettle();

      expect(settings.readingRulerEnabled, expected);
      expect(find.byType(TtsScreen), findsOneWidget);
      expect(find.text(_homeLabel), findsNothing);
      expect(_ttsText(tester), _pasted);
    }

    // Reading mode + focused word survive ruler toggles too.
    await tester.tap(wordFocusSwitch());
    await tester.pumpAndSettle();
    await tapWordOccurrence(tester, _pasted, 'тато');
    expect(find.byType(ImageFiltered), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.widgetWithText(FilterChip, 'Линијар'));
      await tester.pumpAndSettle();
      expect(find.byType(TtsScreen), findsOneWidget);
      expect(
        tester.widget<WordFocusText>(find.byType(WordFocusText)).text,
        _pasted,
      );
      expect(find.byType(ImageFiltered), findsOneWidget);
    }
  });

  testWidgets('«Скенирај текст»: ruler toggles keep text, focus and scroll', (
    tester,
  ) async {
    final text = List.filled(
      40,
      'Ова е долг скениран текст за читање со линијар.',
    ).join(' ');
    final settings = await _pumpApp(
      tester,
      screen: (_) => _OcrResultPage(text: text),
    );

    await tester.tap(wordFocusSwitch());
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byType(ExtractedTextBox),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(scrollable).position.jumpTo(120);
    await tester.pump();

    for (final expected in [true, false, true]) {
      await tester.tap(find.byTooltip('Повеќе'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(expected ? 'Линијар за читање' : 'Линијар (вкл.)'),
      );
      await tester.pumpAndSettle();

      expect(settings.readingRulerEnabled, expected);
      expect(find.byType(_OcrResultPage), findsOneWidget);
      expect(find.text(_homeLabel), findsNothing);
      expect(
        tester.widget<WordFocusText>(find.byType(WordFocusText)).text,
        text,
      );
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 120);
    }
  });

  testWidgets('hiding and showing the ruler keeps its last position', (
    tester,
  ) async {
    var enabled = true;
    late StateSetter setOuterState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 480,
            child: StatefulBuilder(
              builder: (context, setState) {
                setOuterState = setState;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    SingleChildScrollView(child: Text('Ред\n' * 60)),
                    ReadingRulerOverlay(
                      enabled: enabled,
                      textStyle: const TextStyle(fontSize: 20, height: 1.5),
                      contentTopInset: 100,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final band = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label == 'Помести ја линијата за читање',
    );
    final initialTop = tester.getTopLeft(band).dy;

    await tester.drag(band, const Offset(0, 120));
    await tester.pumpAndSettle();
    final movedTop = tester.getTopLeft(band).dy;
    expect(movedTop, greaterThan(initialTop));

    setOuterState(() => enabled = false);
    await tester.pumpAndSettle();
    expect(band, findsNothing);

    setOuterState(() => enabled = true);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(band).dy, movedTop);
  });
}
