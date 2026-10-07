import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'history_database.dart';
import 'legacy_history_migration.dart';
import 'saved_text.dart';
import 'saved_texts_remote.dart';

enum SaveOutcomeKind {
  created,
  updated,

  /// The item already holds exactly this content; nothing was written.
  unchanged,

  /// The item was deleted (here or on another device).
  deleted,
  emptyText,
  titleTooLong,

  /// No signed-in account or the account's storage could not be opened.
  unavailable,
}

class SaveOutcome {
  final SaveOutcomeKind kind;
  final SavedText? item;

  const SaveOutcome(this.kind, [this.item]);

  bool get stored =>
      kind == SaveOutcomeKind.created ||
      kind == SaveOutcomeKind.updated ||
      kind == SaveOutcomeKind.unchanged;
}

enum HistorySort { newest, oldest, title, favorites }

/// Values stored in `saved_texts.lastError`.
class SyncErrorCodes {
  SyncErrorCodes._();

  static const offline = 'offline';
  static const denied = 'denied';
  static const failed = 'failed';
}

/// A queued change, without the text body.
class PendingChange {
  final String id;
  final String op;
  final int localRevision;

  const PendingChange(this.id, this.op, this.localRevision);
}

class SyncCounts {
  final int pending;
  final int failed;
  final int deviceOnly;

  const SyncCounts({this.pending = 0, this.failed = 0, this.deviceOnly = 0});
}

/// Saved texts of one account in its own `history_<uid>.db`.
///
/// A row whose `pendingOp` is set is the durable queue entry for that item.
/// Content and queue entry are always written in one statement or
/// transaction, so a reported local save survives restarts.
class SavedTextsLocalStore {
  static const _upsert = 'upsert';
  static const _delete = 'delete';
  static const _cursorKey = 'pullCursor';
  static const tooLargeReason = 'tooLarge';

  final Database db;
  final String uid;

  /// App documents directory; owned attachments live in
  /// `<documents>/saved_texts_<uid>/`.
  final Future<String> Function() documentsDir;
  final DateTime Function() _now;

