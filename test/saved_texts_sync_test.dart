import 'dart:async';
import 'dart:io';

import 'package:dyslexia_app/features/history/history_database.dart';
import 'package:dyslexia_app/features/history/saved_text.dart';
import 'package:dyslexia_app/features/history/saved_texts_controller.dart';
import 'package:dyslexia_app/features/history/saved_texts_local_store.dart';
import 'package:dyslexia_app/features/history/saved_texts_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfiNoIsolate;

import 'helpers/saved_texts_fakes.dart';

void main() {
  final files = TempHistoryFiles();
  late FakeTextsServer server;
  String? authUid;
  final controllers = <SavedTextsController>[];
  final otherDatabases = <Database>[];

  setUp(() {
    files.setUp();
    server = FakeTextsServer();
    authUid = null;
  });

  tearDown(() async {
    for (final c in controllers) {
      c.dispose();
    }
    controllers.clear();
    for (final db in otherDatabases) {
      await db.close();
    }
    otherDatabases.clear();
    await files.tearDown();
  });

  /// Storage of a second physical device: its own database files.
  Future<Database> Function(String uid) otherDevice(String name) {
    final open = <String, Future<Database>>{};
    return (uid) => open[uid] ??= () async {
      final dir = Directory(p.join(files.root.path, name))
        ..createSync(recursive: true);
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        p.join(dir.path, HistoryDatabase.fileNameFor(uid)),
        options: HistoryDatabase.openOptions(singleInstance: false),
      );
      otherDatabases.add(db);
      return db;
    }();
  }

  SavedTextsController device(
    FakeSavedTextsRemote remote, {
    Future<Database> Function(String uid)? openDatabase,
  }) {
    final controller = SavedTextsController(
      remote: remote,
      currentUid: () => authUid,
      openDatabase: openDatabase,
      documentsDir: () async => files.docsDir,
      extractLegacyText: (_, _) async => null,
      // Automatic retries are driven explicitly in these tests.
      retryBase: const Duration(hours: 1),
      observeLifecycle: false,
    );
    controllers.add(controller);
    return controller;
  }

  Future<SaveOutcome> save(
    SavedTextsController c, {
    String? id,
    String text = 'Мама и тато читаат.',
    String? simplified,
  }) => c.save(
    SaveTextRequest(
      id: id ?? SavedTextIds.generate(),
      title: null,
      source: SavedTextSource.listen,
      originalText: text,
      simplifiedText: simplified,
    ),
  );

  Future<void> signIn(SavedTextsController c, String uid) async {
    authUid = uid;
    await c.switchUser(uid);
    await settle(c);
  }

  test(
    'a save is confirmed for the account only after the server answers',
    () async {
      final remote = FakeSavedTextsRemote(server);
      final c = device(remote);
      await signIn(c, 'alice');

      final out = await save(c, simplified: 'Кратко.');
      expect(out.item!.syncState, SavedTextSyncState.pending);
      expect(c.stateOf(out.item!.id), SavedTextSyncState.pending);

      await settle(c);
      expect(c.stateOf(out.item!.id), SavedTextSyncState.synced);
      final doc = server.doc('alice', out.item!.id)!;
      expect(doc['originalText'], 'Мама и тато читаат.');
      expect(doc['simplifiedText'], 'Кратко.');
      expect(doc['revision'], 1);
      expect(remote.commitUids, everyElement('alice'));
      expect(c.syncStatus, SavedTextsSyncStatus.idle);
    },
  );

  test(
    'offline save survives a restart and is sent after reconnecting',
    () async {
      final remote = FakeSavedTextsRemote(server, online: false);
      final first = device(remote);
      await signIn(first, 'alice');
      final out = await save(first);
      await settle(first);
      expect(first.stateOf(out.item!.id), SavedTextSyncState.pending);
      expect(first.syncStatus, SavedTextsSyncStatus.waitingForNetwork);
      expect(server.docsOf('alice'), isEmpty);

      // The process ends; a new one starts while still offline.
      first.dispose();
      controllers.remove(first);
      await files.restart();
      final second = device(remote);
      await signIn(second, 'alice');
      expect(second.items.single.id, out.item!.id);
      expect(second.items.single.syncState, SavedTextSyncState.pending);

      remote.online = true;
      await second.retrySync();
      await settle(second);
      expect(second.items.single.syncState, SavedTextSyncState.synced);
      expect(server.docsOf('alice').keys, [out.item!.id]);
    },
  );

  test('a lost server answer is retried without a duplicate', () async {
    final remote = FakeSavedTextsRemote(server)..loseResponses = 1;
    final c = device(remote);
    await signIn(c, 'alice');
    final out = await save(c);
    await settle(c);
    // Committed on the server, but this device does not know yet.
    expect(server.docsOf('alice'), hasLength(1));
    expect(c.stateOf(out.item!.id), SavedTextSyncState.pending);

    await c.retrySync();
    await settle(c);
    expect(server.docsOf('alice'), hasLength(1));
    expect(server.doc('alice', out.item!.id)!['revision'], 2);
    expect(c.stateOf(out.item!.id), SavedTextSyncState.synced);
  });

  test('repeated saves of the same item upload it once', () async {
    final remote = FakeSavedTextsRemote(server);
    final c = device(remote);
    await signIn(c, 'alice');
    final id = SavedTextIds.generate();
    await Future.wait([save(c, id: id), save(c, id: id), save(c, id: id)]);
    await settle(c);
    expect(server.docsOf('alice'), hasLength(1));
    expect(remote.commitUids, hasLength(1));
    expect(c.items, hasLength(1));
  });

  test('an edit made during an upload stays queued', () async {
    final remote = FakeSavedTextsRemote(server);
    final c = device(remote);
    await signIn(c, 'alice');
    final id = SavedTextIds.generate();
    final first = save(c, id: id, text: 'Прва');
    final second = save(c, id: id, text: 'Втора');
    await Future.wait([first, second]);
    await settle(c);
    expect(server.doc('alice', id)!['originalText'], 'Втора');
    expect(c.stateOf(id), SavedTextSyncState.synced);
  });

  test('deleting uploads a tombstone and the item never returns', () async {
    final remote = FakeSavedTextsRemote(server);
    final c = device(remote);
    await signIn(c, 'alice');
    final out = await save(c);
    await settle(c);
    expect(await c.delete(out.item!.id), isTrue);
    await settle(c);
    expect(server.doc('alice', out.item!.id)!['deleted'], true);
    expect(c.items, isEmpty);
    await c.refresh();
    await settle(c);
    expect(c.items, isEmpty);
  });

  test('a stale offline device cannot resurrect a deleted item', () async {
    final remoteA = FakeSavedTextsRemote(server);
    final remoteB = FakeSavedTextsRemote(server);
    final deviceA = device(remoteA);
    await signIn(deviceA, 'alice');
    final out = await save(deviceA, text: 'Заеднички текст');
    await settle(deviceA);

    // Device B pulls the item, then goes offline and edits it.
    final deviceB = device(remoteB, openDatabase: otherDevice('b'));
    await deviceB.switchUser('alice');
    await settle(deviceB);
    expect(deviceB.items.single.id, out.item!.id);
    remoteB.online = false;
    await save(deviceB, id: out.item!.id, text: 'Стара измена од B');
    await settle(deviceB);

    // Device A deletes it.
    await deviceA.delete(out.item!.id);
    await settle(deviceA);

    // B reconnects and retries its pending edit.
    remoteB.online = true;
    await deviceB.retrySync();
    await settle(deviceB);
    expect(server.doc('alice', out.item!.id)!['deleted'], true);
    expect(deviceB.items, isEmpty);
    expect(await deviceB.load(out.item!.id), isNull);
  });

  group('favourites', () {
    test('a star syncs to the other devices of the account', () async {
      final deviceA = device(FakeSavedTextsRemote(server));
      await signIn(deviceA, 'alice');
      final out = await save(deviceA);
      await settle(deviceA);
      final deviceB = device(
        FakeSavedTextsRemote(server),
        openDatabase: otherDevice('b'),
      );
      await deviceB.switchUser('alice');
      await settle(deviceB);
      expect(deviceB.items.single.isFavorite, isFalse);

      expect(await deviceA.toggleFavorite(out.item!.id), isTrue);
      expect(deviceA.items.single.isFavorite, isTrue);
      await settle(deviceA);
      expect(server.doc('alice', out.item!.id)!['favorite'], true);
      expect(deviceA.stateOf(out.item!.id), SavedTextSyncState.synced);

      await deviceB.refresh();
      await settle(deviceB);
      expect(deviceB.items.single.isFavorite, isTrue);

      await deviceB.toggleFavorite(out.item!.id);
      await settle(deviceB);
      await deviceA.refresh();
      await settle(deviceA);
      expect(deviceA.items.single.isFavorite, isFalse);
      expect(server.doc('alice', out.item!.id)!['revision'], 3);
    });

    test('an offline star is kept and sent later', () async {
      final remote = FakeSavedTextsRemote(server);
      final c = device(remote);
      await signIn(c, 'alice');
      final out = await save(c);
      await settle(c);
      remote.online = false;
      await c.toggleFavorite(out.item!.id);
      await settle(c);
      expect(c.items.single.isFavorite, isTrue);
      expect(c.stateOf(out.item!.id), SavedTextSyncState.pending);
      expect(server.doc('alice', out.item!.id)!['favorite'], false);

      remote.online = true;
      await c.retrySync();
      await settle(c);
      expect(server.doc('alice', out.item!.id)!['favorite'], true);
    });
  });

  group('delete all', () {
    test(
      'works offline, survives a restart and reaches the server later',
      () async {
        final remote = FakeSavedTextsRemote(server);
        final first = device(remote);
        await signIn(first, 'alice');
        final a = await save(first, text: 'Прв');
        final b = await save(first, text: 'Втор');
        await settle(first);
        remote.online = false;
        // Its upload was attempted while offline, so it may have reached
        // the server and also gets a cloud tombstone.
        final offline = await save(first, text: 'Сочуван без интернет');
        await settle(first);

        expect(await first.deleteAll(uid: 'alice'), 3);
        expect(first.items, isEmpty);
        expect(first.totalCount, 0);
        expect(server.doc('alice', a.item!.id)!['deleted'], false);

        first.dispose();
        controllers.remove(first);
        await files.restart();
        final second = device(remote);
        await signIn(second, 'alice');
        expect(second.items, isEmpty);
        expect(second.counts.pending, 3);

        remote.online = true;
        await second.retrySync();
        await settle(second);
        for (final out in [a, b, offline]) {
          expect(server.doc('alice', out.item!.id)!['deleted'], true);
        }
        expect(second.counts.pending, 0);
        await second.refresh();
        await settle(second);
        expect(second.items, isEmpty);
      },
    );

    test('also deletes items it first learns about from the server', () async {
      final deviceB = device(
        FakeSavedTextsRemote(server),
        openDatabase: otherDevice('b'),
      );
      await signIn(deviceB, 'alice');
      final deviceA = device(FakeSavedTextsRemote(server));
      await deviceA.switchUser('alice');
      await settle(deviceA);
      final fromB = await save(deviceB, text: 'Од уред B');
      await settle(deviceB);
      expect(deviceA.items, isEmpty, reason: 'A has not pulled yet');

      expect(await deviceA.deleteAll(uid: 'alice'), 1);
      await settle(deviceA);
      expect(server.doc('alice', fromB.item!.id)!['deleted'], true);
      await deviceB.refresh();
      await settle(deviceB);
      expect(deviceB.items, isEmpty);
    });

    test('a stale offline device cannot restore deleted items', () async {
      final remoteA = FakeSavedTextsRemote(server);
      final remoteB = FakeSavedTextsRemote(server);
      final deviceA = device(remoteA);
      await signIn(deviceA, 'alice');
      final one = await save(deviceA, text: 'Еден');
      final two = await save(deviceA, text: 'Два');
      await settle(deviceA);
      final deviceB = device(remoteB, openDatabase: otherDevice('b'));
      await deviceB.switchUser('alice');
      await settle(deviceB);
      expect(deviceB.items, hasLength(2));

      remoteB.online = false;
      await save(deviceB, id: one.item!.id, text: 'Стара измена');
      await deviceB.toggleFavorite(two.item!.id);
      await settle(deviceB);

      await deviceA.deleteAll(uid: 'alice');
      await settle(deviceA);

      remoteB.online = true;
      await deviceB.retrySync();
      await settle(deviceB);
      for (final id in [one.item!.id, two.item!.id]) {
        expect(server.doc('alice', id)!['deleted'], true);
        expect(await deviceB.load(id), isNull);
      }
      expect(deviceB.items, isEmpty);
      expect(deviceB.counts.pending, 0);
      await deviceA.refresh();
      await settle(deviceA);
      expect(deviceA.items, isEmpty);
    });

    test('stays with the account it was confirmed for', () async {
      final remote = FakeSavedTextsRemote(server);
      final c = device(remote);
      await signIn(c, 'bob');
      final bobText = await save(c, text: 'Боб');
      await settle(c);
      await signIn(c, 'alice');
      final aliceText = await save(c, text: 'Алиса');
      await settle(c);

      // Offline delete-all for Alice, then Bob signs in.
      remote.online = false;
      expect(await c.deleteAll(uid: 'alice'), 1);
      // A dialog confirmed for Alice cannot act on Bob's session.
      await signIn(c, 'bob');
      expect(await c.deleteAll(uid: 'alice'), isNull);
      expect(c.items.map((e) => e.id), [bobText.item!.id]);

      remote.online = true;
      remote.commitUids.clear();
      await c.retrySync();
      await settle(c);
      expect(server.doc('bob', bobText.item!.id)!['deleted'], false);
      expect(server.doc('alice', aliceText.item!.id)!['deleted'], false);
      expect(remote.commitUids, isNot(contains('alice')));

      await signIn(c, 'alice');
      await settle(c);
      expect(server.doc('alice', aliceText.item!.id)!['deleted'], true);
      expect(server.doc('bob', bobText.item!.id)!['deleted'], false);
      expect(c.items, isEmpty);
    });
  });

  test('deletions from another device arrive with the next pull', () async {
    final c = device(FakeSavedTextsRemote(server));
    await signIn(c, 'alice');
    final out = await save(c);
    await settle(c);
    // Another device deletes it.
    server.commit(
      'alice',
      RemoteCommit(
        id: out.item!.id,
        delete: true,
        title: '',
        source: 'listen',
        originalText: '',
        simplifiedText: null,
        createdAt: DateTime(2026, 5, 1),
        knownRevision: 1,
      ),
    );
    await c.refresh();
    await settle(c);
    expect(c.items, isEmpty);
  });

  test('pulls in bounded pages without snapshot listeners', () async {
    for (var i = 0; i < 120; i++) {
      server.put('alice', 'Remote${i.toString().padLeft(6, '0')}', {
        'title': 'Текст $i',
      });
    }
    final remote = FakeSavedTextsRemote(server);
    final c = device(remote);
    await signIn(c, 'alice');
    expect(remote.fetchUids, hasLength(3));
    expect(c.items, hasLength(SavedTextLimits.localPageSize));
    expect(c.hasMore, isTrue);
    await c.loadMore();
    expect(c.items, hasLength(SavedTextLimits.localPageSize * 2));

    // The next pull starts after the stored cursor.
    remote.fetchUids.clear();
    await c.refresh();
    await settle(c);
    expect(remote.fetchUids, hasLength(1));
  });

  test(
    'rejected uploads are marked failed and wait for a manual retry',
    () async {
      final remote = FakeSavedTextsRemote(server)..deny = true;
      final c = device(remote);
      await signIn(c, 'alice');
      final out = await save(c);
      await settle(c);
      expect(c.stateOf(out.item!.id), SavedTextSyncState.failed);
      expect(c.syncStatus, SavedTextsSyncStatus.failed);

      remote.commitUids.clear();
      await save(c, text: 'Друг текст');
      await settle(c);
      // Only the new item was attempted; the rejected one waits.
      expect(remote.commitUids, hasLength(1));

      remote.deny = false;
      await c.retrySync();
      await settle(c);
      expect(c.stateOf(out.item!.id), SavedTextSyncState.synced);
      expect(server.docsOf('alice'), hasLength(2));
    },
  );

  group('accounts', () {
    test('offline A → B → A keeps A\'s pending text with A only', () async {
      final remote = FakeSavedTextsRemote(server, online: false);
      final c = device(remote);
      await signIn(c, 'alice');
      final aliceText = await save(c, text: 'Текст од Алиса');
      await settle(c);

      authUid = 'bob';
      final switching = c.switchUser('bob');
      // The previous account's History is cleared at once.
      expect(c.items, isEmpty);
      expect(c.uid, 'bob');
      await switching;
      await settle(c);
      expect(c.items, isEmpty);
      final bobText = await save(c, text: 'Текст од Боб');
      await settle(c);
      expect(c.items.map((e) => e.id), [bobText.item!.id]);

      remote.commitUids.clear();
      remote.online = true;
      await c.retrySync();
      await settle(c);
      expect(server.docsOf('bob').keys, [bobText.item!.id]);
      expect(server.docsOf('alice'), isEmpty);

      await signIn(c, 'alice');
      expect(c.items.map((e) => e.id), [aliceText.item!.id]);
      await settle(c);
      expect(server.docsOf('alice').keys, [aliceText.item!.id]);
      expect(server.docsOf('bob').keys, [bobText.item!.id]);
      expect(remote.commitUids, [
        'bob',
        'alice',
      ], reason: 'each upload went to the account that saved it');
    });

    test(
      'nothing is sent while auth already belongs to another account',
      () async {
        final remote = FakeSavedTextsRemote(server, online: false);
        final c = device(remote);
        await signIn(c, 'alice');
        await save(c);
        await settle(c);

        remote.online = true;
        authUid = 'bob'; // signed in as Bob, session not switched yet
        await c.retrySync();
        await settle(c);
        expect(remote.commitUids.where((u) => u == 'alice'), hasLength(1));
        expect(server.docsOf('alice'), isEmpty);
        expect(server.docsOf('bob'), isEmpty);
      },
    );

    test('a slow database open for A cannot show A\'s texts to B', () async {
      final remote = FakeSavedTextsRemote(server);
      final setup = device(remote);
      await signIn(setup, 'alice');
      await save(setup, text: 'Само за Алиса');
      await settle(setup);

      final gate = Completer<void>();
      final c = device(
        remote,
        openDatabase: (uid) async {
          if (uid == 'alice') await gate.future;
          return HistoryDatabase.forUid(uid);
        },
      );
      authUid = 'alice';
      final staleSwitch = c.switchUser('alice');
      authUid = 'bob';
      await c.switchUser('bob');
      gate.complete();
      await staleSwitch;
      await settle(c);
      expect(c.uid, 'bob');
      expect(c.items, isEmpty);
    });

    test('a pull answer for a closed session is dropped', () async {
      server.put('alice', 'AliceRemote01', {'originalText': 'Од облак'});
      final remote = FakeSavedTextsRemote(server)..fetchGate = Completer();
      final c = device(remote);
      authUid = 'alice';
      await c.switchUser('alice');
      await pumpEventQueue();
      expect(remote.fetchUids, ['alice']);

      authUid = 'bob';
      final gate = remote.fetchGate!;
      remote.fetchGate = null;
      await c.switchUser('bob');
      gate.complete();
      await settle(c);
      expect(c.items, isEmpty);

      // Alice's own database did not take the stale page either; it is
      // fetched again on her next sign-in.
      final aliceDb = await HistoryDatabase.forUid('alice');
      final rows = await aliceDb.query(HistoryDatabase.textsTable);
      expect(rows, isEmpty);
      await signIn(c, 'alice');
      expect(c.items.single.id, 'AliceRemote01');
    });
  });
}
