import 'package:dyslexia_app/widgets/ui/reading_ruler_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ruler line height tracks fontSize and height multiplier', (
    tester,
  ) async {
    late double small;
    late double large;
    late double tallerLeading;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            const scaler = TextScaler.linear(1.0);
            small = measureReadingRulerLineHeight(
              style: const TextStyle(fontSize: 16, height: 1.5),
              textScaler: scaler,
            );
            large = measureReadingRulerLineHeight(
              style: const TextStyle(fontSize: 24, height: 1.5),
              textScaler: scaler,
            );
            tallerLeading = measureReadingRulerLineHeight(
              style: const TextStyle(fontSize: 16, height: 2.0),
              textScaler: scaler,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(large, greaterThan(small));
    expect(tallerLeading, greaterThan(small));
    // One line ≈ fontSize * height (within font metric slack).
    expect(small, closeTo(16 * 1.5, 6));
    expect(large, closeTo(24 * 1.5, 8));
  });

  test('snapReadingRulerTop lands on line grid', () {
    expect(
      snapReadingRulerTop(
        top: 16 + 22,
        lineHeight: 40,
        maxTop: 400,
        contentTopInset: 16,
      ),
      16 + 40,
    );
    expect(
      snapReadingRulerTop(
        top: 16 + 10,
        lineHeight: 40,
        maxTop: 400,
        contentTopInset: 16,
      ),
      16,
    );
  });

  testWidgets('text scaler increases measured line height', (tester) async {
    late double base;
    late double scaled;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            const style = TextStyle(fontSize: 17, height: 1.85);
            base = measureReadingRulerLineHeight(
              style: style,
              textScaler: TextScaler.noScaling,
            );
            scaled = measureReadingRulerLineHeight(
              style: style,
              textScaler: const TextScaler.linear(1.3),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(scaled, greaterThan(base));
  });
}
