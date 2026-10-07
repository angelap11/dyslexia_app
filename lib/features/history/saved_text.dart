import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';

/// Where a saved text came from. The enum name is the stored/cloud value.
enum SavedTextSource { listen, camera, gallery, document, legacy }

SavedTextSource savedTextSourceFrom(String? value) {
  for (final source in SavedTextSource.values) {
    if (source.name == value) return source;
  }
  return SavedTextSource.legacy;
}

/// Per-item synchronization state shown in the UI.
enum SavedTextSyncState {
  /// Saved on this device; waiting to be sent to the account.
  pending,

  /// The server acknowledged the current version.
  synced,

  /// The last attempt failed; the item stays saved on this device.
  failed,

  /// Kept on this device only (larger than the cloud limit).
  deviceOnly,
}

/// Cloud payload limits. firestore.rules enforces the same numbers.
class SavedTextLimits {
  SavedTextLimits._();

  /// UTF-8 bytes per text field. Two full fields plus metadata stay well
  /// under Firestore's 1 MiB document limit.
  static const int maxTextBytes = 200 * 1024;
  static const int maxTitleChars = 120;
  static const int defaultTitleChars = 48;

  /// Rows per History page on screen.
  static const int localPageSize = 30;

  /// Documents per Firestore query page (rules allow at most 100).
  static const int remotePageSize = 50;

  static int utf8Bytes(String value) => utf8.encode(value).length;

  static bool fitsCloud(String originalText, String? simplifiedText) {
    if (utf8Bytes(originalText) > maxTextBytes) return false;
    final simplified = simplifiedText;
    return simplified == null || utf8Bytes(simplified) <= maxTextBytes;
  }

  static String formatKb(int bytes) => '${(bytes / 1024).ceil()} KB';
}

/// One History item as stored on this device.
class SavedText {
  final String id;
  final String title;
  final SavedTextSource source;
  final String originalText;
  final String? simplifiedText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SavedTextSyncState syncState;
  final bool isFavorite;

  /// Local-only attachment (scanned photo or picked document).
  final String? attachmentPath;
  final String? attachmentType;

  const SavedText({
    required this.id,
    required this.title,
    required this.source,
    required this.originalText,
    required this.simplifiedText,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    this.isFavorite = false,
    this.attachmentPath,
    this.attachmentType,
  });

  bool get hasSimplified =>
      simplifiedText != null && simplifiedText!.trim().isNotEmpty;
}

/// Row for the History list; the full text is loaded when opened.
class SavedTextSummary {
  final String id;
  final String title;
  final SavedTextSource source;
  final String preview;
  final bool hasSimplified;
  final DateTime createdAt;
  final SavedTextSyncState syncState;
  final bool isFavorite;
  final String? attachmentPath;
  final String? attachmentType;

  const SavedTextSummary({
    required this.id,
    required this.title,
    required this.source,
    required this.preview,
    required this.hasSimplified,
    required this.createdAt,
    required this.syncState,
    this.isFavorite = false,
    this.attachmentPath,
    this.attachmentType,
  });
}

/// Attachment to keep on this device with a new item.
class SaveAttachment {
  final String type;
  final String extension;
  final String? sourcePath;
  final List<int>? bytes;

  const SaveAttachment.file({
    required this.type,
    required this.extension,
    required String path,
  }) : sourcePath = path,
       bytes = null;

  const SaveAttachment.bytes({
    required this.type,
    required this.extension,
    required List<int> data,
  }) : sourcePath = null,
       bytes = data;
}

/// What a screen asks to save. [id] is generated once per item by the
/// screen and reused for every retry of the same save.
class SaveTextRequest {
  final String id;
  final String? title;
  final SavedTextSource source;
  final String originalText;
  final String? simplifiedText;
  final SaveAttachment? attachment;

  const SaveTextRequest({
    required this.id,
    required this.title,
    required this.source,
    required this.originalText,
    this.simplifiedText,
    this.attachment,
  });
}

class SavedTextIds {
  SavedTextIds._();

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static final Random _random = Random.secure();

  /// 20 random characters, like Firestore auto IDs.
  static String generate() => String.fromCharCodes(
    List.generate(
      20,
      (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
    ),
  );

  static final RegExp _valid = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

  static bool isValid(String id) => _valid.hasMatch(id);
}

class SavedTextTitles {
  SavedTextTitles._();

  /// First words of the text, or the date when the text has no words.
  static String defaultTitle(String text, DateTime at) {
    final words = text.trim().split(RegExp(r'\s+'));
    final buffer = StringBuffer();
    for (final word in words) {
      if (word.isEmpty) continue;
      final next = buffer.isEmpty ? word : '$buffer $word';
      if (next.runes.length > SavedTextLimits.defaultTitleChars) {
        if (buffer.isEmpty) {
          return '${String.fromCharCodes(word.runes.take(SavedTextLimits.defaultTitleChars))}…';
        }
        return '$buffer…';
      }
      buffer
        ..clear()
        ..write(next);
    }
    if (buffer.isNotEmpty) return buffer.toString();
    return 'Текст од ${DateFormat('dd.MM.yyyy').format(at)}';
  }

  /// Trimmed title, or the default. Returns null when the given title is
  /// longer than allowed (the UI limits input, so this is never silent).
  static String? resolve(String? title, String text, DateTime at) {
    final trimmed = (title ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return defaultTitle(text, at);
    if (trimmed.runes.length > SavedTextLimits.maxTitleChars) return null;
    return trimmed;
  }
}
