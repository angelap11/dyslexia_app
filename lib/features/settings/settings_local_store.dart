import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_settings.dart';

/// Device storage for settings. A `null` uid is the signed-out scope.
abstract class SettingsLocalStore {
  /// Every stored settings value for [uid]; missing keys were never saved.
  Future<Map<String, Object?>> read(String? uid);

  /// Stores only the given keys; other stored keys are left untouched.
  Future<void> write(String? uid, Map<String, Object?> values);

  /// Synced keys edited on this device that the server has not acknowledged.
  Future<Set<String>> readPending(String uid);

  Future<void> writePending(String uid, Set<String> keys);
}

class HiveSettingsLocalStore implements SettingsLocalStore {
  static const _pendingKey = 'pendingFields';

  static String boxNameFor(String? uid) {
    if (uid == null || uid.isEmpty) return AppSettings.hiveBoxName;
    return '${AppSettings.hiveBoxName}_$uid';
  }

  static String _syncBoxNameFor(String uid) => 'settings_sync_$uid';

  @override
  Future<Map<String, Object?>> read(String? uid) async {
    final box = await Hive.openBox(boxNameFor(uid));

    // Unscoped legacy values may only seed the signed-out scope; they are
    // never copied into an account.
    if (uid == null && box.isEmpty) {
      await _migrateFromSharedPreferences(box);
    }

    final retired = AppSettings.retiredKeys.where(box.containsKey).toList();
    if (retired.isNotEmpty) {
      await box.deleteAll(retired);
    }

    return {
      for (final entry in box.toMap().entries) '${entry.key}': entry.value,
    };
  }

  @override
  Future<void> write(String? uid, Map<String, Object?> values) async {
    final box = await Hive.openBox(boxNameFor(uid));
    await box.putAll(values);
  }

  @override
  Future<Set<String>> readPending(String uid) async {
    final box = await Hive.openBox(_syncBoxNameFor(uid));
    final raw = box.get(_pendingKey);
    if (raw is! List) return <String>{};
    return raw.whereType<String>().toSet();
  }

  @override
  Future<void> writePending(String uid, Set<String> keys) async {
    final box = await Hive.openBox(_syncBoxNameFor(uid));
    await box.put(_pendingKey, keys.toList()..sort());
  }

  Future<void> _migrateFromSharedPreferences(Box<dynamic> box) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('fontSize') &&
        !prefs.containsKey('dyslexiaFont') &&
        !prefs.containsKey('focusMode')) {
      return;
    }

    final legacyFontSize =
        prefs.getDouble('fontSize') ?? AppSettings.baseFontSize;

    final migrated = AppSettings(
      fontScale: (legacyFontSize / AppSettings.baseFontSize).clamp(
        AppSettings.minFontScale,
        AppSettings.maxFontScale,
      ),
      dyslexiaFont: prefs.getBool('dyslexiaFont') ?? true,
      focusMode: prefs.getBool('focusMode') ?? false,
      darkMode: prefs.getBool('darkMode') ?? false,
      highContrastMode: false,
      speechRate:
          prefs.getDouble('speechRate') ?? AppSettings.defaultSpeechRate,
    );

    await box.putAll(migrated.toMap());
  }
}
