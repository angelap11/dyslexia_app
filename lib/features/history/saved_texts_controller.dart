import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../files/files_service.dart';
import 'history_database.dart';
import 'legacy_history_migration.dart';
import 'saved_text.dart';
import 'saved_texts_local_store.dart';
import 'saved_texts_remote.dart';

/// Overall sync state for the History header indicator.
enum SavedTextsSyncStatus {
  /// No account or no cloud configured: texts stay on this device.
  localOnly,
  idle,
  syncing,

  /// Changes wait on this device until the connection returns.
  waitingForNetwork,

  /// Some changes were rejected or failed; a manual retry is offered.
  failed,
}

/// State of one signed-in account. Results that arrive after the session
/// was closed are ignored.
class _Session {
  final String uid;
  final SavedTextsLocalStore store;
  final LegacyHistoryMigration migration;
  bool closed = false;
  bool syncing = false;
  bool rerun = false;
  bool rerunPull = false;
  bool offline = false;
  bool hadFailure = false;
  int backoffStep = 0;
  Timer? retryTimer;

  _Session(this.uid, this.store, this.migration);

  void close() {
    closed = true;
    retryTimer?.cancel();
    retryTimer = null;
  }
}

class SavedTextsController extends ChangeNotifier with WidgetsBindingObserver {
  SavedTextsController({
    SavedTextsRemoteStore? remote,
    String? Function()? currentUid,
    Future<Database> Function(String uid)? openDatabase,
    Future<String> Function()? documentsDir,
    Future<String?> Function(String path, String fileName)? extractLegacyText,
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 20),
    this.retryBase = const Duration(seconds: 15),
    this.retryMax = const Duration(minutes: 5),
    this.maxPullPages = 20,
    this.deleteAllSyncTimeout = const Duration(seconds: 5),
    bool observeLifecycle = true,
  }) : _remote = remote,
       _currentUidOverride = currentUid,
       _openDatabase = openDatabase ?? HistoryDatabase.forUid,
       _documentsDir = documentsDir ?? _defaultDocumentsDir,
       _extractLegacyText =
           extractLegacyText ?? FileService().extractTextFromPath,
       _clock = clock {
    if (observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  final SavedTextsRemoteStore? _remote;
  final String? Function()? _currentUidOverride;
  final Future<Database> Function(String uid) _openDatabase;
  final Future<String> Function() _documentsDir;
  final Future<String?> Function(String, String) _extractLegacyText;
  final DateTime Function()? _clock;

  /// A request without a server answer in this time counts as offline.
  final Duration requestTimeout;
  final Duration retryBase;
  final Duration retryMax;

  /// Upper bound of server pages read per pull.
  final int maxPullPages;

  /// How long «Избриши сè» waits for server changes before deleting.
  final Duration deleteAllSyncTimeout;

  bool _observing = false;
  bool _disposed = false;
  int _generation = 0;
  _Session? _session;
  final Map<String, Future<void>> _migrationRuns = {};

  String? _uid;
  bool _ready = false;
  bool _loadFailed = false;
  bool _loadingMore = false;
  List<SavedTextSummary> _items = const [];
  bool _hasMore = false;
  String _search = '';
  HistorySort _sort = HistorySort.newest;
  SyncCounts _counts = const SyncCounts();
  int _totalCount = 0;
  LegacyMigrationReport? _migrationReport;
  List<LegacyHistoryEntry> _legacyEntries = const [];
  final Map<String, SavedTextSyncState> _states = {};

  static Future<String> _defaultDocumentsDir() async =>
      (await getApplicationDocumentsDirectory()).path;

  // ------------------------------------------------------------- getters

  String? get uid => _uid;

  /// The History of [uid] is loaded and may be shown.
  bool isReadyFor(String? uid) => _ready && _uid == uid;

  bool get isReady => _ready;
  bool get loadFailed => _loadFailed;
  bool get cloudEnabled => _remote != null;
  List<SavedTextSummary> get items => _items;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  String get search => _search;
  HistorySort get sort => _sort;
  SyncCounts get counts => _counts;

  /// All saved texts of this account on this device, regardless of search.
  int get totalCount => _totalCount;
  LegacyMigrationReport? get migrationReport => _migrationReport;
  List<LegacyHistoryEntry> get legacyEntries => _legacyEntries;
  bool get hasPendingSync => _counts.pending > 0 || _counts.failed > 0;
  bool get isSyncing => _session?.syncing ?? false;

  SavedTextsSyncStatus get syncStatus {
    final session = _session;
    if (session == null || _remote == null) {
      return SavedTextsSyncStatus.localOnly;
    }
    if (_counts.failed > 0 || session.hadFailure) {
      return SavedTextsSyncStatus.failed;
    }
    if (session.offline && _counts.pending > 0) {
      return SavedTextsSyncStatus.waitingForNetwork;
    }
    if (session.syncing || _counts.pending > 0) {
      return SavedTextsSyncStatus.syncing;
    }
    return SavedTextsSyncStatus.idle;
  }

  /// Last known state of an item saved or listed in this session.
  SavedTextSyncState? stateOf(String? id) => id == null ? null : _states[id];

  String? _currentUid() {
    final override = _currentUidOverride;
    if (override != null) return override();
    return FirebaseAuth.instance.currentUser?.uid;
  }

  bool _isCurrent(_Session session) =>
      identical(session, _session) && !session.closed;

  // ------------------------------------------------------- account switch

  /// Clears the visible History at once, then loads [uid]'s saved texts,
  /// migrates its legacy rows and starts syncing. Newer calls win.
  Future<void> switchUser(String? uid) async {
    final generation = ++_generation;
    _session?.close();
    _session = null;
    _uid = uid;
    _ready = uid == null;
    _loadFailed = false;
    _items = const [];
    _hasMore = false;
    _counts = const SyncCounts();
    _totalCount = 0;
    _migrationReport = null;
    _legacyEntries = const [];
    _states.clear();
    _notify();
    if (uid == null) return;

    final _Session session;
    try {
      final db = await _openDatabase(uid);
      if (generation != _generation) return;
      final store = SavedTextsLocalStore(
        db,
        uid: uid,
        documentsDir: _documentsDir,
        clock: _clock,
      );
      final migration = LegacyHistoryMigration(
        db,
        extractText: _extractLegacyText,
        clock: _clock,
      );
      session = _Session(uid, store, migration);
      _session = session;
      await _reload(session);
    } catch (e) {
      debugPrint('[SavedTexts] could not open account storage: $e');
      if (generation != _generation) return;
      _loadFailed = true;
      _ready = true;
      _notify();
      return;
    }
    if (!_isCurrent(session)) return;
    _ready = true;
    _notify();

    await _runMigration(session);
    if (!_isCurrent(session)) return;
    unawaited(
      session.store.cleanupOrphanAttachments().catchError((Object e) {
        debugPrint('[SavedTexts] attachment cleanup failed: $e');
        return 0;
      }),
    );
    _requestSync(session, pull: true);
  }

  Future<void> _runMigration(_Session session) async {
    // One run per account at a time, also across quick A→B→A switches.
    final previous = _migrationRuns[session.uid] ?? Future<void>.value();
    final run = previous.then((_) async {
      if (!_isCurrent(session)) return;
      final report = await session.migration.run();
      final entries = await session.migration.unmigratedEntries();
      if (!_isCurrent(session)) return;
      _migrationReport = report;
      _legacyEntries = entries;
      await _reload(session);
      _notify();
    });
    final guarded = run.catchError((Object e) {
      debugPrint('[SavedTexts] legacy migration failed: $e');
    });
    _migrationRuns[session.uid] = guarded;
    await guarded;
  }

  // ----------------------------------------------------------- list view

  Future<void> _reload(_Session session) async {
    final limit = max(_items.length, SavedTextLimits.localPageSize);
    final page = await session.store.listPage(
      search: _search,
      sort: _sort,
      limit: limit + 1,
    );
    final counts = await session.store.counts();
    final total = await session.store.liveCount();
    if (!_isCurrent(session)) return;
    _hasMore = page.length > limit;
    _items = page.take(limit).toList();
    _counts = counts;
    _totalCount = total;
    for (final item in _items) {
      _states[item.id] = item.syncState;
    }
  }

  Future<void> _reloadAndNotify(_Session session) async {
    try {
      await _reload(session);
    } catch (e) {
      debugPrint('[SavedTexts] reload failed: $e');
    }
    if (_isCurrent(session)) _notify();
  }

  Future<void> loadMore() async {
    final session = _session;
    if (session == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    _notify();
    try {
      const limit = SavedTextLimits.localPageSize;
      final page = await session.store.listPage(
        search: _search,
        sort: _sort,
        offset: _items.length,
        limit: limit + 1,
      );
      if (!_isCurrent(session)) return;
      _hasMore = page.length > limit;
      _items = [..._items, ...page.take(limit)];
      for (final item in page) {
        _states[item.id] = item.syncState;
      }
    } catch (e) {
      debugPrint('[SavedTexts] load more failed: $e');
    } finally {
      if (_isCurrent(session)) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> setSearch(String value) async {
    if (value == _search) return;
    _search = value;
    final session = _session;
    if (session == null) return;
    _items = const [];
    await _reloadAndNotify(session);
  }

  Future<void> setSort(HistorySort value) async {
    if (value == _sort) return;
    _sort = value;
    final session = _session;
    if (session == null) return;
    _items = const [];
    await _reloadAndNotify(session);
  }

  /// Re-reads the list and asks the server for changes.
  Future<void> refresh() async {
    final session = _session;
    if (session == null) return;
    await _reloadAndNotify(session);
    if (_isCurrent(session)) await _sync(session, pull: true);
  }

  // ------------------------------------------------------------ actions

  /// Saves on this device first. The returned outcome means the item and
  /// its queued upload are stored durably; the cloud copy follows later.
  Future<SaveOutcome> save(SaveTextRequest request) async {
    final session = _session;
    if (session == null) {
      return const SaveOutcome(SaveOutcomeKind.unavailable);
    }
    final SaveOutcome outcome;
    try {
      outcome = await session.store.save(request);
    } catch (e) {
      debugPrint('[SavedTexts] save failed: $e');
      return const SaveOutcome(SaveOutcomeKind.unavailable);
    }
    if (!_isCurrent(session)) return outcome;
    final item = outcome.item;
    if (item != null) _states[item.id] = item.syncState;
    if (outcome.kind == SaveOutcomeKind.created ||
        outcome.kind == SaveOutcomeKind.updated) {
      await _reloadAndNotify(session);
      _requestSync(session);
    } else {
      _notify();
    }
    return outcome;
  }

  Future<SavedText?> load(String id) async {
    final session = _session;
    if (session == null) return null;
    final item = await session.store.get(id);
    return _isCurrent(session) ? item : null;
  }

  Future<bool> delete(String id) async {
    final session = _session;
    if (session == null) return false;
    final deleted = await session.store.delete(id);
    if (!_isCurrent(session)) return deleted;
    _states.remove(id);
    _items = [
      for (final item in _items)
        if (item.id != id) item,
    ];
    _notify();
    await _reloadAndNotify(session);
    _requestSync(session);
    return deleted;
  }

  Future<bool> toggleFavorite(String id) async {
    final session = _session;
    if (session == null) return false;
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    final value = !_items[index].isFavorite;
    _items = [
      for (final item in _items)
        item.id == id ? _withFavorite(item, value) : item,
    ];
    _notify();
    bool changed;
    try {
      changed = await session.store.setFavorite(id, value);
    } catch (e) {
      debugPrint('[SavedTexts] favourite failed: $e');
      changed = false;
    }
    if (!_isCurrent(session)) return changed;
    await _reloadAndNotify(session);
    if (changed) _requestSync(session);
    return changed;
  }

  static SavedTextSummary _withFavorite(SavedTextSummary item, bool value) =>
      SavedTextSummary(
        id: item.id,
        title: item.title,
        source: item.source,
        preview: item.preview,
        hasSimplified: item.hasSimplified,
        createdAt: item.createdAt,
        syncState: item.syncState,
        isFavorite: value,
        attachmentPath: item.attachmentPath,
        attachmentType: item.attachmentType,
      );

  /// «Избриши сè» for [uid], the account the user confirmed for. Works
  /// offline: tombstones are stored first and uploaded when possible. When
  /// online, server changes are read briefly beforehand so items from
  /// other devices are deleted too. Returns the number of deleted items,
  /// or null if nothing was done.
  Future<int?> deleteAll({required String uid}) async {
    final session = _session;
    if (session == null || session.uid != uid) return null;
    if (_remote != null && _currentUid() == uid) {
      try {
        await _sync(session, pull: true).timeout(deleteAllSyncTimeout);
      } catch (e) {
        debugPrint('[SavedTexts] sync before delete-all skipped: $e');
      }
      if (!_isCurrent(session)) return null;
    }
    final int count;
    try {
      count = await session.store.deleteAll();
    } catch (e) {
      debugPrint('[SavedTexts] delete-all failed: $e');
      return null;
    }
    if (!_isCurrent(session)) return count;
    _states.clear();
    _items = const [];
    _hasMore = false;
    try {
      final entries = await session.migration.unmigratedEntries();
      final report = await session.migration.report();
      if (_isCurrent(session)) {
        _legacyEntries = entries;
        _migrationReport = report;
      }
    } catch (e) {
      debugPrint('[SavedTexts] legacy refresh failed: $e');
    }
    await _reloadAndNotify(session);
    _requestSync(session);
    return count;
  }

  /// Sends rejected and waiting changes again, now.
  Future<void> retrySync() async {
    final session = _session;
    if (session == null) return;
    await session.store.clearDeniedErrors();
    if (!_isCurrent(session)) return;
    session.backoffStep = 0;
    session.hadFailure = false;
    session.retryTimer?.cancel();
    await _reloadAndNotify(session);
    await _sync(session, pull: true);
  }

  /// Tries to send queued changes before sign-out. Unsent changes stay on
  /// this device for this account.
  Future<bool> flushPendingSync({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final session = _session;
    if (session == null || _remote == null) return true;
    try {
      await _sync(session).timeout(timeout);
    } on TimeoutException {
      debugPrint('[SavedTexts] flush before sign-out timed out');
    }
    return !hasPendingSync;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = _session;
    if (state == AppLifecycleState.resumed && session != null) {
      session.backoffStep = 0;
      _requestSync(session, pull: true);
    }
  }

  // --------------------------------------------------------------- sync

  void _requestSync(_Session session, {bool pull = false}) {
    if (_remote == null || !_isCurrent(session)) return;
    unawaited(_sync(session, pull: pull));
  }

  /// Single-flight: a request during a running pass runs one more pass.
  Future<void> _sync(_Session session, {bool pull = false}) async {
    if (_remote == null || !_isCurrent(session)) return;
    if (session.syncing) {
      session.rerun = true;
      session.rerunPull |= pull;
      return;
    }
    session.syncing = true;
    session.retryTimer?.cancel();
    _notify();
    try {
      var doPull = pull;
      do {
        session.rerun = false;
        session.rerunPull = false;
        final pushed = await _push(session);
        if (!_isCurrent(session)) return;
        if (doPull && pushed) await _pull(session);
        doPull = session.rerunPull;
      } while (session.rerun && _isCurrent(session));
    } catch (e) {
      debugPrint('[SavedTexts] sync pass failed: $e');
    } finally {
      session.syncing = false;
      if (_isCurrent(session)) {
        await _reloadAndNotify(session);
        _scheduleRetryIfNeeded(session);
      }
    }
  }

  /// Sends queued changes oldest first. Returns false when it stopped
  /// because the server could not be reached.
  Future<bool> _push(_Session session) async {
    final remote = _remote!;
    final changes = await session.store.pendingChanges();
    var progressed = false;
    session.hadFailure = false;
    for (final change in changes) {
      if (!_isCurrent(session)) return false;
      // Only send while this account is the signed-in one; the path below
      // always uses the uid captured when the session started.
      if (_currentUid() != session.uid) return false;
      final commit = await session.store.beginUpload(change);
      if (commit == null) continue;
      try {
        final result = await remote
            .commit(session.uid, commit)
            .timeout(requestTimeout);
        if (result.alreadyDeleted) {
          await session.store.applyServerDeletion(change.id, result.revision);
        } else {
          await session.store.acknowledge(change, result.revision);
        }
        session.offline = false;
        session.backoffStep = 0;
        progressed = true;
        if (_isCurrent(session)) {
          final state = await session.store.syncStateOf(change.id);
          if (state == null) {
            _states.remove(change.id);
          } else {
            _states[change.id] = state;
          }
          _notify();
        }
      } catch (e) {
        final kind = _errorKind(e);
        debugPrint('[SavedTexts] upload failed: $e');
        if (kind == SavedTextsRemoteErrorKind.offline) {
          await session.store.markError(change.id, SyncErrorCodes.offline);
          session.offline = true;
          return false;
        }
        session.hadFailure = true;
        await session.store.markError(
          change.id,
          kind == SavedTextsRemoteErrorKind.denied
              ? SyncErrorCodes.denied
              : SyncErrorCodes.failed,
        );
        if (_isCurrent(session)) {
          _states[change.id] = SavedTextSyncState.failed;
          _notify();
        }
      }
    }
    if (progressed && _isCurrent(session)) await _reloadAndNotify(session);
    return true;
  }

  /// Reads server changes since the stored cursor in bounded pages.
  Future<void> _pull(_Session session) async {
    final remote = _remote!;
    var changed = false;
    try {
      for (var page = 0; page < maxPullPages; page++) {
        if (!_isCurrent(session) || _currentUid() != session.uid) return;
        final cursor = await session.store.readCursor();
        final result = await remote
            .fetchChanges(session.uid, cursor, SavedTextLimits.remotePageSize)
            .timeout(requestTimeout);
        // A page for a closed session is dropped, not merged.
        if (!_isCurrent(session)) return;
        changed |= await session.store.applyRemotePage(result);
        session.offline = false;
        if (result.next == null ||
            result.items.length < SavedTextLimits.remotePageSize) {
          break;
        }
      }
    } catch (e) {
      debugPrint('[SavedTexts] pull failed: $e');
      if (_errorKind(e) == SavedTextsRemoteErrorKind.offline) {
        session.offline = true;
      } else {
        session.hadFailure = true;
      }
    }
    if (changed && _isCurrent(session)) await _reloadAndNotify(session);
  }

  void _scheduleRetryIfNeeded(_Session session) {
    final waiting = _counts.pending > 0 && session.offline;
    final failed = session.hadFailure;
    if (!waiting && !failed) {
      session.backoffStep = 0;
      return;
    }
    final factor = 1 << min(session.backoffStep, 10);
    final delay = Duration(
      milliseconds: min(
        retryBase.inMilliseconds * factor,
        retryMax.inMilliseconds,
      ),
    );
    session.backoffStep++;
    session.retryTimer?.cancel();
    session.retryTimer = Timer(delay, () {
      if (_isCurrent(session)) unawaited(_sync(session, pull: true));
    });
  }

  static SavedTextsRemoteErrorKind _errorKind(Object error) {
    if (error is TimeoutException) return SavedTextsRemoteErrorKind.offline;
    if (error is SavedTextsRemoteException) return error.kind;
    return SavedTextsRemoteErrorKind.failed;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session?.close();
    _session = null;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
