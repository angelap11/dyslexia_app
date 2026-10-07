import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_settings.dart';
import 'preferences_remote_store.dart';
import 'settings_local_store.dart';

enum PreferencesSyncStatus {
  /// Signed out: settings are kept on this device only.
  localOnly,

  /// Sync is not configured or not allowed; settings stay on this device.
  unavailable,

  /// Waiting for the first answer from the server.
  connecting,

  /// Local edits are saved on this device but not yet acknowledged.
  pending,

  /// The server has acknowledged every local edit.
  synced,

  /// The last attempt failed; edits stay pending on this device.
  failed,
}

/// Remote sync state for one signed-in account. Results that arrive after
/// the session was closed are ignored.
class _SyncSession {
  final String uid;
  StreamSubscription<RemotePreferencesSnapshot>? subscription;
  Timer? debounce;
  Timer? connectTimer;
  bool closed = false;
  bool serverChecked = false;
  bool initializing = false;
  bool waitingForNetwork = false;
  bool unavailable = false;
  bool failed = false;
  int inFlight = 0;

  _SyncSession(this.uid);

  void close() {
    closed = true;
    debounce?.cancel();
    connectTimer?.cancel();
    unawaited(subscription?.cancel());
    subscription = null;
  }
}

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    SettingsLocalStore? localStore,
    PreferencesRemoteStore? remoteStore,
    String? Function()? currentUid,
    this.writeDebounce = const Duration(milliseconds: 800),
    this.connectTimeout = const Duration(seconds: 12),
  }) : _local = localStore ?? HiveSettingsLocalStore(),
       _remote = remoteStore,
       _currentUidOverride = currentUid;

  final SettingsLocalStore _local;
  final PreferencesRemoteStore? _remote;
  final String? Function()? _currentUidOverride;

  /// Quiet period before edits are sent, so a slider drag is one write.
  final Duration writeDebounce;

  /// After this long without a server answer the UI reports no connection.
  final Duration connectTimeout;

  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;
  bool _disposed = false;

  /// Settings for [_activeUid] are loaded and may be shown and edited.
  bool _hasSession = false;
  bool _switching = false;
  String? _activeUid;
  int _generation = 0;
  _SyncSession? _session;

  /// Synced keys edited on this device and not yet acknowledged by the
  /// server. Persisted per uid so edits survive restarts and sign-outs.
  Set<String> _pending = <String>{};

  /// Bumped on every local edit, so an acknowledgement only clears a key
  /// when no newer edit happened while the write was in flight.
  final Map<String, int> _versions = {};

  /// Synced keys this account has a stored local value for.
  Set<String> _storedSyncedKeys = <String>{};

  PreferencesSyncStatus _syncStatus = PreferencesSyncStatus.localOnly;

  bool get isLoaded => _loaded;

  String? get activeUid => _activeUid;

  /// Whether the settings of [uid] (null = signed out) are loaded.
  bool isReadyFor(String? uid) => _hasSession && _activeUid == uid;

  bool isSwitchingTo(String? uid) => _switching && _activeUid == uid;

  PreferencesSyncStatus get syncStatus => _syncStatus;

  bool get hasPendingSync => _pending.isNotEmpty;

  Set<String> get pendingSyncKeys => Set.unmodifiable(_pending);

  /// No server answer recently; local edits wait on this device.
  bool get syncWaitingForNetwork => _session?.waitingForNetwork ?? false;

  double get fontScale => _settings.fontScale;

  /// Display size in px (base × scale) — used by the settings slider label.
  double get fontSize => _settings.fontSizePx;

  bool get dyslexiaFont => _settings.dyslexiaFont;

  bool get focusMode => _settings.focusMode;

  bool get darkMode => _settings.darkMode;

  bool get highContrastMode => _settings.highContrastMode;

  double get speechRate => _settings.speechRate;

  bool get readingRulerEnabled => _settings.readingRulerEnabled;

  double get readingRulerHeight => _settings.readingRulerHeight;

  double get readingRulerDimOpacity => _settings.readingRulerDimOpacity;

  /// Combined scale applied globally via [MediaQuery.textScaler].
  double get textScaleFactor => _settings.textScaleFactor;

  AppSettings get settings => _settings;

  String? _currentUid() {
    final override = _currentUidOverride;
    if (override != null) return override();
    return FirebaseAuth.instance.currentUser?.uid;
  }

  bool _isCurrent(_SyncSession session) =>
      identical(session, _session) && !session.closed;

  /// Shows defaults immediately, then loads [uid]'s settings (null = signed
  /// out) and starts syncing them. A newer call makes older ones no-ops.
  Future<void> switchUser(String? uid) async {
    final generation = ++_generation;
    _closeSession();
    _switching = true;
    _hasSession = false;
    _activeUid = uid;
    _settings = AppSettings.defaults;
    _pending = <String>{};
    _versions.clear();
    _storedSyncedKeys = <String>{};
    _refreshStatus();
    _notify();

    var stored = <String, Object?>{};
    var pending = <String>{};
    try {
      stored = await _local.read(uid);
      if (uid != null) pending = await _local.readPending(uid);
    } catch (e) {
      debugPrint('[Settings] local load failed for ${_label(uid)}: $e');
    }
    if (generation != _generation) return;

    var loaded = AppSettings.fromMap(stored);
    // Upgrade users still on the previous default band height.
    if (loaded.readingRulerHeight == 56.0) {
      loaded = loaded.copyWith(
        readingRulerHeight: AppSettings.defaultReadingRulerHeight,
      );
      unawaited(
        _writeLocal(uid, {'readingRulerHeight': loaded.readingRulerHeight}),
      );
    }

    _settings = loaded;
    _storedSyncedKeys = AppSettings.syncedKeys
        .where(stored.containsKey)
        .toSet();
    _pending = pending.where(AppSettings.syncedKeys.contains).toSet();
    _hasSession = true;
    _switching = false;
    _loaded = true;
    if (uid != null) _startSession(uid);
    _refreshStatus();
    _notify();
  }

  /// Restarts sync for the current account after a failure.
  Future<void> retrySync() async {
    final uid = _activeUid;
    if (!_hasSession || uid == null || _remote == null) return;
    _closeSession();
    _startSession(uid);
    _refreshStatus();
    _notify();
  }

  /// Sends pending edits while the account is still signed in. Returns true
  /// when the server acknowledged everything; otherwise the edits stay
  /// pending on this device for this account's next sign-in here.
  Future<bool> flushPendingSync({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final session = _session;
    if (session == null || _pending.isEmpty) return _pending.isEmpty;
    session.debounce?.cancel();
    try {
      await _flush(session).timeout(timeout);
    } on TimeoutException {
      debugPrint('[SettingsSync] flush before sign-out timed out');
    }
    return _pending.isEmpty;
  }

  void _startSession(String uid) {
    final session = _SyncSession(uid);
    _session = session;
    final remote = _remote;
    if (remote == null) return;

    session.connectTimer = Timer(connectTimeout, () {
      if (!_isCurrent(session) || session.serverChecked) return;
      session.waitingForNetwork = true;
      _refreshStatus();
      _notify();
    });

    try {
      session.subscription = remote
          .watch(uid)
          .listen(
            (snapshot) => _onRemoteSnapshot(session, snapshot),
            onError: (Object error) => _onListenError(session, error),
          );
    } catch (e) {
      _onListenError(session, e);
    }
  }

  void _closeSession() {
    _session?.close();
    _session = null;
  }

  void _onRemoteSnapshot(
    _SyncSession session,
    RemotePreferencesSnapshot snapshot,
  ) {
    if (!_isCurrent(session)) return;

    if (snapshot.exists) _applyRemote(session, snapshot.values);

    if (snapshot.fromCache) {
      if (session.serverChecked) session.waitingForNetwork = true;
    } else {
      session.waitingForNetwork = false;
      session.connectTimer?.cancel();
      if (!session.serverChecked) {
        session.serverChecked = true;
        if (!snapshot.exists) {
          unawaited(_initializeRemote(session));
        } else if (_pending.isNotEmpty) {
          _scheduleFlush(session, Duration.zero);
        }
      }
    }
    _refreshStatus();
    _notify();
  }

  void _onListenError(_SyncSession session, Object error) {
    if (!_isCurrent(session)) return;
    session.connectTimer?.cancel();
    _recordError(session, error);
    _refreshStatus();
    _notify();
  }

  /// Applies remote values for keys without pending local edits. Never marks
  /// anything pending, so remote updates cannot trigger writes.
  void _applyRemote(_SyncSession session, Map<String, Object?> values) {
    final incoming = Map<String, Object?>.of(values)
      ..removeWhere((key, _) => _pending.contains(key));
    if (incoming.isEmpty) return;

    final next = _settings.withSyncedValues(incoming);
    final changed = _changedKeys(_settings, next);
    if (changed.isEmpty) return;

    _settings = next;
    _storedSyncedKeys.addAll(changed);
    final map = next.toMap();
    unawaited(_writeLocal(session.uid, {for (final k in changed) k: map[k]}));
  }

  /// The server has no document: create it from this account's own stored
  /// values only. If nothing was ever stored, defaults are not uploaded.
  Future<void> _initializeRemote(_SyncSession session) async {
    final remote = _remote;
    if (remote == null) return;

    final fields = _syncableFields({..._storedSyncedKeys, ..._pending});
    if (fields.isEmpty) return;
    if (_currentUid() != session.uid) return;

    final versions = _versionsFor(fields.keys);
    session.initializing = true;
    _refreshStatus();
    _notify();

    var created = false;
    try {
      created = await remote.createIfAbsent(session.uid, fields);
      if (!_isCurrent(session)) return;
      session.failed = false;
      if (created) _acknowledge(session, versions);
    } catch (e) {
      if (!_isCurrent(session)) return;
      _recordError(session, e);
      // Re-check on the next server snapshot instead of guessing.
      session.serverChecked = false;
    } finally {
      if (_isCurrent(session)) {
        session.initializing = false;
        if (session.serverChecked && _pending.isNotEmpty) {
          _scheduleFlush(session, Duration.zero);
        }
        _refreshStatus();
        _notify();
      }
    }
  }

  void _scheduleFlush(_SyncSession session, [Duration? delay]) {
    if (!_isCurrent(session) || _remote == null) return;
    session.debounce?.cancel();
    session.debounce = Timer(
      delay ?? writeDebounce,
      () => unawaited(_flush(session)),
    );
  }

  /// Writes the current values of pending keys. Keys are cleared only after
  /// the server acknowledges the write and no newer edit happened meanwhile.
  Future<void> _flush(_SyncSession session) async {
    final remote = _remote;
    if (remote == null || !_isCurrent(session)) return;
    if (!session.serverChecked || session.initializing) return;
    if (session.unavailable) return;
    if (_currentUid() != session.uid) return;

    final invalid = _pending.where((key) {
      return !AppSettings.isValidSyncedValue(key, _settings.toMap()[key]);
    }).toList();
    if (invalid.isNotEmpty) {
      debugPrint('[SettingsSync] keeping local-only invalid values: $invalid');
      _pending.removeAll(invalid);
      unawaited(_writePending(session.uid, {..._pending}));
    }

    final fields = _syncableFields(_pending);
    if (fields.isEmpty) {
      _refreshStatus();
      _notify();
      return;
    }

    final versions = _versionsFor(fields.keys);
    session.inFlight++;
    session.failed = false;
    _refreshStatus();
    _notify();
    try {
      await remote.writeFields(session.uid, fields);
      if (!_isCurrent(session)) return;
      _acknowledge(session, versions);
    } catch (e) {
      if (!_isCurrent(session)) return;
      _recordError(session, e);
    } finally {
      if (_isCurrent(session)) {
        session.inFlight--;
        _refreshStatus();
        _notify();
      }
    }
  }

  void _acknowledge(_SyncSession session, Map<String, int> versions) {
    var changed = false;
    versions.forEach((key, version) {
      if ((_versions[key] ?? 0) == version && _pending.remove(key)) {
        changed = true;
      }
    });
    if (changed) unawaited(_writePending(session.uid, {..._pending}));
  }

  void _recordError(_SyncSession session, Object error) {
    debugPrint('[SettingsSync] ${_label(session.uid)}: $error');
    if (error is PreferencesSyncException &&
        error.kind == PreferencesSyncErrorKind.unavailable) {
      session.unavailable = true;
    } else {
      session.failed = true;
    }
  }

  Map<String, Object> _syncableFields(Iterable<String> keys) {
    final map = _settings.toMap();
    return {
      for (final key in keys)
        if (AppSettings.isValidSyncedValue(key, map[key])) key: map[key]!,
    };
  }

  Map<String, int> _versionsFor(Iterable<String> keys) => {
    for (final key in keys) key: _versions[key] ?? 0,
  };

  void _refreshStatus() {
    final session = _session;
    if (_activeUid == null) {
      _syncStatus = PreferencesSyncStatus.localOnly;
    } else if (_remote == null || session == null || session.unavailable) {
      _syncStatus = _remote == null || (session?.unavailable ?? false)
          ? PreferencesSyncStatus.unavailable
          : PreferencesSyncStatus.connecting;
    } else if (session.failed) {
      _syncStatus = PreferencesSyncStatus.failed;
    } else if (_pending.isNotEmpty || session.inFlight > 0) {
      _syncStatus = PreferencesSyncStatus.pending;
    } else if (!session.serverChecked || session.initializing) {
      _syncStatus = PreferencesSyncStatus.connecting;
    } else {
      _syncStatus = PreferencesSyncStatus.synced;
    }
  }

  Future<void> _update(AppSettings next) async {
    final changed = _changedKeys(_settings, next);
    if (changed.isEmpty) return;
    // Between accounts nothing editable is on screen; never guess the owner.
    if (_switching) return;

    final uid = _activeUid;
    final persist = _hasSession;
    _settings = next;

    final synced = changed.where(AppSettings.syncedKeys.contains).toList();
    final trackSync = persist && uid != null && synced.isNotEmpty;
    if (trackSync) {
      for (final key in synced) {
        _versions[key] = (_versions[key] ?? 0) + 1;
      }
      _pending.addAll(synced);
      _storedSyncedKeys.addAll(synced);
      _refreshStatus();
    }
    _notify();
    if (!persist) return;

    final map = next.toMap();
    final session = _session;
    final generation = _generation;
    final pendingSnapshot = {..._pending};
    // Value first: a crash in between loses the pending mark (remote wins)
    // rather than uploading an old value as a new edit.
    await _writeLocal(uid, {for (final k in changed) k: map[k]});
    if (trackSync) {
      // An acknowledgement may have landed meanwhile; after an account
      // switch _pending belongs to someone else, so keep this uid's snapshot.
      final stillActive = generation == _generation;
      await _writePending(uid, stillActive ? {..._pending} : pendingSnapshot);
      if (session != null) _scheduleFlush(session);
    }
  }

  Future<void> _writeLocal(String? uid, Map<String, Object?> values) async {
    try {
      await _local.write(uid, values);
    } catch (e) {
      debugPrint('[Settings] local write failed for ${_label(uid)}: $e');
    }
  }

  Future<void> _writePending(String uid, Set<String> keys) async {
    try {
      await _local.writePending(uid, keys);
    } catch (e) {
      debugPrint('[SettingsSync] pending write failed: $e');
    }
  }

  static List<String> _changedKeys(AppSettings a, AppSettings b) {
    final before = a.toMap();
    final after = b.toMap();
    return [
      for (final key in after.keys)
        if (before[key] != after[key]) key,
    ];
  }

  static String _label(String? uid) => uid == null ? 'signed-out' : 'account';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _closeSession();
    super.dispose();
  }

  Future<void> setFontScale(double value) => _update(
    _settings.copyWith(
      fontScale: value.clamp(
        AppSettings.minFontScale,
        AppSettings.maxFontScale,
      ),
    ),
  );

  Future<void> setFontSize(double px) =>
      setFontScale(px / AppSettings.baseFontSize);

  Future<void> setDyslexiaFont(bool value) =>
      _update(_settings.copyWith(dyslexiaFont: value));

  Future<void> setFocusMode(bool value) =>
      _update(_settings.copyWith(focusMode: value));

  Future<void> setDarkMode(bool value) =>
      _update(_settings.copyWith(darkMode: value));

  Future<void> setHighContrastMode(bool value) =>
      _update(_settings.copyWith(highContrastMode: value));

  Future<void> setSpeechRate(double value) => _update(
    _settings.copyWith(
      speechRate: value.clamp(
        AppSettings.minSpeechRate,
        AppSettings.maxSpeechRate,
      ),
    ),
  );

  Future<void> setReadingRulerEnabled(bool value) =>
      _update(_settings.copyWith(readingRulerEnabled: value));

  Future<void> setReadingRulerHeight(double value) => _update(
    _settings.copyWith(
      readingRulerHeight: value.clamp(
        AppSettings.minReadingRulerHeight,
        AppSettings.maxReadingRulerHeight,
      ),
    ),
  );

  Future<void> setReadingRulerDimOpacity(double value) => _update(
    _settings.copyWith(
      readingRulerDimOpacity: value.clamp(
        AppSettings.minReadingRulerDimOpacity,
        AppSettings.maxReadingRulerDimOpacity,
      ),
    ),
  );

  Future<void> resetToDefaults() => _update(AppSettings.defaults);
}
