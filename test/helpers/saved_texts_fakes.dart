import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dyslexia_app/features/history/history_database.dart';
import 'package:dyslexia_app/features/history/saved_texts_controller.dart';
import 'package:dyslexia_app/features/history/saved_texts_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// One Firestore project shared by several fake devices. Applies the same
/// checks as firestore.rules: tombstones are final, revisions increase,
/// createdAt and source never change.
class FakeTextsServer {
  final Map<String, Map<String, Map<String, Object?>>> _docs = {};
  int _tick = 0;

  Map<String, Map<String, Object?>> docsOf(String uid) =>
      Map.unmodifiable(_docs[uid] ?? const {});

  Map<String, Object?>? doc(String uid, String id) => _docs[uid]?[id];

  RemoteCommitResult commit(String uid, RemoteCommit change) {
    final docs = _docs.putIfAbsent(uid, () => {});
    final current = docs[change.id];
    final serverRevision = (current?['revision'] as int?) ?? 0;
    if (current != null && current['deleted'] == true) {
      return RemoteCommitResult(revision: serverRevision, alreadyDeleted: true);
    }
    final revision = max(serverRevision, change.knownRevision) + 1;
    final createdAt = current?['createdAt'] ?? change.createdAt;
    final tick = ++_tick;
    docs[change.id] = change.delete
        ? {
            'deleted': true,
            'revision': revision,
            'createdAt': createdAt,
            'tick': tick,
          }
        : {
            'deleted': false,
            'revision': revision,
            'title': change.title,
            'source': current?['source'] ?? change.source,
            'originalText': change.originalText,
            'simplifiedText': change.simplifiedText,
            'favorite': change.favorite,
            'createdAt': createdAt,
            'tick': tick,
          };
    return RemoteCommitResult(revision: revision);
  }

  /// Writes as another device would, bypassing the fake remote.
  void put(String uid, String id, Map<String, Object?> fields) {
    final docs = _docs.putIfAbsent(uid, () => {});
    docs[id] = {
      'deleted': false,
      'revision': 1,
      'title': 'Наслов',
      'source': 'listen',
      'originalText': 'Текст',
      'simplifiedText': null,
      'createdAt': DateTime(2026, 5, 1),
      ...?docs[id],
      ...fields,
      'tick': ++_tick,
    };
  }

  RemotePage fetch(String uid, RemoteCursor? after, int limit) {
    final entries = (_docs[uid] ?? const {}).entries.toList()
      ..sort((a, b) {
        final byTick = (a.value['tick'] as int).compareTo(
          b.value['tick'] as int,
        );
        return byTick != 0 ? byTick : a.key.compareTo(b.key);
      });
    final page = entries
        .where((e) {
          if (after == null) return true;
          final tick = e.value['tick'] as int;
          return tick > after.seconds ||
              (tick == after.seconds && e.key.compareTo(after.id) > 0);
        })
        .take(limit)
        .toList();
    final items = [
      for (final e in page)
        RemoteSavedText(
          id: e.key,
          deleted: e.value['deleted'] == true,
          revision: e.value['revision'] as int,
          title: (e.value['title'] as String?) ?? '',
          source: (e.value['source'] as String?) ?? 'legacy',
          originalText: (e.value['originalText'] as String?) ?? '',
          simplifiedText: e.value['simplifiedText'] as String?,
          favorite: e.value['favorite'] == true,
          createdAt: e.value['createdAt'] as DateTime,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (e.value['tick'] as int) * 1000,
          ),
          cursor: RemoteCursor(e.value['tick'] as int, 0, e.key),
        ),
    ];
    return RemotePage(items, items.isEmpty ? null : items.last.cursor);
  }
}

/// One device's connection to [FakeTextsServer].
class FakeSavedTextsRemote implements SavedTextsRemoteStore {
  final FakeTextsServer server;
  bool online;
  bool deny = false;

  /// The next N commits reach the server but the answer is lost.
  int loseResponses = 0;

  /// When set, fetches wait for it before answering.
  Completer<void>? fetchGate;

  final List<String> commitUids = [];
  final List<String> fetchUids = [];

  FakeSavedTextsRemote(this.server, {this.online = true});

  static const _offline = SavedTextsRemoteException(
    SavedTextsRemoteErrorKind.offline,
    'unavailable',
  );

  @override
  Future<RemoteCommitResult> commit(String uid, RemoteCommit change) async {
    commitUids.add(uid);
    if (!online) throw _offline;
    if (deny) {
      throw const SavedTextsRemoteException(
        SavedTextsRemoteErrorKind.denied,
        'permission-denied',
      );
    }
    final result = server.commit(uid, change);
    if (loseResponses > 0) {
      loseResponses--;
      throw _offline;
    }
    return result;
  }

  @override
  Future<RemotePage> fetchChanges(
    String uid,
    RemoteCursor? after,
    int limit,
  ) async {
    fetchUids.add(uid);
    final gate = fetchGate;
    if (gate != null) await gate.future;
    if (!online) throw _offline;
    return server.fetch(uid, after, limit);
  }
}

/// Real SQLite files in a temp folder, so restarts can be simulated.
class TempHistoryFiles {
  late Directory root;

  String get dbDir => '${root.path}${Platform.pathSeparator}db';
  String get docsDir => '${root.path}${Platform.pathSeparator}docs';

  void setUp() {
    sqfliteFfiInit();
    root = Directory.systemTemp.createTempSync('chitaj_history_test');
    Directory(dbDir).createSync();
    Directory(docsDir).createSync();
    HistoryDatabase.factoryOverride = databaseFactoryFfiNoIsolate;
    HistoryDatabase.directoryOverride = dbDir;
  }

  Future<void> tearDown() async {
    await HistoryDatabase.closeAll();
    HistoryDatabase.factoryOverride = null;
    HistoryDatabase.directoryOverride = null;
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  }

  /// Closes every database, like the app process ending.
  Future<void> restart() => HistoryDatabase.closeAll();
}

/// In-memory databases for widget tests (no real file I/O under fake async).
class MemoryHistoryDatabases {
  final Map<String, Database> _open = {};

  Future<Database> open(String uid) async {
    sqfliteFfiInit();
    return _open[uid] ??= await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: HistoryDatabase.openOptions(singleInstance: false),
    );
  }

  Future<void> closeAll() async {
    for (final db in _open.values) {
      await db.close();
    }
    _open.clear();
  }
}

/// Waits until the controller has no sync pass running.
Future<void> settle(SavedTextsController controller) async {
  for (var i = 0; i < 200; i++) {
    await pumpEventQueue();
    if (!controller.isSyncing) {
      await pumpEventQueue();
      if (!controller.isSyncing) return;
    }
  }
  fail('sync did not finish');
}
