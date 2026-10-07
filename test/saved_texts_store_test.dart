import 'dart:io';

import 'package:dyslexia_app/features/history/history_database.dart';
import 'package:dyslexia_app/features/history/saved_text.dart';
import 'package:dyslexia_app/features/history/saved_texts_local_store.dart';
import 'package:dyslexia_app/features/history/saved_texts_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers/saved_texts_fakes.dart';

void main() {
  final files = TempHistoryFiles();
  late SavedTextsLocalStore store;

  setUp(() async {
    files.setUp();
    store = SavedTextsLocalStore(
      await HistoryDatabase.forUid('alice'),
      uid: 'alice',
      documentsDir: () async => files.docsDir,
    );
  });

  tearDown(files.tearDown);

  SaveTextRequest request({
    String? id,
    String? title,
    String original = 'Мама и тато читаат.',
    String? simplified,
    SavedTextSource source = SavedTextSource.listen,
    SaveAttachment? attachment,
  }) => SaveTextRequest(
    id: id ?? SavedTextIds.generate(),
    title: title,
    source: source,
    originalText: original,
    simplifiedText: simplified,
    attachment: attachment,
  );

  group('save', () {
    test('stores the item and its queued upload together', () async {
      final outcome = await store.save(request(title: 'Прв'));
      expect(outcome.kind, SaveOutcomeKind.created);
      expect(outcome.item!.syncState, SavedTextSyncState.pending);
      final pending = await store.pendingChanges();
      expect(pending.single.id, outcome.item!.id);
      expect(pending.single.op, 'upsert');
    });

    test('repeating a save with the same id never duplicates', () async {
      final req = request();
      final results = await Future.wait([
        store.save(req),
        store.save(req),
        store.save(req),
      ]);
      expect(
        results.map((r) => r.kind),
        containsAll([SaveOutcomeKind.created, SaveOutcomeKind.unchanged]),
      );
      expect(
        results.where((r) => r.kind == SaveOutcomeKind.created),
        hasLength(1),
      );
      expect(await store.listPage(), hasLength(1));
      expect(await store.pendingChanges(), hasLength(1));
    });

    test('keeps original and simplified versions together', () async {
      final out = await store.save(
        request(original: 'Оригинал.', simplified: 'Поедноставено.'),
      );
      final item = (await store.get(out.item!.id))!;
      expect(item.originalText, 'Оригинал.');
      expect(item.simplifiedText, 'Поедноставено.');
      expect(item.hasSimplified, isTrue);
      final summary = (await store.listPage()).single;
      expect(summary.hasSimplified, isTrue);
    });

    test('updating content bumps the revision and queues one upload', () async {
      final req = request(original: 'Прва верзија.');
      await store.save(req);
      final updated = await store.save(
        SaveTextRequest(
          id: req.id,
          title: null,
          source: req.source,
          originalText: 'Втора верзија.',
          simplifiedText: 'Кратко.',
        ),
      );
      expect(updated.kind, SaveOutcomeKind.updated);
      expect(updated.item!.originalText, 'Втора верзија.');
      expect(updated.item!.simplifiedText, 'Кратко.');
      final pending = await store.pendingChanges();
      expect(pending.single.localRevision, 2);
    });

    test('rejects empty text and an over-long title', () async {
      expect(
        (await store.save(request(original: '  \n\t '))).kind,
        SaveOutcomeKind.emptyText,
      );
      expect(
        (await store.save(request(title: 'а' * 121))).kind,
        SaveOutcomeKind.titleTooLong,
      );
      expect(await store.listPage(), isEmpty);
    });

    test('uses the first words as the default title', () async {
      final out = await store.save(
        request(
          original:
              '  Ова е многу долг текст за насловот на ставката '
              'што продолжува понатаму и понатаму.',
        ),
      );
      expect(out.item!.title, startsWith('Ова е многу долг текст'));
      expect(out.item!.title.runes.length, lessThanOrEqualTo(49));
      expect(out.item!.title, endsWith('…'));
    });

    test('empty simplified text is not stored as a version', () async {
      final out = await store.save(request(simplified: '   '));
      expect(out.item!.simplifiedText, isNull);
    });
  });

  group('payload limits', () {
    // Cyrillic letters are two UTF-8 bytes.
    final exact = 'а' * (SavedTextLimits.maxTextBytes ~/ 2);

    test('text at exactly the limit is queued for the account', () async {
      final out = await store.save(request(original: exact, simplified: exact));
      expect(out.item!.syncState, SavedTextSyncState.pending);
      expect(await store.pendingChanges(), hasLength(1));
    });

    test('larger text stays on the device, complete and not queued', () async {
      final big = '${exact}x';
      final out = await store.save(request(original: big));
      expect(out.kind, SaveOutcomeKind.created);
      expect(out.item!.syncState, SavedTextSyncState.deviceOnly);
      expect((await store.get(out.item!.id))!.originalText, big);
      expect(await store.pendingChanges(), isEmpty);
      expect((await store.counts()).deviceOnly, 1);
    });

    test('an oversized simplified version also keeps it device-only', () async {
      final out = await store.save(request(simplified: '$exactш'));
      expect(out.item!.syncState, SavedTextSyncState.deviceOnly);
    });
  });

  group('delete', () {
    test(
      'never-uploaded items leave a local tombstone and no cloud op',
      () async {
        final req = request();
        await store.save(req);
        expect(await store.delete(req.id), isTrue);
        expect(await store.get(req.id), isNull);
        expect(await store.listPage(), isEmpty);
        expect(await store.pendingChanges(), isEmpty);
        // A retried save with the same id cannot bring it back.
        expect((await store.save(req)).kind, SaveOutcomeKind.deleted);
        expect(await store.listPage(), isEmpty);
      },
    );

    test('items that may be in the cloud queue a tombstone upload', () async {
      final req = request();
      await store.save(req);
      final change = (await store.pendingChanges()).single;
      expect(await store.beginUpload(change), isNotNull);
      await store.delete(req.id);
      final pending = (await store.pendingChanges()).single;
      expect(pending.op, 'delete');
      final commit = (await store.beginUpload(pending))!;
      expect(commit.delete, isTrue);
      expect(commit.originalText, isEmpty);
    });

    test('deleting twice reports the second as already deleted', () async {
      final req = request();
      await store.save(req);
      expect(await store.delete(req.id), isTrue);
      expect(await store.delete(req.id), isFalse);
    });
  });

  group('attachments', () {
    test('owned copies are removed after a durable delete', () async {
      final photo = File(p.join(files.root.path, 'camera.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final req = request(
        source: SavedTextSource.camera,
        attachment: SaveAttachment.file(
          type: 'image',
          extension: 'jpg',
          path: photo.path,
        ),
      );
      final out = await store.save(req);
      final copy = out.item!.attachmentPath!;
      expect(p.isWithin(await store.ownedAttachmentDir(), copy), isTrue);
      expect(File(copy).existsSync(), isTrue);

      await store.delete(req.id);
      expect(File(copy).existsSync(), isFalse);
      // The picked source file is never touched.
      expect(photo.existsSync(), isTrue);
    });

    test('shared legacy files are never deleted', () async {
      final shared = File(p.join(files.docsDir, 'document_history', 'a.pdf'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1]);
      final db = await HistoryDatabase.forUid('alice');
      final id = SavedTextIds.generate();
      await db.insert(HistoryDatabase.textsTable, {
        'id': id,
        'title': 'Стар',
        'source': 'document',
        'originalText': 'Текст',
        'createdAt': 0,
        'updatedAt': 0,
        'attachmentPath': shared.path,
        'attachmentType': 'pdf',
        'attachmentOwned': 0,
      });
      await store.delete(id);
      expect(shared.existsSync(), isTrue);
    });

    test(
      'an owned flag on a path outside the owned folder is ignored',
      () async {
        final outside = File(p.join(files.root.path, 'elsewhere.txt'))
          ..writeAsStringSync('x');
        final db = await HistoryDatabase.forUid('alice');
        final id = SavedTextIds.generate();
        await db.insert(HistoryDatabase.textsTable, {
          'id': id,
          'title': 'Т',
          'source': 'listen',
          'originalText': 'Т',
          'createdAt': 0,
          'updatedAt': 0,
          'attachmentPath': outside.path,
          'attachmentOwned': 1,
        });
        await store.delete(id);
        expect(outside.existsSync(), isTrue);
      },
    );

    test('orphan cleanup removes only unreferenced owned files', () async {
      final dir = Directory(await store.ownedAttachmentDir())
        ..createSync(recursive: true);
      final orphan = File(p.join(dir.path, 'gone.jpg'))..writeAsBytesSync([1]);
      final photo = File(p.join(files.root.path, 'p.jpg'))
        ..writeAsBytesSync([1]);
      final kept = await store.save(
        request(
          attachment: SaveAttachment.file(
            type: 'image',
            extension: 'jpg',
            path: photo.path,
          ),
        ),
      );
      expect(await store.cleanupOrphanAttachments(), 1);
      expect(orphan.existsSync(), isFalse);
      expect(File(kept.item!.attachmentPath!).existsSync(), isTrue);
    });

    test('a missing source file still saves the text', () async {
      final out = await store.save(
        request(
          attachment: const SaveAttachment.file(
            type: 'image',
            extension: 'jpg',
            path: 'Z:/does/not/exist.jpg',
          ),
        ),
      );
      expect(out.kind, SaveOutcomeKind.created);
      expect(out.item!.attachmentPath, isNull);
    });
  });

  group('merging server pages', () {
    RemoteSavedText remote(
      String id, {
      int revision = 1,
      bool deleted = false,
      String text = 'Од сервер',
      int tick = 1,
    }) => RemoteSavedText(
      id: id,
      deleted: deleted,
      revision: revision,
      title: 'Наслов',
      source: 'listen',
      originalText: deleted ? '' : text,
      simplifiedText: null,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 2),
      cursor: RemoteCursor(tick, 0, id),
    );

    test('adds new items and stores the cursor in the same step', () async {
      final id = SavedTextIds.generate();
      await store.applyRemotePage(
        RemotePage([remote(id)], RemoteCursor(1, 0, id)),
      );
      expect((await store.get(id))!.syncState, SavedTextSyncState.synced);
      expect(await store.readCursor(), RemoteCursor(1, 0, id));
    });

    test('never overwrites unsent local edits', () async {
      final req = request(original: 'Локална измена');
      await store.save(req);
      await store.applyRemotePage(
        RemotePage([remote(req.id, revision: 5)], null),
      );
      final item = (await store.get(req.id))!;
      expect(item.originalText, 'Локална измена');
      expect(item.syncState, SavedTextSyncState.pending);
      // The next upload starts above the server revision.
      final commit = (await store.beginUpload(
        (await store.pendingChanges()).single,
      ))!;
      expect(commit.knownRevision, 5);
    });

    test('updates clean items only from a newer revision', () async {
      final id = SavedTextIds.generate();
      await store.applyRemotePage(RemotePage([remote(id, revision: 2)], null));
      await store.applyRemotePage(
        RemotePage([remote(id, revision: 1, text: 'Старо')], null),
      );
      expect((await store.get(id))!.originalText, 'Од сервер');
      await store.applyRemotePage(
        RemotePage([remote(id, revision: 3, text: 'Ново')], null),
      );
      expect((await store.get(id))!.originalText, 'Ново');
    });

    test('a server deletion wins over a local pending edit', () async {
      final req = request();
      await store.save(req);
      await store.applyRemotePage(
        RemotePage([remote(req.id, revision: 2, deleted: true)], null),
      );
      expect(await store.get(req.id), isNull);
      expect(await store.pendingChanges(), isEmpty);
      expect((await store.save(req)).kind, SaveOutcomeKind.deleted);
    });
  });

  group('favourites', () {
    test('starring queues an upload that carries the star', () async {
      final req = request();
      await store.save(req);
      await store.acknowledge((await store.pendingChanges()).single, 1);
      expect(await store.pendingChanges(), isEmpty);

      expect(await store.setFavorite(req.id, true), isTrue);
      expect(await store.setFavorite(req.id, true), isFalse);
      expect((await store.get(req.id))!.isFavorite, isTrue);
      final change = (await store.pendingChanges()).single;
      expect(change.op, 'upsert');
      final commit = (await store.beginUpload(change))!;
      expect(commit.favorite, isTrue);
      expect(commit.knownRevision, 1);
    });

    test('saving the same text again keeps the star', () async {
      final req = request();
      await store.save(req);
      await store.setFavorite(req.id, true);
      expect((await store.save(req)).kind, SaveOutcomeKind.unchanged);
      final edited = await store.save(
        SaveTextRequest(
          id: req.id,
          title: req.title,
          source: req.source,
          originalText: 'Изменет текст.',
          simplifiedText: null,
        ),
      );
      expect(edited.kind, SaveOutcomeKind.updated);
      expect(edited.item!.isFavorite, isTrue);
    });

    test('device-only items can be starred but stay on the device', () async {
      final big = 'а' * (SavedTextLimits.maxTextBytes ~/ 2 + 1);
      final out = await store.save(request(original: big));
      expect(await store.setFavorite(out.item!.id, true), isTrue);
      expect(await store.pendingChanges(), isEmpty);
      expect(
        (await store.get(out.item!.id))!.syncState,
        SavedTextSyncState.deviceOnly,
      );
    });

    test('deleted items cannot be starred', () async {
      final req = request();
      await store.save(req);
      await store.delete(req.id);
      expect(await store.setFavorite(req.id, true), isFalse);
    });

    test('the favourites sort lists starred items first', () async {
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        ids.add((await store.save(request(title: 'Т$i'))).item!.id);
      }
      await store.setFavorite(ids[0], true);
      final page = await store.listPage(sort: HistorySort.favorites);
      expect(page.first.id, ids[0]);
      expect(page.first.isFavorite, isTrue);
      expect(page.skip(1).map((e) => e.isFavorite), everyElement(isFalse));
    });

    test('stars arrive from the server only on clean items', () async {
      final id = SavedTextIds.generate();
      RemoteSavedText doc(int revision, bool favorite) => RemoteSavedText(
        id: id,
        deleted: false,
        revision: revision,
        title: 'Наслов',
        source: 'listen',
        originalText: 'Текст',
        simplifiedText: null,
        favorite: favorite,
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 2),
        cursor: RemoteCursor(revision, 0, id),
      );
      await store.applyRemotePage(RemotePage([doc(1, true)], null));
      expect((await store.get(id))!.isFavorite, isTrue);
      await store.applyRemotePage(RemotePage([doc(2, false)], null));
      expect((await store.get(id))!.isFavorite, isFalse);
      // A local unsent star is not overwritten by an older-looking server.
      await store.setFavorite(id, true);
      await store.applyRemotePage(RemotePage([doc(3, false)], null));
      expect((await store.get(id))!.isFavorite, isTrue);
    });
  });

  group('delete all', () {
    test('tombstones every item in one step, offline', () async {
      final uploaded = request(title: 'Во облак');
      final local = request(title: 'Само локално');
      await store.save(uploaded);
      await store.save(local);
      final change = (await store.pendingChanges()).firstWhere(
        (c) => c.id == uploaded.id,
      );
      await store.beginUpload(change);
      await store.setFavorite(uploaded.id, true);

      expect(await store.deleteAll(), 2);
      expect(await store.listPage(), isEmpty);
      expect(await store.liveCount(), 0);
      final pending = await store.pendingChanges();
      // Only the item that may be on the server needs a cloud tombstone.
      expect(pending.map((c) => (c.id, c.op)), [(uploaded.id, 'delete')]);
      final commit = (await store.beginUpload(pending.single))!;
      expect(commit.delete, isTrue);
      expect(commit.favorite, isFalse);
      expect(commit.originalText, isEmpty);
      for (final req in [uploaded, local]) {
        expect((await store.save(req)).kind, SaveOutcomeKind.deleted);
      }
      expect(await store.deleteAll(), 0);
    });

    test('removes owned attachments after the delete is stored', () async {
      final photo = File(p.join(files.root.path, 'p.jpg'))
        ..writeAsBytesSync([1]);
      final out = await store.save(
        request(
          attachment: SaveAttachment.file(
            type: 'image',
            extension: 'jpg',
            path: photo.path,
          ),
        ),
      );
      final copy = out.item!.attachmentPath!;
      await store.deleteAll();
      expect(File(copy).existsSync(), isFalse);
      expect(photo.existsSync(), isTrue);
    });

    test('a later server version cannot revive a deleted item', () async {
      final req = request();
      await store.save(req);
      await store.deleteAll();
      await store.applyRemotePage(
        RemotePage([
          RemoteSavedText(
            id: req.id,
            deleted: false,
            revision: 9,
            title: 'Стар уред',
            source: 'listen',
            originalText: 'Стара измена',
            simplifiedText: null,
            createdAt: DateTime(2026, 5, 1),
            updatedAt: DateTime(2026, 5, 2),
            cursor: RemoteCursor(9, 0, req.id),
          ),
        ], null),
      );
      expect(await store.get(req.id), isNull);
      expect(await store.liveCount(), 0);
    });
  });

  group('listing', () {
    test('pages, sorts and searches by title', () async {
      for (var i = 0; i < 5; i++) {
        await store.save(request(title: 'Наслов $i'));
      }
      await store.save(request(title: '100% сигурно_да'));
      final firstPage = await store.listPage(limit: 4);
      final secondPage = await store.listPage(limit: 4, offset: 4);
      expect(firstPage, hasLength(4));
      expect(secondPage, hasLength(2));
      expect({
        ...firstPage.map((e) => e.id),
        ...secondPage.map((e) => e.id),
      }, hasLength(6));
      expect(await store.listPage(search: '%'), hasLength(1));
      expect(await store.listPage(search: '_'), hasLength(1));
      expect(await store.listPage(search: 'Наслов'), hasLength(5));
      final byTitle = await store.listPage(sort: HistorySort.title);
      expect(byTitle.first.title, '100% сигурно_да');
    });
  });
}
