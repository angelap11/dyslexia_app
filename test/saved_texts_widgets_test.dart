import 'package:dyslexia_app/features/history/history_screen.dart';
import 'package:dyslexia_app/features/history/saved_text.dart';
import 'package:dyslexia_app/features/history/saved_texts_controller.dart';
import 'package:dyslexia_app/features/history/saved_texts_local_store.dart';
import 'package:dyslexia_app/features/ocr/ocr_screen.dart';
import 'package:dyslexia_app/features/ocr/ocr_service.dart';
import 'package:dyslexia_app/features/settings/provider.dart';
import 'package:dyslexia_app/features/simplify/widgets/simplify_text_bar.dart';
import 'package:dyslexia_app/features/tts/tts_screen.dart';
import 'package:dyslexia_app/widgets/ui/word_focus_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_tts_service.dart';
import 'helpers/saved_texts_fakes.dart';
import 'helpers/settings_sync_fakes.dart';
import 'helpers/word_focus_helpers.dart';

class _FakeOcrService implements OcrService {
  final String text;

  _FakeOcrService(this.text);

  @override
  Future<XFile?> pickImage({bool fromCamera = false}) async =>
      XFile('C:/fake/scan.jpg');

  @override
  Future<String> scanText(XFile image) async => text;

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _uid = 'widget-user';

class _Harness {
  final SettingsProvider settings;
  final SavedTextsController controller;
  final FakeTextsServer server;

  _Harness(this.settings, this.controller, this.server);
}

Future<_Harness> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});

  final dbs = MemoryHistoryDatabases();
  final server = FakeTextsServer();
  final settings = SettingsProvider(
    localStore: MemorySettingsLocalStore(),
    currentUid: () => _uid,
  );
  final controller = SavedTextsController(
    remote: FakeSavedTextsRemote(server),
    currentUid: () => _uid,
    openDatabase: dbs.open,
    // Attachments need real file I/O, which these tests do not use.
    documentsDir: () => Future.error(UnsupportedError('no files')),
    extractLegacyText: (_, _) async => null,
    retryBase: const Duration(hours: 1),
    observeLifecycle: false,
  );
  addTearDown(() async {
    controller.dispose();
    await dbs.closeAll();
  });
  await settings.switchUser(_uid);
  await controller.switchUser(_uid);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: controller),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(settings, controller, server);
}

Finder get _saveAction => find.byKey(const ValueKey('save-text-action'));
Finder get _confirm => find.byKey(const ValueKey('save-confirm'));

Future<void> _openSaveSheet(WidgetTester tester) async {
  await tester.tap(_saveAction);
  await tester.pumpAndSettle();
}

Future<void> _confirmSave(WidgetTester tester) async {
  await tester.tap(_confirm);
  await tester.pumpAndSettle();
}

String _editorText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