  SavedTextsLocalStore(
    this.db, {
    required this.uid,
    required this.documentsDir,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  static const String _table = HistoryDatabase.textsTable;

  Future<String> ownedAttachmentDir() async =>
      p.join(await documentsDir(), 'saved_texts_$uid');

  // ---------------------------------------------------------------- save

  Future<SaveOutcome> save(SaveTextRequest request) async {
    if (!SavedTextIds.isValid(request.id)) {
      throw ArgumentError.value(request.id, 'id', 'invalid text id');
    }
    final original = request.originalText;
    if (original.trim().isEmpty) {
      return const SaveOutcome(SaveOutcomeKind.emptyText);
    }
    final simplified = (request.simplifiedText?.trim().isEmpty ?? true)
        ? null
        : request.simplifiedText;
    final now = _now();
    final title = SavedTextTitles.resolve(request.title, original, now);
    if (title == null) return const SaveOutcome(SaveOutcomeKind.titleTooLong);
    final fits = SavedTextLimits.fitsCloud(original, simplified);

    final existing = await _row(request.id);
    String? attachmentPath;
    if (existing == null && request.attachment != null) {
      attachmentPath = await _storeAttachment(request.id, request.attachment!);
    }

    final outcome = await db.transaction((txn) async {
      final rows = await txn.query(
        _table,
        where: 'id = ?',
        whereArgs: [request.id],
      );
      if (rows.isEmpty) {
        await txn.insert(_table, {
          'id': request.id,
          'title': title,
          'source': request.source.name,
          'originalText': original,
          'simplifiedText': simplified,
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
          'deleted': 0,
          'localRevision': 1,
          'pendingOp': fits ? _upsert : null,
          'deviceOnlyReason': fits ? null : tooLargeReason,
          'attachmentPath': attachmentPath,
          'attachmentType': attachmentPath == null
              ? null
              : request.attachment!.type,
          'attachmentOwned': attachmentPath == null ? 0 : 1,
        });
        return SaveOutcomeKind.created;
      }
      final row = rows.single;
      if (row['deleted'] == 1) return SaveOutcomeKind.deleted;
      final sameContent =
          row['title'] == title &&
          row['originalText'] == original &&
          row['simplifiedText'] == simplified;
      if (sameContent) return SaveOutcomeKind.unchanged;
      await txn.rawUpdate(
        '''
        UPDATE $_table SET title = ?, originalText = ?, simplifiedText = ?,
          updatedAt = ?, localRevision = localRevision + 1,
          pendingOp = ?, deviceOnlyReason = ?, lastError = NULL
        WHERE id = ?
        ''',
        [
          title,
          original,
          simplified,
          now.millisecondsSinceEpoch,
          fits ? _upsert : null,
          fits ? null : tooLargeReason,
          request.id,
        ],
      );
      return SaveOutcomeKind.updated;
    });

    if (outcome != SaveOutcomeKind.created && attachmentPath != null) {
      await _deleteOwnedFile(attachmentPath);
    }
    if (outcome == SaveOutcomeKind.deleted) {
      return const SaveOutcome(SaveOutcomeKind.deleted);
    }
    return SaveOutcome(outcome, await get(request.id));
  }

  Future<String?> _storeAttachment(String id, SaveAttachment attachment) async {
    try {
      final dir = Directory(await ownedAttachmentDir());
      await dir.create(recursive: true);
      final ext = attachment.extension.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final dest = p.join(dir.path, ext.isEmpty ? id : '$id.$ext');
      if (attachment.bytes != null) {
        await File(dest).writeAsBytes(attachment.bytes!, flush: true);
      } else {
        await File(attachment.sourcePath!).copy(dest);
      }
      return dest;
    } catch (_) {
      // The text is what matters; an item without its photo is still useful.
      return null;
    }
  }

  // -------------------------------------------------------------- delete

  /// Deletes locally and keeps a content-free tombstone, so a retried save
  /// with the same id cannot bring the item back. A cloud delete is queued
  /// only if an upload of the item may have reached the server.
  Future<bool> delete(String id) async {
    final now = _now().millisecondsSinceEpoch;
    final (deleted, attachment) = await db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty || rows.single['deleted'] == 1) {
        return (false, null);
      }
      final row = rows.single;
      await txn.rawUpdate(
        '''
        UPDATE $_table SET deleted = 1, title = '', originalText = '',
          simplifiedText = NULL, favorite = 0, updatedAt = ?,
          localRevision = localRevision + 1, pendingOp = ?,
          deviceOnlyReason = NULL, lastError = NULL,
          attachmentPath = NULL, attachmentType = NULL, attachmentOwned = 0
        WHERE id = ?
        ''',
        [now, row['uploadAttempted'] == 1 ? _delete : null, id],
      );
      return (true, _OwnedFile.fromRow(row));
    });
    await attachment?.cleanup(this);
    return deleted;
  }

  /// «Избриши сè»: deletes every item of this account on this device in one
  /// transaction, with the same tombstones as [delete]. Unconverted legacy
  /// entries are hidden; their rows and files stay untouched.
  Future<int> deleteAll() async {
    final now = _now().millisecondsSinceEpoch;
    final (count, files) = await db.transaction((txn) async {
      final rows = await txn.query(
        _table,
        columns: ['attachmentPath', 'attachmentOwned'],
        where: 'deleted = 0',
      );
      await txn.rawUpdate(
        '''
        UPDATE $_table SET deleted = 1, title = '', originalText = '',
          simplifiedText = NULL, favorite = 0, updatedAt = ?,
          localRevision = localRevision + 1,
          pendingOp = CASE WHEN uploadAttempted = 1 THEN ? ELSE NULL END,
          deviceOnlyReason = NULL, lastError = NULL,
          attachmentPath = NULL, attachmentType = NULL, attachmentOwned = 0
        WHERE deleted = 0
        ''',
        [now, _delete],
      );
      await txn.update(
        HistoryDatabase.migrationTable,
        {'status': LegacyHistoryMigration.dismissed, 'updatedAt': now},
        where: 'status IN (?, ?)',
        whereArgs: [
          LegacyHistoryMigration.deviceOnly,
          LegacyHistoryMigration.attention,
        ],
      );
      // Rows the background migration has not reached yet must not become
      // new items after the user deleted everything.
      await txn.rawInsert(
        '''
        INSERT INTO ${HistoryDatabase.migrationTable}
          (legacyId, textId, status, reason, updatedAt)
        SELECT id, NULL, ?, 'deleteAll', ? FROM ${HistoryDatabase.legacyTable}
        WHERE id NOT IN (SELECT legacyId FROM ${HistoryDatabase.migrationTable})
        ''',
        [LegacyHistoryMigration.dismissed, now],
      );
      return (rows.length, rows.map(_OwnedFile.fromRow).nonNulls.toList());
    });
    for (final file in files) {
      await file.cleanup(this);
    }
    return count;
  }

  /// Stars or unstars an item. The change syncs like an edit; device-only
  /// items stay on this device.
  Future<bool> setFavorite(String id, bool favorite) async {
    final updated = await db.rawUpdate(
      '''
      UPDATE $_table SET favorite = ?, updatedAt = ?,
        localRevision = localRevision + 1,
        pendingOp = CASE WHEN deviceOnlyReason IS NULL THEN ? ELSE pendingOp END,
        lastError = NULL
      WHERE id = ? AND deleted = 0 AND favorite != ?
      ''',
      [
        favorite ? 1 : 0,
        _now().millisecondsSinceEpoch,
        _upsert,
        id,
        favorite ? 1 : 0,
      ],
    );
    return updated > 0;
  }

  Future<int> liveCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_table WHERE deleted = 0'),
      ) ??
      0;

  Future<void> _deleteOwnedFile(String path) async {
    final ownedDir = await ownedAttachmentDir();
    if (!p.isWithin(ownedDir, path)) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Removes files in the owned folder that no live item references,
  /// e.g. when the app stopped between a delete and its file cleanup.
  Future<int> cleanupOrphanAttachments() async {
    final dir = Directory(await ownedAttachmentDir());
    if (!await dir.exists()) return 0;
    final rows = await db.query(
      _table,
      columns: ['attachmentPath'],
      where: 'attachmentOwned = 1 AND attachmentPath IS NOT NULL',
    );
    final referenced = {
      for (final row in rows) p.normalize(row['attachmentPath'] as String),
    };
    var removed = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (referenced.contains(p.normalize(entity.path))) continue;
      try {
        await entity.delete();
        removed++;
      } catch (_) {}
    }
    return removed;
  }

  // --------------------------------------------------------------- reads

  Future<Map<String, Object?>?> _row(String id) async {
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.single;
  }

  Future<SavedText?> get(String id) async {
    final row = await _row(id);
    if (row == null || row['deleted'] == 1) return null;
    return _toSavedText(row);
  }

  Future<SavedTextSyncState?> syncStateOf(String id) async {
    final rows = await db.query(
      _table,
      columns: ['pendingOp', 'lastError', 'deviceOnlyReason', 'deleted'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty || rows.single['deleted'] == 1) return null;
    return syncStateFromRow(rows.single);
  }

  Future<List<SavedTextSummary>> listPage({
    String search = '',
    HistorySort sort = HistorySort.newest,
    int offset = 0,
    int limit = SavedTextLimits.localPageSize,
  }) async {
    final where = StringBuffer('deleted = 0');
    final args = <Object?>[];
    final query = search.trim();
    if (query.isNotEmpty) {
      where.write(r" AND title LIKE ? ESCAPE '\'");
      final escaped = query
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      args.add('%$escaped%');
    }
    final orderBy = switch (sort) {
      HistorySort.newest => 'createdAt DESC, id DESC',
      HistorySort.oldest => 'createdAt ASC, id ASC',
      HistorySort.title => 'title COLLATE NOCASE ASC, id ASC',
      HistorySort.favorites => 'favorite DESC, createdAt DESC, id DESC',
    };
    final rows = await db.rawQuery(
      '''
      SELECT id, title, source, substr(originalText, 1, 160) AS preview,
        simplifiedText IS NOT NULL AS hasSimplified, createdAt, pendingOp,
        lastError, deviceOnlyReason, attachmentPath, attachmentType, favorite
      FROM $_table WHERE $where ORDER BY $orderBy LIMIT ? OFFSET ?
      ''',
      [...args, limit, offset],
    );
    return [
      for (final row in rows)
        SavedTextSummary(
          id: row['id'] as String,
          title: row['title'] as String,
          source: savedTextSourceFrom(row['source'] as String?),
          preview: (row['preview'] as String).replaceAll(RegExp(r'\s+'), ' '),
          hasSimplified: row['hasSimplified'] == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['createdAt'] as int,
          ),
          syncState: syncStateFromRow(row),
          isFavorite: row['favorite'] == 1,
          attachmentPath: row['attachmentPath'] as String?,
          attachmentType: row['attachmentType'] as String?,
        ),
    ];
  }

  Future<SyncCounts> counts() async {
    final rows = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN pendingOp IS NOT NULL AND (lastError IS NULL
          OR lastError = '${SyncErrorCodes.offline}') THEN 1 ELSE 0 END) AS pending,
        SUM(CASE WHEN pendingOp IS NOT NULL AND lastError IN
          ('${SyncErrorCodes.denied}', '${SyncErrorCodes.failed}')
          THEN 1 ELSE 0 END) AS failed,
        SUM(CASE WHEN deleted = 0 AND deviceOnlyReason IS NOT NULL
          THEN 1 ELSE 0 END) AS deviceOnly
      FROM $_table
    ''');
    final row = rows.single;
    return SyncCounts(
      pending: (row['pending'] as int?) ?? 0,
      failed: (row['failed'] as int?) ?? 0,
      deviceOnly: (row['deviceOnly'] as int?) ?? 0,
    );
  }

  static SavedTextSyncState syncStateFromRow(Map<String, Object?> row) {
    if (row['deviceOnlyReason'] != null) return SavedTextSyncState.deviceOnly;
    if (row['pendingOp'] == null) return SavedTextSyncState.synced;
    final error = row['lastError'];
    if (error == SyncErrorCodes.denied || error == SyncErrorCodes.failed) {
      return SavedTextSyncState.failed;
    }
    return SavedTextSyncState.pending;
  }

  SavedText _toSavedText(Map<String, Object?> row) => SavedText(
    id: row['id'] as String,
    title: row['title'] as String,
    source: savedTextSourceFrom(row['source'] as String?),
    originalText: row['originalText'] as String,
    simplifiedText: row['simplifiedText'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updatedAt'] as int),
    syncState: syncStateFromRow(row),
    isFavorite: row['favorite'] == 1,
    attachmentPath: row['attachmentPath'] as String?,
    attachmentType: row['attachmentType'] as String?,
  );

  // ---------------------------------------------------------- sync queue

  /// Queued changes, oldest first. Rejected ones wait for a manual retry
  /// unless [includeDenied] is set.
  Future<List<PendingChange>> pendingChanges({
    bool includeDenied = false,
  }) async {
    final rows = await db.query(
      _table,
      columns: ['id', 'pendingOp', 'localRevision'],
      where: includeDenied
          ? 'pendingOp IS NOT NULL'
          : "pendingOp IS NOT NULL AND (lastError IS NULL OR lastError != '${SyncErrorCodes.denied}')",
      orderBy: 'updatedAt ASC, id ASC',
    );
    return [
      for (final row in rows)
        PendingChange(
          row['id'] as String,
          row['pendingOp'] as String,
          row['localRevision'] as int,
        ),
    ];
  }

  /// Records that [change] is about to be sent. After this, deleting the
  /// item leaves a tombstone because the upload may reach the server.
  /// Returns the commit to send, or null if the change was superseded.
  Future<RemoteCommit?> beginUpload(PendingChange change) async {
    return db.transaction((txn) async {
      final rows = await txn.query(
        _table,
        where: 'id = ? AND localRevision = ? AND pendingOp = ?',
        whereArgs: [change.id, change.localRevision, change.op],
      );
      if (rows.isEmpty) return null;
      final row = rows.single;
      if (change.op == _upsert && row['uploadAttempted'] != 1) {
        await txn.update(
          _table,
          {'uploadAttempted': 1},
          where: 'id = ?',
          whereArgs: [change.id],
        );
      }
      return RemoteCommit(
        id: change.id,
        delete: change.op == _delete,
        title: row['title'] as String,
        source: row['source'] as String,
        originalText: row['originalText'] as String,
        simplifiedText: row['simplifiedText'] as String?,
        favorite: row['favorite'] == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
        knownRevision: row['serverRevision'] as int,
      );
    });
  }

  /// The server acknowledged [change] at [serverRevision]. A newer local
  /// edit made meanwhile stays queued.
  Future<void> acknowledge(PendingChange change, int serverRevision) async {
    await db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        '''
        UPDATE $_table SET pendingOp = NULL, lastError = NULL,
          syncedRevision = localRevision, serverRevision = ?
        WHERE id = ? AND localRevision = ? AND pendingOp = ?
        ''',
        [serverRevision, change.id, change.localRevision, change.op],
      );
      if (updated == 0) {
        await txn.rawUpdate(
          'UPDATE $_table SET serverRevision = MAX(serverRevision, ?) '
          'WHERE id = ?',
          [serverRevision, change.id],
        );
      }
    });
  }

  Future<void> markError(String id, String code) async {
    await db.update(
      _table,
      {'lastError': code},
      where: 'id = ? AND pendingOp IS NOT NULL',
      whereArgs: [id],
    );
  }

  /// Makes rejected changes eligible for sending again.
  Future<void> clearDeniedErrors() async {
    await db.update(_table, {
      'lastError': null,
    }, where: 'pendingOp IS NOT NULL AND lastError IS NOT NULL');
  }

  /// The server holds a deletion marker for [id]; deletion wins.
  Future<void> applyServerDeletion(String id, int serverRevision) async {
    final file = await db.transaction(
      (txn) => _markDeletedFromServer(txn, id, serverRevision),
    );
    await file?.cleanup(this);
  }

  Future<_OwnedFile?> _markDeletedFromServer(
    Transaction txn,
    String id,
    int serverRevision,
  ) async {
    final rows = await txn.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    await txn.rawUpdate(
      '''
      UPDATE $_table SET deleted = 1, title = '', originalText = '',
        simplifiedText = NULL, favorite = 0, pendingOp = NULL,
        lastError = NULL, deviceOnlyReason = NULL, uploadAttempted = 1,
        serverRevision = MAX(serverRevision, ?),
        attachmentPath = NULL, attachmentType = NULL, attachmentOwned = 0
      WHERE id = ?
      ''',
      [serverRevision, id],
    );
    return rows.single['deleted'] == 1 ? null : _OwnedFile.fromRow(rows.single);
  }

  // ---------------------------------------------------------------- pull

  Future<RemoteCursor?> readCursor() async {
    final rows = await db.query(
      HistoryDatabase.metaTable,
      where: 'key = ?',
      whereArgs: [_cursorKey],
    );
    if (rows.isEmpty) return null;
    try {
      return RemoteCursor.fromJson(jsonDecode(rows.single['value'] as String));
    } catch (_) {
      return null;
    }
  }

  /// Merges one page of server changes and stores the cursor in the same
  /// transaction. Returns whether anything visible changed.
  ///
  /// Policy: a server deletion always wins. Local unsent edits (and
  /// device-only items) are never overwritten. Clean rows take the server
  /// version when its revision is newer.
  Future<bool> applyRemotePage(RemotePage page) async {
    final cleanups = <_OwnedFile>[];
    final changed = await db.transaction((txn) async {
      var changed = false;
      for (final doc in page.items) {
        final rows = await txn.query(
          _table,
          where: 'id = ?',
          whereArgs: [doc.id],
        );
        final local = rows.isEmpty ? null : rows.single;
        if (doc.deleted) {
          if (local == null) continue;
          if (local['deleted'] != 1) changed = true;
          final file = await _markDeletedFromServer(txn, doc.id, doc.revision);
          if (file != null) cleanups.add(file);
          continue;
        }
        if (local == null) {
          await txn.insert(_table, {
            'id': doc.id,
            'title': doc.title,
            'source': doc.source,
            'originalText': doc.originalText,
            'simplifiedText': doc.simplifiedText,
            'favorite': doc.favorite ? 1 : 0,
            'createdAt': doc.createdAt.millisecondsSinceEpoch,
            'updatedAt': doc.updatedAt.millisecondsSinceEpoch,
            'deleted': 0,
            'localRevision': 1,
            'syncedRevision': 1,
            'serverRevision': doc.revision,
            'uploadAttempted': 1,
          });
          changed = true;
          continue;
        }
        if (local['deleted'] == 1) continue;
        final dirty =
            local['pendingOp'] != null || local['deviceOnlyReason'] != null;
        final known = local['serverRevision'] as int;
        if (dirty || doc.revision <= known) {
          if (doc.revision > known) {
            await txn.update(
              _table,
              {'serverRevision': doc.revision, 'uploadAttempted': 1},
              where: 'id = ?',
              whereArgs: [doc.id],
            );
          }
          continue;
        }
        await txn.update(
          _table,
          {
            'title': doc.title,
            'originalText': doc.originalText,
            'simplifiedText': doc.simplifiedText,
            'favorite': doc.favorite ? 1 : 0,
            'updatedAt': doc.updatedAt.millisecondsSinceEpoch,
            'serverRevision': doc.revision,
            'uploadAttempted': 1,
          },
          where: 'id = ?',
          whereArgs: [doc.id],
        );
        changed = true;
      }
      if (page.next != null) {
        await txn.insert(HistoryDatabase.metaTable, {
          'key': _cursorKey,
          'value': jsonEncode(page.next!.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return changed;
    });
    for (final file in cleanups) {
      await file.cleanup(this);
    }
    return changed;
  }
}

class _OwnedFile {
  final String path;

  const _OwnedFile(this.path);

  static _OwnedFile? fromRow(Map<String, Object?> row) {
    final path = row['attachmentPath'];
    if (row['attachmentOwned'] != 1 || path is! String) return null;
    return _OwnedFile(path);
  }

  Future<void> cleanup(SavedTextsLocalStore store) =>
      store._deleteOwnedFile(path);
}
