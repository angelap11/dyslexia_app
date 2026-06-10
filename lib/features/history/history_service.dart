import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class HistoryService {
  static Database? _database;

  static const String tableName = 'history_files';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    return openDatabase(
      join(dbPath, 'history.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fileName TEXT NOT NULL,
            filePath TEXT NOT NULL,
            fileType TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            isFavorite INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  String getFileType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.txt')) return 'text';
    if (lower.endsWith('.pdf')) return 'pdf';

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return 'image';
    }

    return 'other';
  }

  Future<void> saveFile({
    required String fileName,
    required String filePath,
  }) async {
    final db = await database;

    await db.insert(
      tableName,
      {
        'fileName': fileName,
        'filePath': filePath,
        'fileType': getFileType(fileName),
        'createdAt': DateTime.now().toIso8601String(),
        'isFavorite': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getHistory({
    String searchQuery = '',
    String filterType = 'all',
    String sortBy = 'date',
  }) async {
    final db = await database;

    String? where;
    List<dynamic> whereArgs = [];

    if (searchQuery.isNotEmpty && filterType != 'all') {
      where = 'fileName LIKE ? AND fileType = ?';
      whereArgs = ['%$searchQuery%', filterType];
    } else if (searchQuery.isNotEmpty) {
      where = 'fileName LIKE ?';
      whereArgs = ['%$searchQuery%'];
    } else if (filterType != 'all') {
      where = 'fileType = ?';
      whereArgs = [filterType];
    }

    String orderBy;

    if (sortBy == 'name') {
      orderBy = 'fileName COLLATE NOCASE ASC';
    } else if (sortBy == 'favorite') {
      orderBy = 'isFavorite DESC, createdAt DESC';
    } else {
      orderBy = 'createdAt DESC';
    }

    return await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  Future<void> deleteFile(int id) async {
    final db = await database;

    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete(tableName);
  }

  Future<void> toggleFavorite({
    required int id,
    required int currentValue,
  }) async {
    final db = await database;

    await db.update(
      tableName,
      {
        'isFavorite': currentValue == 1 ? 0 : 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getHistoryCount() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}