import 'dart:async';

import 'package:dyslexia_app/features/settings/preferences_remote_store.dart';
import 'package:dyslexia_app/features/settings/settings_local_store.dart';

/// Device settings storage kept in memory, scoped like the Hive store.
class MemorySettingsLocalStore implements SettingsLocalStore {
  final Map<String?, Map<String, Object?>> values = {};
  final Map<String, Set<String>> pending = {};

  /// Simulates slow device storage when set.
  Completer<void>? readGate;

  @override
  Future<Map<String, Object?>> read(String? uid) async {
    final gate = readGate;
    if (gate != null) await gate.future;
    return Map.of(values[uid] ?? const {});
  }

  @override
  Future<void> write(String? uid, Map<String, Object?> next) async {
    (values[uid] ??= {}).addAll(next);
  }

  @override
  Future<Set<String>> readPending(String uid) async =>
      Set.of(pending[uid] ?? const <String>{});

  @override
  Future<void> writePending(String uid, Set<String> keys) async {
    pending[uid] = Set.of(keys);
  }
}

class RemoteWrite {
  final String uid;
  final Map<String, Object> fields;
  final bool create;

  RemoteWrite(this.uid, this.fields, {this.create = false});
}

/// Server copy of preferences with manual control over connectivity and
/// acknowledgements, mirroring how Firestore behaves for one client.
class FakePreferencesRemoteStore implements PreferencesRemoteStore {
  final Map<String, Map<String, Object?>> documents = {};
  final List<RemoteWrite> writes = [];
  final Map<String, StreamController<RemotePreferencesSnapshot>> _watchers = {};
  final List<_HeldWrite> _held = [];

  bool online = true;

  /// When false, writes stay unacknowledged until [acknowledgeAll].
  bool autoAcknowledge = true;

  /// Error returned by watch/write calls, e.g. permission-denied.
  PreferencesSyncException? error;

  int get openWatchers => _watchers.values.where((c) => c.hasListener).length;

  @override
  Stream<RemotePreferencesSnapshot> watch(String uid) {
    late StreamController<RemotePreferencesSnapshot> controller;
    controller = StreamController<RemotePreferencesSnapshot>(
      onListen: () {
        final failure = error;
        if (failure != null) {
          controller.addError(failure);
          return;
        }
        _emit(uid, controller, fromCache: true);
        if (online) _emit(uid, controller, fromCache: false);
      },
      onCancel: () {
        if (identical(_watchers[uid], controller)) _watchers.remove(uid);
      },
    );
    _watchers[uid] = controller;
    return controller.stream;
  }

  @override
  Future<void> writeFields(String uid, Map<String, Object> fields) {
    final failure = error;
    if (failure != null) return Future.error(failure);
    writes.add(RemoteWrite(uid, fields));
    final held = _HeldWrite(uid, fields);
    if (online && autoAcknowledge) {
      _apply(held);
      return Future.value();
    }
    _held.add(held);
    return held.completer.future;
  }

  @override
  Future<bool> createIfAbsent(String uid, Map<String, Object> fields) async {
    final failure = error;
    if (failure != null) throw failure;
    if (!online) {
      throw const PreferencesSyncException(
        PreferencesSyncErrorKind.failed,
        'unavailable',
      );
    }
    if (documents.containsKey(uid)) return false;
    writes.add(RemoteWrite(uid, fields, create: true));
    documents[uid] = Map.of(fields);
    _notify(uid);
    return true;
  }

  /// Simulates another device changing the server copy.
  void serverUpdate(String uid, Map<String, Object?> fields) {
    (documents[uid] ??= {}).addAll(fields);
    _notify(uid);
  }

  void goOffline() => online = false;

  /// Reconnects: held writes are delivered in order, listeners get a
  /// server-confirmed snapshot.
  void goOnline() {
    online = true;
    if (autoAcknowledge) acknowledgeAll();
    for (final entry in _watchers.entries) {
      _emit(entry.key, entry.value, fromCache: false);
    }
  }

  void acknowledgeAll() {
    final held = List.of(_held);
    _held.clear();
    for (final write in held) {
      _apply(write);
    }
  }

  int get heldWrites => _held.length;

  void _apply(_HeldWrite write) {
    (documents[write.uid] ??= {}).addAll(write.fields);
    if (!write.completer.isCompleted) write.completer.complete();
    _notify(write.uid);
  }

  void _notify(String uid) {
    final controller = _watchers[uid];
    if (controller != null && online) {
      _emit(uid, controller, fromCache: false);
    }
  }

  void _emit(
    String uid,
    StreamController<RemotePreferencesSnapshot> controller, {
    required bool fromCache,
  }) {
    if (controller.isClosed) return;
    final doc = documents[uid];
    controller.add(
      RemotePreferencesSnapshot(
        exists: doc != null,
        values: Map.of(doc ?? const {}),
        fromCache: fromCache,
      ),
    );
  }
}

class _HeldWrite {
  final String uid;
  final Map<String, Object> fields;
  final Completer<void> completer = Completer<void>();

  _HeldWrite(this.uid, this.fields);
}
