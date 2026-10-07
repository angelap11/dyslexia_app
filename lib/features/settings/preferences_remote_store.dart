import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_settings.dart';

enum PreferencesSyncErrorKind {
  /// Sync is not set up for this project (no database, rules deny access).
  unavailable,

  /// A temporary or unexpected failure; retrying may succeed.
  failed,
}

class PreferencesSyncException implements Exception {
  final PreferencesSyncErrorKind kind;
  final String code;
  final String? message;

  const PreferencesSyncException(this.kind, this.code, [this.message]);

  @override
  String toString() => 'PreferencesSyncException($kind, $code, $message)';
}

class RemotePreferencesSnapshot {
  final bool exists;

  /// Synced keys only; unknown remote fields are dropped.
  final Map<String, Object?> values;

  /// True when served from the local cache, i.e. not confirmed by the server.
  final bool fromCache;
  final bool hasPendingWrites;

  const RemotePreferencesSnapshot({
    required this.exists,
    required this.values,
    required this.fromCache,
    this.hasPendingWrites = false,
  });
}

/// Remote copy of one account's reading preferences.
abstract class PreferencesRemoteStore {
  Stream<RemotePreferencesSnapshot> watch(String uid);

  /// Merges [fields] into the document. Completes only after the server
  /// acknowledges the write.
  Future<void> writeFields(String uid, Map<String, Object> fields);

  /// Creates the document from [fields] only if the server has none.
  /// Returns whether this call created it.
  Future<bool> createIfAbsent(String uid, Map<String, Object> fields);
}

/// `users/{uid}/settings/preferences` in Cloud Firestore.
class FirestorePreferencesRemoteStore implements PreferencesRemoteStore {
  static const int schemaVersion = 1;

  final FirebaseFirestore _firestore;

  FirestorePreferencesRemoteStore(this._firestore);

  /// Returns null when Firestore cannot be used in this build/environment.
  static PreferencesRemoteStore? tryCreate() {
    try {
      return FirestorePreferencesRemoteStore(FirebaseFirestore.instance);
    } catch (e) {
      debugPrint('[SettingsSync] Firestore unavailable: $e');
      return null;
    }
  }

  @visibleForTesting
  DocumentReference<Map<String, dynamic>> docFor(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('preferences');

  @override
  Stream<RemotePreferencesSnapshot> watch(String uid) {
    return docFor(uid)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final data = snapshot.data() ?? const <String, dynamic>{};
          return RemotePreferencesSnapshot(
            exists: snapshot.exists,
            values: {
              for (final key in AppSettings.syncedKeys)
                if (data.containsKey(key)) key: data[key],
            },
            fromCache: snapshot.metadata.isFromCache,
            hasPendingWrites: snapshot.metadata.hasPendingWrites,
          );
        })
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.addError(_mapError(error), stackTrace),
          ),
        );
  }

  @override
  Future<void> writeFields(String uid, Map<String, Object> fields) async {
    try {
      await docFor(uid).set(_withMetadata(fields), SetOptions(merge: true));
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<bool> createIfAbsent(String uid, Map<String, Object> fields) async {
    final ref = docFor(uid);
    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (snapshot.exists) return false;
        transaction.set(ref, _withMetadata(fields));
        return true;
      });
    } catch (e) {
      throw _mapError(e);
    }
  }

  Map<String, Object> _withMetadata(Map<String, Object> fields) => {
    ...fields,
    'schemaVersion': schemaVersion,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Object _mapError(Object error) {
    if (error is PreferencesSyncException) return error;
    if (error is FirebaseException) {
      const unavailableCodes = {
        'permission-denied',
        'not-found',
        'failed-precondition',
        'unimplemented',
      };
      return PreferencesSyncException(
        unavailableCodes.contains(error.code)
            ? PreferencesSyncErrorKind.unavailable
            : PreferencesSyncErrorKind.failed,
        error.code,
        error.message,
      );
    }
    return PreferencesSyncException(
      PreferencesSyncErrorKind.failed,
      'unknown',
      '$error',
    );
  }
}
