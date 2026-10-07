import 'package:dyslexia_app/features/ocr/ocr_accuracy_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('penalizes false internal splits more than clean text', () {
    final clean = scoreOcrAccuracySignals(
      'Ликот на Мерсо од Странецот на Ками е човек на новото време.',
    );
    final split = scoreOcrAccuracySignals(
      'Ликот на Мерсо од Странецо т на Ками е ч овек на новото време.',
    );
    expect(clean.score, greaterThan(split.score));
    expect(split.suspiciousShortPairs, greaterThan(0));
  });
}
