import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum SavedTextsRemoteErrorKind {
  /// No connection or the server did not answer in time.
  offline,

  /// Rules rejected the request (wrong account, malformed data, no setup).
  denied,

  /// Anything else; retrying later may succeed.
  failed,
}

class SavedTextsRemoteException implements Exception {
  final SavedTextsRemoteErrorKind kind;
  final String code;
  final String? message;

  const SavedTextsRemoteException(this.kind, this.code, [this.message]);

  @override
  String toString() => 'SavedTextsRemoteException($kind, $code, $message)';
}

/// Exact position in the `updatedAt, documentId` order used for pulls.
@immutable
class RemoteCursor {
  final int seconds;
  final int nanoseconds;
  final String id;

  const RemoteCursor(this.seconds, this.nanoseconds, this.id);

  Map<String, Object> toJson() => {'s': seconds, 'n': nanoseconds, 'id': id};

  static RemoteCursor? fromJson(Object? json) {
    if (json is! Map) return null;
    final s = json['s'];
    final n = json['n'];
    final id = json['id'];
    if (s is! int || n is! int || id is! String) return null;
    return RemoteCursor(s, n, id);
  }

  @override
  bool operator ==(Object other) =>
      other is RemoteCursor &&
      other.seconds == seconds &&
      other.nanoseconds == nanoseconds &&
      other.id == id;

  @override
  int get hashCode => Object.hash(seconds, nanoseconds, id);
}

/// One document of `users/{uid}/texts` as read from the server.
class RemoteSavedText {
  final String id;
  final bool deleted;
  final int revision;
  final String title;
  final String source;
  final String originalText;
  final String? simplifiedText;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RemoteCursor cursor;

  const RemoteSavedText({
    required this.id,
    required this.deleted,
    required this.revision,
    required this.title,
    required this.source,
    required this.originalText,
    required this.simplifiedText,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    required this.cursor,
  });
}

class RemotePage {
  final List<RemoteSavedText> items;

  /// Cursor after the last item; null when the page is empty.
  final RemoteCursor? next;

  const RemotePage(this.items, this.next);
}

/// A local change to send. [knownRevision] is the newest server revision
/// this device has seen for the item.
class RemoteCommit {
  final String id;
  final bool delete;
  final String title;
  final String source;
  final String originalText;
  final String? simplifiedText;
  final bool favorite;
  final DateTime createdAt;
  final int knownRevision;

  const RemoteCommit({
    required this.id,
    required this.delete,
    required this.title,
    required this.source,
    required this.originalText,
    required this.simplifiedText,
    this.favorite = false,
    required this.createdAt,
    required this.knownRevision,
  });
}

class RemoteCommitResult {
  final int revision;

  /// The server already has a deletion marker; the local change was not
  /// applied and the item must be deleted locally.
  final bool alreadyDeleted;

  const RemoteCommitResult({
    required this.revision,
    this.alreadyDeleted = false,
  });
}

/// Cloud copy of one account's saved texts: `users/{uid}/texts/{textId}`.
/// Both methods complete only with a server answer.
abstract class SavedTextsRemoteStore {
  Future<RemoteCommitResult> commit(String uid, RemoteCommit change);

  /// Documents changed after [after] in `updatedAt, documentId` order.
  Future<RemotePage> fetchChanges(String uid, RemoteCursor? after, int limit);
}

class FirestoreSavedTextsRemote implements SavedTextsRemoteStore {
  static const int schemaVersion = 1;

  final FirebaseFirestore _firestore;

  FirestoreSavedTextsRemote(this._firestore);

