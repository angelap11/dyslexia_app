import 'dart:io';

import 'package:dyslexia_app/features/history/history_database.dart';
import 'package:dyslexia_app/features/history/legacy_history_migration.dart';
import 'package:dyslexia_app/features/history/saved_text.dart';
import 'package:dyslexia_app/features/history/saved_texts_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/saved_texts_fakes.dart';

void main() {
  final files = TempHistoryFiles();

  setUp(files.setUp);
  tearDown(files.tearDown);

  /// Creates a database exactly like the old app (schema version 1).
  Future<void> createLegacyDb(
    String fileName,
    List<Map<String, Object?>> rows,
  ) async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      p.join(files.dbDir, fileName),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE history_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fileName TEXT NOT NULL,
            filePath TEXT NOT NULL,
            fileType TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            isFavorite INTEGER NOT NULL DEFAULT 0
          )
        '''),
      ),
    );
    for (final row in rows) {
      await db.insert('history_files', row);
    }
    await db.close();
  }

  String legacyFile(String name, String content) {
    final file = File(p.join(files.docsDir, 'document_history', name))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return file.path;
  }

  Map<String, Object?> row(
    String name,
    String path,
    String type, {
    String createdAt = '2026-03-04T08:30:00.000',
    bool favorite = false,
  }) => {
    'fileName': name,
    'filePath': path,
    'fileType': type,
    'createdAt': createdAt,
    'isFavorite': favorite ? 1 : 0,
  };

  Future<String?> extract(String path, String fileName) async {
    if (fileName.startsWith('broken')) throw const FormatException('bad pdf');
    return File(path).readAsString();
  }

  Future<LegacyHistoryMigration> migrationFor(String uid) async =>
      LegacyHistoryMigration(
        await HistoryDatabase.forUid(uid),
        extractText: extract,
      );

  test(
    'upgrades the old schema in place and migrates only known files',
    () async {
      final story = legacyFile('1_Приказна.txt', 'Еднаш одамна...');
      final photo = legacyFile('photo.jpg', 'jpeg');
      final broken = legacyFile('broken.pdf', 'x');
      final empty = legacyFile('empty.txt', '   ');
      await createLegacyDb('history_alice.db', [
        row('Приказна.txt', story, 'text'),
        row('OCR Камера 2026-03-04_08-31.jpg', photo, 'image'),
        row('Избришан.pdf', p.join(files.docsDir, 'gone.pdf'), 'pdf'),
        row('broken.pdf', broken, 'pdf'),
        row('empty.txt', empty, 'text'),
      ]);

      final migration = await migrationFor('alice');
      final report = await migration.run();
      expect(report.migrated, 1);
      expect(report.deviceOnly, 1);
      expect(report.attention, 3);

      final db = await HistoryDatabase.forUid('alice');
      final texts = await db.query(HistoryDatabase.textsTable);
      expect(texts, hasLength(1));
      final item = texts.single;
      expect(item['title'], 'Приказна');
      expect(item['originalText'], 'Еднаш одамна...');
      expect(item['simplifiedText'], isNull);
      expect(item['source'], 'legacy');
      expect(
        item['createdAt'],
        DateTime.parse('2026-03-04T08:30:00.000').millisecondsSinceEpoch,
      );
      expect(item['pendingOp'], 'upsert');
      expect(item['attachmentOwned'], 0);

      // Legacy rows and files are untouched.
      expect(await db.query(HistoryDatabase.legacyTable), hasLength(5));
      for (final path in [story, photo, broken, empty]) {
        expect(File(path).existsSync(), isTrue);
      }

      final leftovers = await migration.unmigratedEntries();
      expect(leftovers.map((e) => e.reason).toSet(), {
        'image',
        'missing',
        'unreadable',
        'empty',
      });
    },
  );

  test(
    'repeated and restarted runs never duplicate or restore items',
    () async {
      final story = legacyFile('a.txt', 'Текст');
      await createLegacyDb('history_alice.db', [row('a.txt', story, 'text')]);

      await (await migrationFor('alice')).run();
      await files.restart();
      await (await migrationFor('alice')).run();
      final db = await HistoryDatabase.forUid('alice');
      final texts = await db.query(HistoryDatabase.textsTable);
      expect(texts, hasLength(1));

      // The user deletes the migrated item; later runs keep it deleted.
      final controller = SavedTextsController(
        currentUid: () => 'alice',
        documentsDir: () async => files.docsDir,
        extractLegacyText: extract,
        observeLifecycle: false,
      );
      addTearDown(controller.dispose);
      await controller.switchUser('alice');
      expect(controller.items, hasLength(1));
      await controller.delete(controller.items.single.id);
      await files.restart();
      await controller.switchUser('alice');
      expect(controller.items, isEmpty);
      expect(
        await (await HistoryDatabase.forUid(
          'alice',
        )).query(HistoryDatabase.textsTable, where: 'deleted = 0'),
        isEmpty,
      );
    },
  );

  test('a file that reappears is migrated on a later run', () async {
    final path = p.join(files.docsDir, 'document_history', 'late.txt');
    await createLegacyDb('history_alice.db', [row('late.txt', path, 'text')]);
    expect((await (await migrationFor('alice')).run()).attention, 1);

    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('Сега постои');
    final report = await (await migrationFor('alice')).run();
    expect(report.migrated, 1);
    expect(report.attention, 0);
  });

  test(
    'copies of the same document become one item with the earliest date',
    () async {
      final doc = legacyFile('1_Текст.txt', 'Ист текст');
      final copy = legacyFile('2_Текст.txt', 'Ист текст');
      await createLegacyDb('history_alice.db', [
        row('Текст.txt', doc, 'text', createdAt: '2026-04-02T10:00:00.000'),
        row('Текст.txt', copy, 'text', createdAt: '2026-04-01T09:00:00.000'),
      ]);
      final report = await (await migrationFor('alice')).run();
      expect(report.migrated, 2);
      final texts = await (await HistoryDatabase.forUid(
        'alice',
      )).query(HistoryDatabase.textsTable);
      expect(texts, hasLength(1));
      expect(
        texts.single['createdAt'],
        DateTime.parse('2026-04-01T09:00:00.000').millisecondsSinceEpoch,
      );
    },
  );

  test('oversized legacy text is kept complete on this device only', () async {
    final big = legacyFile(
      'big.txt',
      'ш' * (SavedTextLimits.maxTextBytes ~/ 2 + 1),
    );
    await createLegacyDb('history_alice.db', [row('big.txt', big, 'text')]);
    await (await migrationFor('alice')).run();
    final item = (await (await HistoryDatabase.forUid(
      'alice',
    )).query(HistoryDatabase.textsTable)).single;
    expect(item['deviceOnlyReason'], 'tooLarge');
    expect(item['pendingOp'], isNull);
    expect(
      (item['originalText'] as String).length,
      SavedTextLimits.maxTextBytes ~/ 2 + 1,
    );
  });

  test('unscoped history.db and history_anonymous.db are never used', () async {
    final shared = legacyFile('shared.txt', 'Чиј е ова?');
    await createLegacyDb('history.db', [row('shared.txt', shared, 'text')]);
    await createLegacyDb('history_anonymous.db', [
      row('shared.txt', shared, 'text'),
    ]);
    final before = {
      for (final name in ['history.db', 'history_anonymous.db'])
        name: File(p.join(files.dbDir, name)).readAsBytesSync(),
    };

    final controller = SavedTextsController(
      currentUid: () => 'alice',
      documentsDir: () async => files.docsDir,
      extractLegacyText: extract,
      observeLifecycle: false,
    );
    addTearDown(controller.dispose);
    await controller.switchUser('alice');
    expect(controller.items, isEmpty);
    expect(controller.legacyEntries, isEmpty);
    expect(() => HistoryDatabase.forUid('anonymous'), throwsArgumentError);

    for (final entry in before.entries) {
      expect(
        File(p.join(files.dbDir, entry.key)).readAsBytesSync(),
        entry.value,
        reason: '${entry.key} must stay unchanged',
      );
    }
  });

  group('favourites', () {
    test('legacy stars become synced favourites', () async {
      await createLegacyDb('history_alice.db', [
        row(
          'star.txt',
          legacyFile('star.txt', 'Омилен'),
          'text',
          favorite: true,
        ),
        row('plain.txt', legacyFile('plain.txt', 'Обичен'), 'text'),
      ]);
      await (await migrationFor('alice')).run();
      final texts = await (await HistoryDatabase.forUid(
        'alice',
      )).query(HistoryDatabase.textsTable, orderBy: 'title');
      expect(texts.map((t) => (t['title'], t['favorite'])), [
        ('plain', 0),
        ('star', 1),
      ]);
      expect(texts.map((t) => t['pendingOp']), everyElement('upsert'));
    });

    test('a starred copy stars the merged item', () async {
      await createLegacyDb('history_alice.db', [
        row('Текст.txt', legacyFile('1_Текст.txt', 'Ист'), 'text'),
        row(
          'Текст.txt',
          legacyFile('2_Текст.txt', 'Ист'),
          'text',
          favorite: true,
        ),
      ]);
      await (await migrationFor('alice')).run();
      final item = (await (await HistoryDatabase.forUid(
        'alice',
      )).query(HistoryDatabase.textsTable)).single;
      expect(item['favorite'], 1);
      expect(item['localRevision'], 2);
      expect(item['pendingOp'], 'upsert');
    });

    test(
      'upgrading a version 2 database restores stars of migrated items',
      () async {
        final starred = legacyFile('a.txt', 'Со ѕвезда');
        final db = await databaseFactoryFfiNoIsolate.openDatabase(
          p.join(files.dbDir, 'history_alice.db'),
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, _) async {
              await db.execute('''
              CREATE TABLE history_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT, fileName TEXT NOT NULL,
                filePath TEXT NOT NULL, fileType TEXT NOT NULL,
                createdAt TEXT NOT NULL,
                isFavorite INTEGER NOT NULL DEFAULT 0)
            ''');
              await db.execute('''
              CREATE TABLE saved_texts (
                id TEXT PRIMARY KEY, title TEXT NOT NULL,
                source TEXT NOT NULL, originalText TEXT NOT NULL,
                simplifiedText TEXT, createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0,
                localRevision INTEGER NOT NULL DEFAULT 1,
                syncedRevision INTEGER NOT NULL DEFAULT 0,
                serverRevision INTEGER NOT NULL DEFAULT 0, pendingOp TEXT,
                uploadAttempted INTEGER NOT NULL DEFAULT 0,
                deviceOnlyReason TEXT, lastError TEXT, attachmentPath TEXT,
                attachmentType TEXT,
                attachmentOwned INTEGER NOT NULL DEFAULT 0)
            ''');
              await db.execute('''
              CREATE TABLE legacy_migration (
                legacyId INTEGER PRIMARY KEY, textId TEXT,
                status TEXT NOT NULL, reason TEXT,
                updatedAt INTEGER NOT NULL)
            ''');
              await db.execute(
                'CREATE TABLE sync_meta (key TEXT PRIMARY KEY, '
                'value TEXT NOT NULL)',
              );
            },
          ),
        );
        await db.insert(
          'history_files',
          row('a.txt', starred, 'text', favorite: true),
        );
        await db.insert(
          'history_files',
          row('b.txt', starred, 'text', favorite: true),
        );
        for (final (id, deleted) in [('item_aaaa1', 0), ('item_bbbb2', 1)]) {
          await db.insert('saved_texts', {
            'id': id,
            'title': deleted == 1 ? '' : 'a',
            'source': 'legacy',
            'originalText': deleted == 1 ? '' : 'Со ѕвезда',
            'createdAt': 1,
            'updatedAt': 1,
            'deleted': deleted,
            'syncedRevision': 1,
            'serverRevision': 1,
            'uploadAttempted': 1,
          });
        }
        await db.insert('legacy_migration', {
          'legacyId': 1,
          'textId': 'item_aaaa1',
          'status': 'migrated',
          'updatedAt': 1,
        });
        await db.insert('legacy_migration', {
          'legacyId': 2,
          'textId': 'item_bbbb2',
          'status': 'migrated',
          'updatedAt': 1,
        });
        await db.close();

        final upgraded = await HistoryDatabase.forUid('alice');
        final rows = {
          for (final r in await upgraded.query(HistoryDatabase.textsTable))
            r['id']: r,
        };
        expect(rows['item_aaaa1']!['favorite'], 1);
        expect(rows['item_aaaa1']!['localRevision'], 2);
        expect(rows['item_aaaa1']!['pendingOp'], 'upsert');
        // A deleted item stays deleted and unstarred.
        expect(rows['item_bbbb2']!['favorite'], 0);
        expect(rows['item_bbbb2']!['pendingOp'], isNull);
      },
    );
  });

  test(
    '«Избриши сè» hides legacy leftovers and stops later conversion',
    () async {
      final story = legacyFile('a.txt', 'Текст');
      final photo = legacyFile('photo.jpg', 'jpeg');
      await createLegacyDb('history_alice.db', [
        row('a.txt', story, 'text'),
        row('photo.jpg', photo, 'image'),
        row('late.txt', p.join(files.docsDir, 'late.txt'), 'text'),
      ]);
      final controller = SavedTextsController(
        currentUid: () => 'alice',
        documentsDir: () async => files.docsDir,
        extractLegacyText: extract,
        observeLifecycle: false,
      );
      addTearDown(controller.dispose);
      await controller.switchUser('alice');
      expect(controller.items, hasLength(1));
      expect(controller.legacyEntries, hasLength(2));

      // A legacy row the background migration has not reached yet.
      final db = await HistoryDatabase.forUid('alice');
      final unseen = legacyFile('unseen.txt', 'Нов');
      await db.insert(
        HistoryDatabase.legacyTable,
        row('unseen.txt', unseen, 'text'),
      );

      expect(await controller.deleteAll(uid: 'alice'), 1);
      expect(controller.items, isEmpty);
      expect(controller.legacyEntries, isEmpty);
      expect(controller.totalCount, 0);

      // The missing file appears and the app restarts: nothing comes back.
      File(p.join(files.docsDir, 'late.txt')).writeAsStringSync('Сега има');
      await files.restart();
      await controller.switchUser('alice');
      expect(controller.items, isEmpty);
      expect(controller.legacyEntries, isEmpty);
      expect(controller.migrationReport!.attention, 0);
      expect(controller.migrationReport!.deviceOnly, 0);

      // Legacy rows and files are untouched.
      expect(
        await (await HistoryDatabase.forUid(
          'alice',
        )).query(HistoryDatabase.legacyTable),
        hasLength(4),
      );
      for (final path in [story, photo, unseen]) {
        expect(File(path).existsSync(), isTrue);
      }
    },
  );

  test('each account migrates only its own database', () async {
    await createLegacyDb('history_alice.db', [
      row('a.txt', legacyFile('a.txt', 'Алиса'), 'text'),
    ]);
    await createLegacyDb('history_bob.db', [
      row('b.txt', legacyFile('b.txt', 'Боб'), 'text'),
    ]);
    final controller = SavedTextsController(
      currentUid: () => null,
      documentsDir: () async => files.docsDir,
      extractLegacyText: extract,
      observeLifecycle: false,
    );
    addTearDown(controller.dispose);
    await controller.switchUser('alice');
    expect(controller.items.map((e) => e.title), ['a']);
    await controller.switchUser('bob');
    expect(controller.items.map((e) => e.title), ['b']);
  });
}
