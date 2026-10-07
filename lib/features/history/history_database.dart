import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The per-account SQLite file `history_<uid>.db`.
///
/// Version 1 had only the legacy `history_files` table (file references).
/// Version 2 adds saved texts, the legacy migration map and sync metadata;
/// the legacy table is kept as-is. Version 3 adds synced favourites.
class HistoryDatabase {
  HistoryDatabase._();

  static const int version = 3;

  static const String legacyTable = 'history_files';
  static const String textsTable = 'saved_texts';
  static const String migrationTable = 'legacy_migration';
  static const String metaTable = 'sync_meta';

  @visibleForTesting
  static DatabaseFactory? factoryOverride;

  /// Directory for database files; null uses the platform default.
  @visibleForTesting
  static String? directoryOverride;

  static final Map<String, Future<Database>> _open = {};

  static DatabaseFactory get _factory => factoryOverride ?? databaseFactory;

  static String fileNameFor(String uid) => 'history_$uid.db';

  /// Opens the database of [uid]. Never used for signed-out or unscoped
  /// data: `history.db` and `history_anonymous.db` are not opened here.
  static Future<Database> forUid(String uid) {
    if (uid.isEmpty || uid == 'anonymous') {
      throw ArgumentError.value(uid, 'uid', 'not an account uid');
    }
    return _open[uid] ??= _openDb(uid).catchError((Object e) {
      _open.remove(uid);
      throw e;
    });
  }

  static Future<void> close(String uid) async {
    final db = _open.remove(uid);
    if (db == null) return;
    try {
      await (await db).close();
    } catch (_) {}
  }

  @visibleForTesting
  static Future<void> closeAll() async {
    for (final uid in _open.keys.toList()) {
      await close(uid);
    }
  }

  static Future<Database> _openDb(String uid) async {
    final dir = directoryOverride ?? await _factory.getDatabasesPath();
    return _factory.openDatabase(
      p.join(dir, fileNameFor(uid)),
      options: openOptions(),
    );
  }

  static OpenDatabaseOptions openOptions({bool singleInstance = true}) =>
      OpenDatabaseOptions(
        version: version,
        singleInstance: singleInstance,
        onCreate: (db, _) async {
          await _createLegacyTable(db);
          await _createV2Tables(db);
          await _upgradeToV3(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createV2Tables(db);
          if (oldVersion < 3) await _upgradeToV3(db);
        },
      );

  static Future<void> _createLegacyTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE $legacyTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        fileType TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isFavorite INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _createV2Tables(DatabaseExecutor db) async {
    // pendingOp is the durable queue entry; it is written in the same
    // statement as the content it refers to.
    await db.execute('''
      CREATE TABLE $textsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        source TEXT NOT NULL,
        originalText TEXT NOT NULL,
        simplifiedText TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        localRevision INTEGER NOT NULL DEFAULT 1,
        syncedRevision INTEGER NOT NULL DEFAULT 0,
        serverRevision INTEGER NOT NULL DEFAULT 0,
        pendingOp TEXT,
        uploadAttempted INTEGER NOT NULL DEFAULT 0,
        deviceOnlyReason TEXT,
        lastError TEXT,
        attachmentPath TEXT,
        attachmentType TEXT,
        attachmentOwned INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX saved_texts_list ON $textsTable (deleted, createdAt)',
    );
    await db.execute(
      'CREATE INDEX saved_texts_pending ON $textsTable (pendingOp, updatedAt)',
    );
    await db.execute('''
      CREATE TABLE $migrationTable (
        legacyId INTEGER PRIMARY KEY,
        textId TEXT,
        status TEXT NOT NULL,
        reason TEXT,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $metaTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Synced favourites. Items migrated by version 2 get their legacy star
  /// back, queued for upload like any other edit.
  static Future<void> _upgradeToV3(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE $textsTable ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('''
      UPDATE $textsTable SET favorite = 1,
        localRevision = localRevision + 1,
        pendingOp = CASE WHEN deviceOnlyReason IS NULL THEN 'upsert'
          ELSE pendingOp END
      WHERE deleted = 0 AND id IN (
        SELECT m.textId FROM $migrationTable m
        JOIN $legacyTable l ON l.id = m.legacyId
        WHERE m.status = 'migrated' AND l.isFavorite = 1
      )
    ''');
  }
}
