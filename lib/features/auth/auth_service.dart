import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Database? _database;

  static const String tableName = 'users';

  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _currentUserIdKey = 'currentUserId';
  static const String _currentUserNameKey = 'currentUserName';
  static const String _currentUserEmailKey = 'currentUserEmail';

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();

    return openDatabase(
      join(dbPath, 'auth.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            passwordHash TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> _saveSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_currentUserIdKey, user['id'] as int);
    await prefs.setString(_currentUserNameKey, user['name'] as String);
    await prefs.setString(_currentUserEmailKey, user['email'] as String);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<String?> getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserNameKey);
  }

  Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserEmailKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_currentUserIdKey);
    await prefs.remove(_currentUserNameKey);
    await prefs.remove(_currentUserEmailKey);
  }

  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await database;

    final normalizedEmail = email.trim().toLowerCase();

    final existingUser = await db.query(
      tableName,
      where: 'email = ?',
      whereArgs: [normalizedEmail],
    );

    if (existingUser.isNotEmpty) {
      return false;
    }

    await db.insert(
      tableName,
      {
        'name': name.trim(),
        'email': normalizedEmail,
        'passwordHash': _hashPassword(password),
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    return true;
  }

  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    final db = await database;

    final result = await db.query(
      tableName,
      where: 'email = ? AND passwordHash = ?',
      whereArgs: [
        email.trim().toLowerCase(),
        _hashPassword(password),
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    final user = result.first;
    await _saveSession(user);

    return user;
  }
}