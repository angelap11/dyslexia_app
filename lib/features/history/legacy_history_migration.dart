import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'history_database.dart';
import 'saved_text.dart';

/// Legacy History rows (file references) that are still shown separately
/// because they could not become saved texts.
class LegacyHistoryEntry {
  final int legacyId;
  final String fileName;
  final String filePath;
  final String fileType;
  final DateTime? createdAt;

  /// `deviceOnly` or `attention`.
  final String status;
  final String? reason;

  const LegacyHistoryEntry({
    required this.legacyId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.createdAt,
    required this.status,
    required this.reason,
  });

  bool get needsAttention => status == LegacyHistoryMigration.attention;

  /// The map shape expected by the legacy viewers.
  Map<String, dynamic> toFileMap() => {
    'fileName': fileName,
    'filePath': filePath,
    'fileType': fileType,
  };
}

class LegacyMigrationReport {
  /// Rows that are now saved texts (including duplicates merged into one).
  final int migrated;

  /// Rows kept as device-only legacy entries (photos without saved text).
  final int deviceOnly;

  /// Rows whose file is missing, unreadable or empty.
  final int attention;

  const LegacyMigrationReport({
    this.migrated = 0,
    this.deviceOnly = 0,
    this.attention = 0,
  });

  int get total => migrated + deviceOnly + attention;
}

/// Turns legacy `history_files` rows of one account into saved texts.
///
/// Only the per-account `history_<uid>.db` is read, so ownership is known.
/// Legacy rows and their files are never modified or deleted. Each
/// converted row gets a stable random id that is stored together with the
/// new item in one transaction, so repeated or interrupted runs neither
/// duplicate items nor bring back items the user deleted.
class LegacyHistoryMigration {
  static const migrated = 'migrated';
  static const deviceOnly = 'deviceOnly';
  static const attention = 'attention';

  /// Hidden by «Избриши сè»; never converted afterwards.
  static const dismissed = 'dismissed';

  final Database db;
  final Future<String?> Function(String path, String fileName) extractText;
  final DateTime Function() _now;

