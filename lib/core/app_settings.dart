/// Central accessibility and appearance settings model.
class AppSettings {
  static const String hiveBoxName = 'app_settings';

  /// Keys from removed settings that may still exist in saved Hive boxes.
  static const List<String> retiredKeys = ['wordFocusEnabled', 'wordFocusBlur'];

  /// Reading/accessibility preferences that follow the account across
  /// devices. `darkMode` and `readingRulerEnabled` stay on this device.
  static const List<String> syncedKeys = [
    'fontScale',
    'dyslexiaFont',
    'focusMode',
    'highContrastMode',
    'speechRate',
    'readingRulerHeight',
    'readingRulerDimOpacity',
  ];

  static const double baseFontSize = 17.0;
  static const double minFontScale = 14 / baseFontSize;
  static const double maxFontScale = 26 / baseFontSize;
  static const double focusModeTextScaleBoost = 1.06;

  static const double defaultFontScale = 1.0;
  static const double defaultSpeechRate = 0.5;
  static const double defaultReadingRulerHeight = 76.0;
  static const double defaultReadingRulerDimOpacity = 0.5;
  static const double minReadingRulerHeight = 48.0;
  static const double maxReadingRulerHeight = 120.0;
  static const double minReadingRulerDimOpacity = 0.2;
  static const double maxReadingRulerDimOpacity = 0.75;
  static const double minSpeechRate = 0.3;
  static const double maxSpeechRate = 0.8;

  /// Shared with Settings and TTS speed picker: Бавно / Нормално / Брзо.
  static const List<double> speechRatePresets = [0.3, 0.5, 0.8];
  static const List<String> speechRateLabels = ['Бавно', 'Нормално', 'Брзо'];

  final double fontScale;
  final bool dyslexiaFont;
  final bool focusMode;
  final bool darkMode;
  final bool highContrastMode;
  final double speechRate;
  final bool readingRulerEnabled;
  final double readingRulerHeight;
  final double readingRulerDimOpacity;

  const AppSettings({
    this.fontScale = defaultFontScale,
    this.dyslexiaFont = true,
    this.focusMode = false,
    this.darkMode = false,
    this.highContrastMode = false,
    this.speechRate = defaultSpeechRate,
    this.readingRulerEnabled = false,
    this.readingRulerHeight = defaultReadingRulerHeight,
    this.readingRulerDimOpacity = defaultReadingRulerDimOpacity,
  });

  static const defaults = AppSettings();

  double get fontSizePx => baseFontSize * fontScale;

  double get textScaleFactor =>
      fontScale * (focusMode ? focusModeTextScaleBoost : 1.0);

  AppSettings copyWith({
    double? fontScale,
    bool? dyslexiaFont,
    bool? focusMode,
    bool? darkMode,
    bool? highContrastMode,
    double? speechRate,
    bool? readingRulerEnabled,
    double? readingRulerHeight,
    double? readingRulerDimOpacity,
  }) {
    return AppSettings(
      fontScale: fontScale ?? this.fontScale,
      dyslexiaFont: dyslexiaFont ?? this.dyslexiaFont,
      focusMode: focusMode ?? this.focusMode,
      darkMode: darkMode ?? this.darkMode,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      speechRate: speechRate ?? this.speechRate,
      readingRulerEnabled: readingRulerEnabled ?? this.readingRulerEnabled,
      readingRulerHeight: readingRulerHeight ?? this.readingRulerHeight,
      readingRulerDimOpacity:
          readingRulerDimOpacity ?? this.readingRulerDimOpacity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontScale': fontScale,
      'dyslexiaFont': dyslexiaFont,
      'focusMode': focusMode,
      'darkMode': darkMode,
      'highContrastMode': highContrastMode,
      'speechRate': speechRate,
      'readingRulerEnabled': readingRulerEnabled,
      'readingRulerHeight': readingRulerHeight,
      'readingRulerDimOpacity': readingRulerDimOpacity,
    };
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    return AppSettings(
      fontScale: _readDouble(
        map['fontScale'],
        defaultFontScale,
      ).clamp(minFontScale, maxFontScale),
      dyslexiaFont: map['dyslexiaFont'] as bool? ?? true,
      focusMode: map['focusMode'] as bool? ?? false,
      darkMode: map['darkMode'] as bool? ?? false,
      highContrastMode: map['highContrastMode'] as bool? ?? false,
      speechRate: _readDouble(map['speechRate'], defaultSpeechRate),
      readingRulerEnabled: map['readingRulerEnabled'] as bool? ?? false,
      readingRulerHeight: _readDouble(
        map['readingRulerHeight'],
        defaultReadingRulerHeight,
      ).clamp(minReadingRulerHeight, maxReadingRulerHeight),
      readingRulerDimOpacity: _readDouble(
        map['readingRulerDimOpacity'],
        defaultReadingRulerDimOpacity,
      ).clamp(minReadingRulerDimOpacity, maxReadingRulerDimOpacity),
    );
  }

  /// Whether [value] may be stored remotely for synced [key]. Mirrors the
  /// ranges enforced by `firestore.rules`.
  static bool isValidSyncedValue(String key, Object? value) {
    bool inRange(double min, double max) =>
        value is num && value >= min - 1e-9 && value <= max + 1e-9;

    switch (key) {
      case 'fontScale':
        return inRange(minFontScale, maxFontScale);
      case 'speechRate':
        return inRange(minSpeechRate, maxSpeechRate);
      case 'readingRulerHeight':
        return inRange(minReadingRulerHeight, maxReadingRulerHeight);
      case 'readingRulerDimOpacity':
        return inRange(minReadingRulerDimOpacity, maxReadingRulerDimOpacity);
      case 'dyslexiaFont':
      case 'focusMode':
      case 'highContrastMode':
        return value is bool;
      default:
        return false;
    }
  }

  /// Applies valid synced values from [values]; anything else is ignored.
  AppSettings withSyncedValues(Map<String, Object?> values) {
    final merged = toMap();
    for (final key in syncedKeys) {
      if (!values.containsKey(key)) continue;
      final value = values[key];
      if (!isValidSyncedValue(key, value)) continue;
      merged[key] = value is int ? value.toDouble() : value;
    }
    return AppSettings.fromMap(merged);
  }

  static double _readDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return fallback;
  }
}
