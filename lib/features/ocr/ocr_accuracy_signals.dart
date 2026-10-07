import 'package:flutter/foundation.dart';

/// Lightweight OCR quality signals — not used for dictionary correction.
class OcrAccuracySignals {
  final int rawChars;
  final int tokenCount;
  final int singleCharTokens;
  final double fragRatio;
  final double avgTokenLen;
  final int suspiciousShortPairs;
  final double score;

  const OcrAccuracySignals({
    required this.rawChars,
    required this.tokenCount,
    required this.singleCharTokens,
    required this.fragRatio,
    required this.avgTokenLen,
    required this.suspiciousShortPairs,
    required this.score,
  });
}

/// Score recognition quality without inventing words.
///
/// Higher is better. Penalizes single-character tokens and very short
/// fragments that often indicate false internal spaces / broken words.
OcrAccuracySignals scoreOcrAccuracySignals(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const OcrAccuracySignals(
      rawChars: 0,
      tokenCount: 0,
      singleCharTokens: 0,
      fragRatio: 1,
      avgTokenLen: 0,
      suspiciousShortPairs: 0,
      score: 0,
    );
  }

  final tokens = trimmed
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final singleChar = tokens.where((t) => t.length == 1).length;
  final fragRatio = tokens.isEmpty ? 1.0 : singleChar / tokens.length;
  final avgLen = tokens.isEmpty
      ? 0.0
      : tokens.fold<int>(0, (s, t) => s + t.length) / tokens.length;

  // Adjacent short alphabetic tokens often mean a false split ("Странецо т").
  var suspiciousPairs = 0;
  for (var i = 0; i < tokens.length - 1; i++) {
    final a = tokens[i];
    final b = tokens[i + 1];
    final alpha = RegExp(r'^[\p{L}]+$', unicode: true);
    if (alpha.hasMatch(a) &&
        alpha.hasMatch(b) &&
        ((a.length <= 2 && b.length <= 3) ||
            (a.length >= 4 && b.length == 1))) {
      suspiciousPairs++;
    }
  }

  var score = 1.0;
  score -= (fragRatio * 0.55).clamp(0.0, 0.55);
  if (avgLen < 3.5) score -= 0.2;
  if (avgLen < 4.5) score -= 0.08;
  score -= (suspiciousPairs * 0.04).clamp(0.0, 0.28);
  // Mild length preference only — never decide solely by char count.
  if (trimmed.length < 80) score -= 0.12;
  if (trimmed.length > 200) score += 0.03;

  return OcrAccuracySignals(
    rawChars: trimmed.length,
    tokenCount: tokens.length,
    singleCharTokens: singleChar,
    fragRatio: fragRatio,
    avgTokenLen: avgLen,
    suspiciousShortPairs: suspiciousPairs,
    score: score.clamp(0.0, 1.0),
  );
}

void logOcrAccuracySignals(String label, OcrAccuracySignals s) {
  if (!kDebugMode) return;
  debugPrint(
    '[OCR-COMPARE] $label chars=${s.rawChars} tokens=${s.tokenCount} '
    'fragRatio=${s.fragRatio.toStringAsFixed(3)} '
    'avgTokenLen=${s.avgTokenLen.toStringAsFixed(2)} '
    'suspiciousPairs=${s.suspiciousShortPairs} '
    'score=${s.score.toStringAsFixed(3)}',
  );
}