  LegacyHistoryMigration(
    this.db, {
    required this.extractText,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  Future<LegacyMigrationReport> run() async {
    final legacyRows = await db.query(
      HistoryDatabase.legacyTable,
      orderBy: 'id ASC',
    );
    final done = <int>{
      for (final row in await db.query(
        HistoryDatabase.migrationTable,
        columns: ['legacyId'],
        where: 'status != ?',
        whereArgs: [attention],
      ))
        row['legacyId'] as int,
    };
    for (final row in legacyRows) {
      final legacyId = row['id'] as int;
      if (done.contains(legacyId)) continue;
      await _migrateRow(row);
    }
    return report();
  }

  Future<LegacyMigrationReport> report() async {
    final rows = await db.rawQuery('''
      SELECT m.status AS status, COUNT(*) AS n
      FROM ${HistoryDatabase.migrationTable} m
      JOIN ${HistoryDatabase.legacyTable} l ON l.id = m.legacyId
      GROUP BY m.status
    ''');
    final counts = {for (final r in rows) r['status'] as String: r['n'] as int};
    return LegacyMigrationReport(
      migrated: counts[migrated] ?? 0,
      deviceOnly: counts[deviceOnly] ?? 0,
      attention: counts[attention] ?? 0,
    );
  }

  /// Legacy rows that did not become saved texts.
  Future<List<LegacyHistoryEntry>> unmigratedEntries() async {
    final rows = await db.rawQuery(
      '''
      SELECT l.id, l.fileName, l.filePath, l.fileType, l.createdAt,
        m.status, m.reason
      FROM ${HistoryDatabase.legacyTable} l
      JOIN ${HistoryDatabase.migrationTable} m ON m.legacyId = l.id
      WHERE m.status IN (?, ?)
      ORDER BY l.createdAt DESC, l.id DESC
      ''',
      [deviceOnly, attention],
    );
    return [
      for (final row in rows)
        LegacyHistoryEntry(
          legacyId: row['id'] as int,
          fileName: row['fileName'] as String,
          filePath: row['filePath'] as String,
          fileType: row['fileType'] as String,
          createdAt: DateTime.tryParse(row['createdAt'] as String? ?? ''),
          status: row['status'] as String,
          reason: row['reason'] as String?,
        ),
    ];
  }

  Future<void> _migrateRow(Map<String, Object?> row) async {
    final legacyId = row['id'] as int;
    final type = row['fileType'] as String? ?? 'other';
    final path = row['filePath'] as String? ?? '';
    final fileName = row['fileName'] as String? ?? '';
    final favorite = row['isFavorite'] == 1;

    if (type == 'image') {
      // Old OCR rows stored only the photo; the recognized text was never
      // kept, so there is nothing to sync. The photo stays on this device.
      await _mark(legacyId, deviceOnly, 'image');
      return;
    }

    String? text;
    late DateTime fileModified;
    try {
      final file = File(path);
      if (path.isEmpty || !await file.exists()) {
        await _mark(legacyId, attention, 'missing');
        return;
      }
      fileModified = await file.lastModified();
      text = await extractText(path, fileName);
    } catch (_) {
      await _mark(legacyId, attention, 'unreadable');
      return;
    }
    if (text == null || text.trim().isEmpty) {
      await _mark(legacyId, attention, 'empty');
      return;
    }

    final createdAt =
        DateTime.tryParse(row['createdAt'] as String? ?? '') ?? fileModified;
    final title = _titleFor(fileName, text, createdAt);
    final originalText = text;
    final fits = SavedTextLimits.fitsCloud(originalText, null);
    final lower = fileName.toLowerCase();
    final source = lower.endsWith('.pdf') || lower.endsWith('.docx')
        ? SavedTextSource.document
        : SavedTextSource.legacy;

    await db.transaction((txn) async {
      final mapped = await txn.query(
        HistoryDatabase.migrationTable,
        where: 'legacyId = ? AND status != ?',
        whereArgs: [legacyId, attention],
      );
      if (mapped.isNotEmpty) return;

      // The old app added a row each time the same file was opened; such
      // copies become one item.
      final duplicate = await txn.rawQuery(
        '''
        SELECT t.id FROM ${HistoryDatabase.textsTable} t
        JOIN ${HistoryDatabase.migrationTable} m ON m.textId = t.id
        WHERE m.status = ? AND t.title = ? AND t.originalText = ?
        LIMIT 1
        ''',
        [migrated, title, originalText],
      );
      String textId;
      String? reason;
      if (duplicate.isNotEmpty) {
        textId = duplicate.single['id'] as String;
        reason = 'duplicate';
        await txn.rawUpdate(
          'UPDATE ${HistoryDatabase.textsTable} SET createdAt = '
          'MIN(createdAt, ?) WHERE id = ?',
          [createdAt.millisecondsSinceEpoch, textId],
        );
        if (favorite) {
          await txn.rawUpdate(
            '''
            UPDATE ${HistoryDatabase.textsTable} SET favorite = 1,
              localRevision = localRevision + 1,
              pendingOp = CASE WHEN deviceOnlyReason IS NULL THEN 'upsert'
                ELSE pendingOp END
            WHERE id = ? AND favorite = 0 AND deleted = 0
            ''',
            [textId],
          );
        }
      } else {
        textId = SavedTextIds.generate();
        final now = _now().millisecondsSinceEpoch;
        await txn.insert(HistoryDatabase.textsTable, {
          'id': textId,
          'title': title,
          'source': source.name,
          'originalText': originalText,
          'simplifiedText': null,
          'favorite': favorite ? 1 : 0,
          'createdAt': createdAt.millisecondsSinceEpoch,
          'updatedAt': now,
          'deleted': 0,
          'localRevision': 1,
          'pendingOp': fits ? 'upsert' : null,
          'deviceOnlyReason': fits ? null : 'tooLarge',
          'attachmentPath': path,
          'attachmentType': type,
          'attachmentOwned': 0,
        });
      }
      await txn.insert(
        HistoryDatabase.migrationTable,
        {
          'legacyId': legacyId,
          'textId': textId,
          'status': migrated,
          'reason': reason,
          'updatedAt': _now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _mark(int legacyId, String status, String reason) async {
    await db.transaction((txn) async {
      final existing = await txn.query(
        HistoryDatabase.migrationTable,
        columns: ['status'],
        where: 'legacyId = ?',
        whereArgs: [legacyId],
      );
      if (existing.isNotEmpty && existing.single['status'] != attention) {
        return;
      }
      await txn.insert(
        HistoryDatabase.migrationTable,
        {
          'legacyId': legacyId,
          'textId': null,
          'status': status,
          'reason': reason,
          'updatedAt': _now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static String _titleFor(String fileName, String text, DateTime at) {
    final base = p.basenameWithoutExtension(fileName).trim();
    if (base.isEmpty) return SavedTextTitles.defaultTitle(text, at);
    final runes = base.runes;
    if (runes.length <= SavedTextLimits.maxTitleChars) return base;
    return '${String.fromCharCodes(runes.take(SavedTextLimits.maxTitleChars - 1))}…';
  }
}