void main() {
  group('«Слушај текст»', () {
    testWidgets('saves once; repeated taps say it is already saved', (
      tester,
    ) async {
      final h = await _pump(tester, TtsScreen(ttsService: FakeTtsService()));
      const text = 'Мама и тато читаат книга.';
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();

      await _openSaveSheet(tester);
      expect(find.text('Зачувај во историја'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('save-title-field')),
        'Книга',
      );
      await _confirmSave(tester);

      expect(find.text('Зачувано на уредот.'), findsOneWidget);
      expect(h.controller.items.single.title, 'Книга');
      expect(find.text('Зачувано во сметката'), findsOneWidget);
      expect(h.server.docsOf(_uid), hasLength(1));

      for (var i = 0; i < 3; i++) {
        await tester.tap(_saveAction);
        await tester.pumpAndSettle();
        expect(find.text('Зачувај во историја'), findsNothing);
      }
      expect(find.text('Веќе е зачувано.'), findsOneWidget);
      expect(h.controller.items, hasLength(1));
      expect(_editorText(tester), text);
    });

    testWidgets('a double tap on confirm saves one item and stays on screen', (
      tester,
    ) async {
      final h = await _pump(tester, TtsScreen(ttsService: FakeTtsService()));
      await tester.enterText(find.byType(TextField), 'Брз двоен допир.');
      await tester.pump();
      await _openSaveSheet(tester);
      await tester.tap(_confirm);
      await tester.tap(_confirm, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(TtsScreen), findsOneWidget);
      expect(h.controller.items, hasLength(1));
    });

    testWidgets('changed text can update the item or be saved as new', (
      tester,
    ) async {
      final h = await _pump(tester, TtsScreen(ttsService: FakeTtsService()));
      await tester.enterText(find.byType(TextField), 'Прва верзија.');
      await tester.pump();
      await _openSaveSheet(tester);
      await _confirmSave(tester);
      final firstId = h.controller.items.single.id;

      await tester.enterText(find.byType(TextField), 'Втора верзија.');
      await tester.pump();
      await _openSaveSheet(tester);
      expect(find.text('Зачувај промени'), findsWidgets);
      await _confirmSave(tester);
      expect(h.controller.items.single.id, firstId);
      expect(
        (await h.controller.load(firstId))!.originalText,
        'Втора верзија.',
      );

      await tester.enterText(find.byType(TextField), 'Трета верзија.');
      await tester.pump();
      await _openSaveSheet(tester);
      await tester.tap(find.byKey(const ValueKey('save-as-new')));
      await tester.pumpAndSettle();
      expect(h.controller.items, hasLength(2));
      expect(
        (await h.controller.load(firstId))!.originalText,
        'Втора верзија.',
      );
    });

    testWidgets('empty text is not saved', (tester) async {
      final h = await _pump(tester, TtsScreen(ttsService: FakeTtsService()));
      expect(_saveAction, findsNothing);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(_saveAction, findsNothing);
      expect(h.controller.items, isEmpty);
    });

    testWidgets('opening a saved item keeps both versions when switching', (
      tester,
    ) async {
      final item = SavedText(
        id: SavedTextIds.generate(),
        title: 'Две верзии',
        source: SavedTextSource.camera,
        originalText: 'Ова е оригиналниот, подолг и потежок текст.',
        simplifiedText: 'Ова е лесен текст.',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
        syncState: SavedTextSyncState.synced,
      );
      final h = await _pump(
        tester,
        TtsScreen(ttsService: FakeTtsService(), initialText: item),
      );
      await h.controller.save(
        SaveTextRequest(
          id: item.id,
          title: item.title,
          source: item.source,
          originalText: item.originalText,
          simplifiedText: item.simplifiedText,
        ),
      );
      await tester.pumpAndSettle();
      expect(_editorText(tester), item.originalText);

      Finder tab(String label) => find.descendant(
        of: find.byType(SimplifyTextBar),
        matching: find.text(label),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(tab('Поедноставен текст'));
        await tester.pumpAndSettle();
        expect(_editorText(tester), item.simplifiedText);
        await tester.tap(tab('Оригинален текст'));
        await tester.pumpAndSettle();
        expect(_editorText(tester), item.originalText);
      }

      // Nothing changed, so saving does not create anything new.
      await tester.tap(_saveAction);
      await tester.pumpAndSettle();
      expect(find.text('Веќе е зачувано.'), findsOneWidget);
      expect(h.controller.items, hasLength(1));
      final stored = (await h.controller.load(item.id))!;
      expect(stored.originalText, item.originalText);
      expect(stored.simplifiedText, item.simplifiedText);
    });

    testWidgets('ruler and Word Focus keep the saved text on screen', (
      tester,
    ) async {
      final h = await _pump(tester, TtsScreen(ttsService: FakeTtsService()));
      const text = 'Читаме полека со линијар и фокус на збор.';
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await _openSaveSheet(tester);
      await _confirmSave(tester);

      for (final expected in [true, false]) {
        await tester.tap(find.widgetWithText(FilterChip, 'Линијар'));
        await tester.pumpAndSettle();
        expect(h.settings.readingRulerEnabled, expected);
        expect(find.byType(TtsScreen), findsOneWidget);
        expect(_editorText(tester), text);
        expect(find.text('Зачувано во сметката'), findsOneWidget);
      }

      await tester.tap(wordFocusSwitch());
      await tester.pumpAndSettle();
      expect(
        tester.widget<WordFocusText>(find.byType(WordFocusText)).text,
        text,
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Линијар'));
      await tester.pumpAndSettle();
      expect(find.byType(WordFocusText), findsOneWidget);
      expect(h.controller.items, hasLength(1));
    });
  });

  group('«Скенирај текст»', () {
    const scanned = 'Скениран текст од книгата за читање.';

    Future<_Harness> scan(WidgetTester tester) async {
      final h = await _pump(
        tester,
        OcrScreen(
          ocrService: _FakeOcrService(scanned),
          ttsService: FakeTtsService(),
        ),
      );
      await tester.tap(find.text('Галерија').first);
      await tester.pumpAndSettle();
      expect(find.text(scanned), findsOneWidget);
      return h;
    }

    testWidgets('scanning alone saves nothing; Зачувај saves once', (
      tester,
    ) async {
      final h = await scan(tester);
      expect(h.controller.items, isEmpty);

      await _openSaveSheet(tester);
      await _confirmSave(tester);
      final item = (await h.controller.load(h.controller.items.single.id))!;
      expect(item.source, SavedTextSource.gallery);
      expect(item.originalText, scanned);
      expect(item.attachmentPath, isNull);
      expect(find.text('Зачувано во сметката'), findsOneWidget);

      await tester.tap(_saveAction);
      await tester.pumpAndSettle();
      expect(find.text('Веќе е зачувано.'), findsOneWidget);
      expect(h.controller.items, hasLength(1));
    });

    testWidgets('edited OCR text is saved as edited', (tester) async {
      final h = await scan(tester);
      await tester.tap(find.byTooltip('Уреди'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Поправен текст.');
      await tester.pump();
      // Saving straight from edit mode keeps the edit.
      await _openSaveSheet(tester);
      await _confirmSave(tester);
      final item = (await h.controller.load(h.controller.items.single.id))!;
      expect(item.originalText, 'Поправен текст.');
    });

    testWidgets('ruler and Word Focus keep the scanned text after saving', (
      tester,
    ) async {
      final h = await scan(tester);
      await _openSaveSheet(tester);
      await _confirmSave(tester);
      await tester.tap(wordFocusSwitch());
      await tester.pumpAndSettle();

      for (final expected in [true, false]) {
        await tester.tap(find.byTooltip('Повеќе'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(expected ? 'Линијар за читање' : 'Линијар (вкл.)'),
        );
        await tester.pumpAndSettle();
        expect(h.settings.readingRulerEnabled, expected);
        expect(find.byType(OcrScreen), findsOneWidget);
        expect(
          tester.widget<WordFocusText>(find.byType(WordFocusText)).text,
          scanned,
        );
      }
      expect(h.controller.items, hasLength(1));
    });
  });

  group('History', () {
    testWidgets('lists versions and deletes only after confirmation', (
      tester,
    ) async {
      final h = await _pump(tester, const SizedBox());
      await h.controller.save(
        SaveTextRequest(
          id: SavedTextIds.generate(),
          title: 'Со поедноставување',
          source: SavedTextSource.listen,
          originalText: 'Долг текст.',
          simplifiedText: 'Краток.',
        ),
      );
      await h.controller.save(
        SaveTextRequest(
          id: SavedTextIds.generate(),
          title: 'Само оригинал',
          source: SavedTextSource.camera,
          originalText: 'Друг текст.',
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: h.settings),
            ChangeNotifierProvider.value(value: h.controller),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Со поедноставување'), findsOneWidget);
      expect(find.text('Само оригинал'), findsOneWidget);
      expect(find.text('Оригинал'), findsNWidgets(2));
      expect(find.text('Поедноставен'), findsOneWidget);

      Future<void> openMenuAndDelete() async {
        await tester.tap(find.byTooltip('Опции').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Избриши').last);
        await tester.pumpAndSettle();
      }

      await openMenuAndDelete();
      await tester.tap(find.text('Откажи'));
      await tester.pumpAndSettle();
      expect(h.controller.items, hasLength(2));

      await openMenuAndDelete();
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();
      expect(h.controller.items, hasLength(1));
      expect(find.text('Текстот е избришан.'), findsOneWidget);
      final deleted = h.server
          .docsOf(_uid)
          .values
          .where((d) => d['deleted'] == true);
      expect(deleted, hasLength(1));
    });

    Future<_Harness> historyWith(
      WidgetTester tester,
      List<String> titles,
    ) async {
      final h = await _pump(tester, const SizedBox());
      for (final title in titles) {
        await h.controller.save(
          SaveTextRequest(
            id: SavedTextIds.generate(),
            title: title,
            source: SavedTextSource.listen,
            originalText: 'Текст за $title.',
          ),
        );
      }
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: h.settings),
            ChangeNotifierProvider.value(value: h.controller),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('«Омилени»: the star syncs and sorts starred texts first', (
      tester,
    ) async {
      final h = await historyWith(tester, ['Прв', 'Втор', 'Трет']);
      final prv = h.controller.items.firstWhere((e) => e.title == 'Прв');

      await tester.tap(find.byKey(ValueKey('favorite-${prv.id}')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Отстрани од омилени'), findsOneWidget);
      expect(find.byTooltip('Додај во омилени'), findsNWidgets(2));
      expect(h.server.doc(_uid, prv.id)!['favorite'], true);

      await tester.tap(find.byTooltip('Подреди'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Омилени прво'));
      await tester.pumpAndSettle();
      expect(h.controller.sort, HistorySort.favorites);
      expect(h.controller.items.first.id, prv.id);
      final firstCardY = tester.getTopLeft(find.text('Прв')).dy;
      expect(firstCardY, lessThan(tester.getTopLeft(find.text('Втор')).dy));
      expect(firstCardY, lessThan(tester.getTopLeft(find.text('Трет')).dy));

      await tester.tap(find.byKey(ValueKey('favorite-${prv.id}')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Отстрани од омилени'), findsNothing);
      expect(h.server.doc(_uid, prv.id)!['favorite'], false);
    });

    testWidgets('«Избриши сè» deletes everything only after confirmation', (
      tester,
    ) async {
      final h = await historyWith(tester, ['Прв', 'Втор']);
      final deleteAll = find.byKey(const ValueKey('history-delete-all'));
      expect(deleteAll, findsOneWidget);

      await tester.tap(deleteAll);
      await tester.pumpAndSettle();
      expect(find.text('Бришење историја?'), findsOneWidget);
      expect(find.textContaining('(2) на сите уреди'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-delete-all')));
      await tester.pumpAndSettle();
      expect(h.controller.items, hasLength(2));
      expect(find.text('Прв'), findsOneWidget);

      await tester.tap(deleteAll);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-all')));
      await tester.pumpAndSettle();
      expect(h.controller.items, isEmpty);
      expect(find.text('Историјата е избришана.'), findsOneWidget);
      expect(find.text('Нема зачувани текстови'), findsOneWidget);
      expect(deleteAll, findsNothing);
      final docs = h.server.docsOf(_uid).values;
      expect(docs, hasLength(2));
      expect(docs.map((d) => d['deleted']), everyElement(true));
    });

    testWidgets('switching accounts clears the visible list at once', (
      tester,
    ) async {
      final h = await _pump(tester, const HistoryScreen());
      await h.controller.save(
        SaveTextRequest(
          id: SavedTextIds.generate(),
          title: 'Од првата сметка',
          source: SavedTextSource.listen,
          originalText: 'Текст.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Од првата сметка'), findsOneWidget);

      final switching = h.controller.switchUser('other-user');
      await tester.pump();
      expect(find.text('Од првата сметка'), findsNothing);
      await switching;
      await tester.pumpAndSettle();
      expect(find.text('Од првата сметка'), findsNothing);
      expect(find.text('Нема зачувани текстови'), findsOneWidget);
    });
  });
}