  static SavedTextsRemoteStore? tryCreate() {
    try {
      return FirestoreSavedTextsRemote(FirebaseFirestore.instance);
    } catch (e) {
      debugPrint('[SavedTexts] Firestore unavailable: $e');
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>> _texts(String uid) =>
      _firestore.collection('users').doc(uid).collection('texts');

  @override
  Future<RemoteCommitResult> commit(String uid, RemoteCommit change) async {
    final ref = _texts(uid).doc(change.id);
    try {
      // Transactions need the server, so success means it was acknowledged.
      return await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(ref);
        final current = snapshot.data();
        final serverRevision = (current?['revision'] as num?)?.toInt() ?? 0;
        if (current != null && current['deleted'] == true) {
          return RemoteCommitResult(
            revision: serverRevision,
            alreadyDeleted: true,
          );
        }
        final revision = max(serverRevision, change.knownRevision) + 1;
        final createdAt =
            current?['createdAt'] ?? Timestamp.fromDate(change.createdAt);
        if (change.delete) {
          tx.set(ref, {
            'schemaVersion': schemaVersion,
            'deleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
            'createdAt': createdAt,
            'updatedAt': FieldValue.serverTimestamp(),
            'revision': revision,
          });
        } else {
          tx.set(ref, {
            'schemaVersion': schemaVersion,
            'deleted': false,
            'title': change.title,
            'source': current?['source'] ?? change.source,
            'originalText': change.originalText,
            if (change.simplifiedText != null)
              'simplifiedText': change.simplifiedText,
            'favorite': change.favorite,
            'createdAt': createdAt,
            'updatedAt': FieldValue.serverTimestamp(),
            'revision': revision,
          });
        }
        return RemoteCommitResult(revision: revision);
      }, maxAttempts: 3);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<RemotePage> fetchChanges(
    String uid,
    RemoteCursor? after,
    int limit,
  ) async {
    Query<Map<String, dynamic>> query = _texts(
      uid,
    ).orderBy('updatedAt').orderBy(FieldPath.documentId).limit(limit);
    if (after != null) {
      query = query.startAfter([
        Timestamp(after.seconds, after.nanoseconds),
        after.id,
      ]);
    }
    try {
      final snapshot = await query.get(const GetOptions(source: Source.server));
      final items = <RemoteSavedText>[];
      RemoteCursor? next;
      for (final doc in snapshot.docs) {
        final updated = doc.data()['updatedAt'];
        if (updated is Timestamp) {
          next = RemoteCursor(updated.seconds, updated.nanoseconds, doc.id);
        }
        final parsed = parse(doc.id, doc.data());
        if (parsed != null) items.add(parsed);
      }
      return RemotePage(items, next);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Returns null for documents this version cannot read safely.
  @visibleForTesting
  static RemoteSavedText? parse(String id, Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'];
    final createdAt = data['createdAt'];
    final revision = data['revision'];
    if (updatedAt is! Timestamp || createdAt is! Timestamp) return null;
    if (revision is! num) return null;
    final cursor = RemoteCursor(updatedAt.seconds, updatedAt.nanoseconds, id);
    if (data['deleted'] == true) {
      return RemoteSavedText(
        id: id,
        deleted: true,
        revision: revision.toInt(),
        title: '',
        source: 'legacy',
        originalText: '',
        simplifiedText: null,
        createdAt: createdAt.toDate(),
        updatedAt: updatedAt.toDate(),
        cursor: cursor,
      );
    }
    final title = data['title'];
    final original = data['originalText'];
    final simplified = data['simplifiedText'];
    if (title is! String || original is! String) return null;
    return RemoteSavedText(
      id: id,
      deleted: false,
      revision: revision.toInt(),
      title: title,
      source: data['source'] is String ? data['source'] as String : 'legacy',
      originalText: original,
      simplifiedText: simplified is String ? simplified : null,
      favorite: data['favorite'] == true,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt.toDate(),
      cursor: cursor,
    );
  }

  static SavedTextsRemoteException mapError(Object error) {
    if (error is SavedTextsRemoteException) return error;
    if (error is FirebaseException) {
      const offline = {'unavailable', 'deadline-exceeded', 'aborted'};
      const denied = {
        'permission-denied',
        'unauthenticated',
        'not-found',
        'failed-precondition',
        'invalid-argument',
      };
      final kind = offline.contains(error.code)
          ? SavedTextsRemoteErrorKind.offline
          : denied.contains(error.code)
          ? SavedTextsRemoteErrorKind.denied
          : SavedTextsRemoteErrorKind.failed;
      return SavedTextsRemoteException(kind, error.code, error.message);
    }
    return SavedTextsRemoteException(
      SavedTextsRemoteErrorKind.failed,
      'unknown',
      '$error',
    );
  }
}
