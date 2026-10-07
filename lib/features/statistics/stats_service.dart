import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  /// Returns the uid of the currently signed-in Firebase user,
  /// falling back to 'anonymous' if none (should not happen in normal flow).
  static String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  /// Prefix every key with the current uid so each user has isolated counters.
  static String _k(String key) => 'u_${_uid}_$key';

  String get _ocrKey => _k('ocr_count');
  String get _ttsKey => _k('tts_count');
  String get _savedKey => _k('saved_texts');
  String get _lastActivityKey => _k('last_activity_date');
  String get _streakKey => _k('reading_streak');
  String get _todayActivityKey => _k('today_activity');
  String get _todayDateKey => _k('today_activity_date');
  String get _weeklyMapKey => _k('weekly_activity_map');

  /// Soft daily reading goal used on home and progress screens.
  static const int dailyGoal = 3;

  Future<void> incrementOCR() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_ocrKey) ?? 0;
    await prefs.setInt(_ocrKey, value + 1);
    await _incrementToday(prefs, ocr: 1);
    await _updateStreakOnActivity(prefs);
  }

  Future<void> incrementTTS() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_ttsKey) ?? 0;
    await prefs.setInt(_ttsKey, value + 1);
    await _incrementToday(prefs, tts: 1);
    await _updateStreakOnActivity(prefs);
  }

  Future<void> incrementSavedTexts() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_savedKey) ?? 0;
    await prefs.setInt(_savedKey, value + 1);
    await _incrementToday(prefs, saved: 1);
  }

  Future<int> getOCRCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_ocrKey) ?? 0;
  }

  Future<int> getTTSCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_ttsKey) ?? 0;
  }

  Future<int> getSavedTexts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_savedKey) ?? 0;
  }

  Future<int> getReadingStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await _refreshStreakIfNeeded(prefs);
    return prefs.getInt(_streakKey) ?? 0;
  }

  Future<int> getTodayActivityCount() async {
    final today = await getTodayBreakdown();
    return today.total;
  }

  Future<DailyActivityRecord> getTodayBreakdown() async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadDailyMap(prefs);
    return map[_todayKey()] ?? DailyActivityRecord.zero;
  }

  /// Returns activity counts for the last [days] days (oldest → today).
  Future<List<DayActivity>> getRecentActivity({int days = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _loadDailyMap(prefs);
    final now = DateTime.now();
    const labels = ['Пон', 'Вто', 'Сре', 'Чет', 'Пет', 'Саб', 'Нед'];
    final count = days.clamp(1, 14);
    final today = _todayKey();

    return List.generate(count, (i) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: count - 1 - i));
      final key = _dateKey(day);
      return DayActivity(
        label: labels[day.weekday - 1],
        count: map[key]?.total ?? 0,
        isToday: key == today,
      );
    });
  }

  /// Returns activity counts for the last 7 days (oldest → today).
  Future<List<DayActivity>> getWeeklyActivity() {
    return getRecentActivity(days: 7);
  }

  /// Sum of the last 7 days vs the 7 days before that.
  Future<WeekComparison> getWeekComparison() async {
    final recent = await getRecentActivity(days: 14);
    final thisWeek = recent.length <= 7
        ? recent
        : recent.sublist(recent.length - 7);
    final lastWeek = recent.length <= 7
        ? const <DayActivity>[]
        : recent.sublist(0, recent.length - 7);

    int sum(List<DayActivity> days) =>
        days.fold<int>(0, (total, day) => total + day.count);

    return WeekComparison(thisWeek: sum(thisWeek), lastWeek: sum(lastWeek));
  }

  Future<void> _incrementToday(
    SharedPreferences prefs, {
    int ocr = 0,
    int tts = 0,
    int saved = 0,
  }) async {
    final today = _todayKey();
    final map = await _loadDailyMap(prefs);
    final current = map[today] ?? DailyActivityRecord.zero;
    map[today] = current.incremented(ocr: ocr, tts: tts, saved: saved);
    await _writeDailyMap(prefs, map);
    await _syncTodayCache(prefs, map[today]!);
  }

  Future<void> _updateStreakOnActivity(SharedPreferences prefs) async {
    await _refreshStreakIfNeeded(prefs);

    final today = _todayKey();
    final last = prefs.getString(_lastActivityKey);
    final streak = prefs.getInt(_streakKey) ?? 0;
    final yesterday = _yesterdayKey();

    if (last != today) {
      final nextStreak = last == yesterday ? streak + 1 : 1;
      await prefs.setInt(_streakKey, nextStreak);
      await prefs.setString(_lastActivityKey, today);
    }
  }

  Future<void> _refreshStreakIfNeeded(SharedPreferences prefs) async {
    final last = prefs.getString(_lastActivityKey);
    if (last == null) return;

    final today = _todayKey();
    final yesterday = _yesterdayKey();
    if (last != today && last != yesterday) {
      await prefs.setInt(_streakKey, 0);
    }
  }

  Future<void> _syncTodayCache(
    SharedPreferences prefs,
    DailyActivityRecord today,
  ) async {
    await prefs.setString(_todayDateKey, _todayKey());
    await prefs.setInt(_todayActivityKey, today.total);
  }

  Future<Map<String, DailyActivityRecord>> _loadDailyMap(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_weeklyMapKey);
    final today = _todayKey();
    final map = <String, DailyActivityRecord>{};
    var needsRewrite = false;

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          final parsed = DailyActivityRecord.fromStored(value);
          if (value is num && key == today) {
            map[key] = DailyActivityRecord.zero;
            needsRewrite = true;
            return;
          }
          if (value is num) {
            needsRewrite = true;
          }
          map[key] = parsed;
        });
      } catch (_) {
        // Keep an empty map rather than inventing history.
      }
    }

    if (prefs.getString(_todayDateKey) != today) {
      map.putIfAbsent(today, () => DailyActivityRecord.zero);
      await _syncTodayCache(prefs, map[today]!);
      needsRewrite = true;
    }

    if (needsRewrite) {
      await _writeDailyMap(prefs, map);
    }

    return map;
  }

  Future<void> _writeDailyMap(
    SharedPreferences prefs,
    Map<String, DailyActivityRecord> map,
  ) async {
    final now = DateTime.now();
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 14));

    map.removeWhere((key, _) {
      final date = _tryParseDateKey(key);
      if (date == null) return true;
      return date.isBefore(cutoff);
    });

    await prefs.setString(
      _weeklyMapKey,
      jsonEncode(map.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  DateTime? _tryParseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _yesterdayKey() =>
      _dateKey(DateTime.now().subtract(const Duration(days: 1)));

  String _dateKey(DateTime day) {
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }
}

class DailyActivityRecord {
  final int ocr;
  final int tts;
  final int saved;
  final int legacyTotal;

  const DailyActivityRecord({
    this.ocr = 0,
    this.tts = 0,
    this.saved = 0,
    this.legacyTotal = 0,
  });

  static const zero = DailyActivityRecord();

  int get total {
    final typed = ocr + tts + saved;
    return typed > 0 ? typed : legacyTotal;
  }

  DailyActivityRecord incremented({int ocr = 0, int tts = 0, int saved = 0}) {
    return DailyActivityRecord(
      ocr: this.ocr + ocr,
      tts: this.tts + tts,
      saved: this.saved + saved,
    );
  }

  static DailyActivityRecord fromStored(dynamic value) {
    if (value is num) {
      return DailyActivityRecord(legacyTotal: value.toInt());
    }
    if (value is Map) {
      return DailyActivityRecord(
        ocr: (value['ocr'] as num?)?.toInt() ?? 0,
        tts: (value['tts'] as num?)?.toInt() ?? 0,
        saved: (value['saved'] as num?)?.toInt() ?? 0,
        legacyTotal: (value['legacyTotal'] as num?)?.toInt() ?? 0,
      );
    }
    return DailyActivityRecord.zero;
  }

  Map<String, int> toJson() {
    if (ocr + tts + saved == 0 && legacyTotal > 0) {
      return {'legacyTotal': legacyTotal};
    }
    return {'ocr': ocr, 'tts': tts, 'saved': saved};
  }
}

class DayActivity {
  final String label;
  final int count;
  final bool isToday;

  const DayActivity({
    required this.label,
    required this.count,
    required this.isToday,
  });
}

class WeekComparison {
  final int thisWeek;
  final int lastWeek;

  const WeekComparison({required this.thisWeek, required this.lastWeek});
}
