import 'package:flutter/foundation.dart';

/// One OCR text line with optional bounding box (image coordinates).
class OcrTextLine {
  final String text;
  final int left;
  final int top;
  final int right;
  final int bottom;

  const OcrTextLine({
    required this.text,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  int get height => (bottom - top).clamp(0, 100000);
  bool get hasBox => right > left && bottom > top;

  factory OcrTextLine.fromMap(Map<dynamic, dynamic> map) {
    return OcrTextLine(
      text: (map['text'] ?? '').toString(),
      left: _asInt(map['left']),
      top: _asInt(map['top']),
      right: _asInt(map['right']),
      bottom: _asInt(map['bottom']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

/// Native recognition payload: raw UTF-8 text plus optional line boxes.
class OcrRecognitionResult {
  final String rawText;
  final List<OcrTextLine> lines;

  const OcrRecognitionResult({required this.rawText, this.lines = const []});

  bool get hasLayout => lines.length >= 2 && lines.every((l) => l.hasBox);
}

/// Rebuilds readable text from OCR output.
///
/// Spatial/bbox reconstruction is disabled — sorting lines by boxes scrambled
/// Macedonian reading order. Always preserves Tesseract order via
/// [normalizeOcrLineBreaks] only.
String reconstructOcrText({
  required String rawText,
  List<OcrTextLine> lines = const [],
}) {
  _layoutLog(
    '[OCR-LAYOUT] spatial_reconstruction=disabled fallback=plain_text',
  );
  return normalizeOcrLineBreaks(rawText);
}

/// Paragraph-aware reconstruction using vertical gaps between line boxes.
@visibleForTesting
String reconstructOcrTextFromLines(List<OcrTextLine> lines) {
  final sorted = [...lines]
    ..sort((a, b) {
      final dy = a.top.compareTo(b.top);
      if (dy != 0) return dy;
      return a.left.compareTo(b.left);
    });

  final heights = sorted.map((l) => l.height).where((h) => h > 0).toList();
  final medianHeight = _median(heights).round().clamp(1, 10000);

  final gaps = <int>[];
  for (var i = 1; i < sorted.length; i++) {
    gaps.add(sorted[i].top - sorted[i - 1].bottom);
  }

  // Normal wrap spacing = median of *small* gaps only. Including paragraph
  // gaps in the median would inflate the threshold and flatten the page.
  final wrapCandidates = gaps
      .where((g) => g > 0 && g < medianHeight * 0.75)
      .toList();
  final normalGap = wrapCandidates.isEmpty
      ? (medianHeight * 0.35).round()
      : _median(wrapCandidates).round();

  final byNormal = (normalGap * 1.7).round();
  final byHeight = (medianHeight * 0.75).round();
  final paragraphThreshold = byNormal > byHeight ? byNormal : byHeight;

  _layoutLog('[OCR-LAYOUT] normalGap=$normalGap');
  _layoutLog('[OCR-LAYOUT] paragraphThreshold=$paragraphThreshold');
  _layoutLog('[OCR-LAYOUT] medianLineHeight=$medianHeight');

  final paragraphs = <String>[];
  final buffer = StringBuffer();
  OcrTextLine? previous;

  for (final line in sorted) {
    final text = line.text.trim();
    if (text.isEmpty) continue;

    if (buffer.isEmpty || previous == null) {
      buffer.write(text);
      previous = line;
      continue;
    }

    final gap = line.top - previous.bottom;
    final indentDelta = line.left - previous.left;
    final isParagraph =
        gap >= paragraphThreshold ||
        (indentDelta >= medianHeight && gap >= (normalGap * 0.85).round());

    _layoutLog('[OCR-LAYOUT] lineGap=$gap');
    _layoutLog('[OCR-LAYOUT] decision=${isParagraph ? "paragraph" : "wrap"}');

    if (isParagraph) {
      paragraphs.add(_collapseHorizontal(buffer.toString()));
      buffer
        ..clear()
        ..write(text);
    } else {
      _appendVisualWrap(buffer, text);
    }
    previous = line;
  }

  if (buffer.isNotEmpty) {
    paragraphs.add(_collapseHorizontal(buffer.toString()));
  }

  _layoutLog('[OCR-LAYOUT] detectedParagraphs=${paragraphs.length}');
  return paragraphs.join('\n\n').trim();
}

/// Post-processes plain OCR text when line bounding boxes are unavailable.
///
/// * Single `\n` → visual wrap (space), with safe mid-word fragment joining
/// * `\n\n` (or more) → real paragraph, unless it is a false blank line
/// * Hyphenated wraps joined without inventing characters
String normalizeOcrLineBreaks(String text) {
  if (text.trim().isEmpty) {
    return text.trim();
  }

  var result = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  result = _collapseFalseParagraphBreaks(result);
  result = _joinHyphenatedWraps(result);
  result = _wrapNewlinesPreservingParagraphs(result);
  result = result.split('\n').map(_collapseHorizontal).join('\n');
  return result.trim();
}

/// Blank lines that split mid-word fragments are treated as wraps.
///
/// Collapses only when the left side ends with a short alphabetic fragment
/// (≤3 letters, no sentence punctuation) and the right side continues in
/// lowercase — never invents characters.
String _collapseFalseParagraphBreaks(String text) {
  final paragraphs = text.split(RegExp(r'\n{2,}'));
  if (paragraphs.length < 2) return text;

  final merged = <String>[];
  var current = paragraphs.first;

  for (var i = 1; i < paragraphs.length; i++) {
    final next = paragraphs[i];
    if (_isFalseParagraphBreak(current, next)) {
      // Soft wrap between fragment lines — single newline for the wrap joiner.
      current = '${current.trimRight()}\n${next.trimLeft()}';
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);
  return merged.join('\n\n');
}

bool _isFalseParagraphBreak(String left, String right) {
  final leftTrim = left.trimRight();
  final rightTrim = right.trimLeft();
  if (leftTrim.isEmpty || rightTrim.isEmpty) return false;

  final endChar = leftTrim[leftTrim.length - 1];
  if (_isSentenceEndChar(endChar)) return false;

  final startChar = rightTrim[0];
  if (!_isLowerLetter(startChar)) return false;

  final tokens = leftTrim
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return false;

  final last = tokens.last.replaceAll(RegExp(r'[^\p{L}]+$', unicode: true), '');
  // Only collapse when the previous line ends on a short fragment.
  return last.isNotEmpty && last.length <= 3;
}

bool _isSentenceEndChar(String ch) {
  return ch == '.' ||
      ch == '!' ||
      ch == '?' ||
      ch == '…' ||
      ch == ':' ||
      ch == '»' ||
      ch == '"' ||
      ch == '”';
}

bool _isLowerLetter(String ch) {
  if (ch.isEmpty) return false;
  // Prefer Unicode lowercase class; fall back to case round-trip for Cyrillic.
  if (RegExp(r'^\p{Ll}$', unicode: true).hasMatch(ch)) return true;
  final lower = ch.toLowerCase();
  final upper = ch.toUpperCase();
  return lower == ch &&
      upper != ch &&
      RegExp(r'^\p{L}$', unicode: true).hasMatch(ch);
}

/// Hyphen at end of a visual line:
/// * short remainder (`пред-\nвид`, `македонски-\nте`) → one word
/// * longer next token (`македонски-\nтекст`) → two words, hyphen dropped
String _joinHyphenatedWraps(String text) {
  final pattern = RegExp(r'(\p{L})-\s*\n+\s*(\p{L}+)', unicode: true);

  var result = text;
  while (pattern.hasMatch(result)) {
    result = result.replaceAllMapped(pattern, (match) {
      final stem = match[1]!;
      final rest = match[2]!;
      if (rest.length <= 4) {
        return '$stem$rest';
      }
      return '$stem $rest';
    });
  }
  return result;
}

/// Blank lines mark paragraphs; other newlines are visual wraps.
///
/// Short alphabetic fragments split across a wrap (without a hyphen) are
/// rejoined without a space only when safe — e.g. `с\nтепа` → `степа`.
/// Standalone Macedonian one-letter words (`е`, `и`, …) keep a space.
String _wrapNewlinesPreservingParagraphs(String text) {
  const paragraphMark = '\u0000';
  var result = text.replaceAll(RegExp(r'\n{2,}'), paragraphMark);

  final parts = result.split(paragraphMark);
  final rebuilt = parts.map(_joinVisualWrapLines).join('\n\n');
  return rebuilt;
}

String _joinVisualWrapLines(String paragraph) {
  final lines = paragraph
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return '';
  if (lines.length == 1) return lines.first;

  final buffer = StringBuffer(lines.first);
  for (var i = 1; i < lines.length; i++) {
    _appendVisualWrap(buffer, lines[i]);
  }
  return buffer.toString();
}

void _appendVisualWrap(StringBuffer buffer, String nextLine) {
  final current = buffer.toString();
  final hyphen = RegExp(r'(\p{L})-\s*$', unicode: true).firstMatch(current);
  final nextWord = RegExp(r'^(\p{L}+)', unicode: true).firstMatch(nextLine);

  if (hyphen != null && nextWord != null) {
    final rest = nextWord.group(1)!;
    final after = nextLine.substring(rest.length).trimLeft();
    final withoutHyphen = current.replaceFirst(RegExp(r'-\s*$'), '');
    buffer
      ..clear()
      ..write(withoutHyphen);
    if (rest.length <= 4) {
      buffer.write(rest);
    } else {
      buffer
        ..write(' ')
        ..write(rest);
    }
    if (after.isNotEmpty) {
      buffer
        ..write(' ')
        ..write(after);
    }
    return;
  }

  // Soft mid-word wrap without hyphen: "Цел с" + "тепа" → "Цел степа".
  if (_shouldJoinWrapFragments(current, nextLine)) {
    final trimmedNext = nextLine.trimLeft();
    buffer.write(trimmedNext);
    return;
  }

  buffer
    ..write(' ')
    ..write(nextLine);
}

/// Safe fragment join across a former visual newline (never invents letters).
bool _shouldJoinWrapFragments(String current, String nextLine) {
  final left = RegExp(r'(\p{L}+)\s*$', unicode: true).firstMatch(current);
  final right = RegExp(
    r'^(\p{L}+)',
    unicode: true,
  ).firstMatch(nextLine.trimLeft());
  if (left == null || right == null) return false;

  final a = left.group(1)!;
  final b = right.group(1)!;
  final bStart = b[0];

  // New sentence / proper name — keep separated.
  if (!_isLowerLetter(bStart)) return false;

  const singleLetterWords = {'е', 'и', 'а', 'о', 'у'};
  if (a.length == 1 && singleLetterWords.contains(a.toLowerCase())) {
    return false;
  }

  // Only rejoin when BOTH sides look like fragments of one token.
  // Do not glue a lone letter onto a long word ("к" + "треба") — that is
  // often an OCR substitution error, not a wrap.
  if (a.length <= 2 && b.length <= 2) return true;

  return false;
}

String _collapseHorizontal(String text) {
  return text.replaceAll(RegExp(r'[^\S\n]+'), ' ').trim();
}

double _median(List<num> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[mid].toDouble();
  }
  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

void _layoutLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
