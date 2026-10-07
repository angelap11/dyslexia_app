import 'package:dyslexia_app/features/tts/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsService.snapToNextWordBoundary', () {
    test('stop inside a word → resumes at next word', () {
      const text = 'Денес е убав ден и времето е сончево.';
      final insideDen = text.indexOf('ден') + 1; // inside "ден"
      final snapped = TtsService.snapToNextWordBoundary(text, insideDen);
      expect(text.substring(snapped), startsWith('и времето'));
    });

    test('stop exactly at word boundary (start of word) → skips that word', () {
      const text = 'Денес е убав ден и времето е сончево.';
      final atDen = text.indexOf('ден');
      final snapped = TtsService.snapToNextWordBoundary(text, atDen);
      expect(text.substring(snapped), startsWith('и'));
    });

    test('stop between words → resumes at next word', () {
      const text = 'Збор   следен збор';
      // Offset on spaces after "Збор"
      final snapped = TtsService.snapToNextWordBoundary(text, 4);
      expect(text.substring(snapped), startsWith('следен'));
    });

    test('stop before punctuation → skips punct and resumes at next word', () {
      const text = 'Прв, втор збор';
      final insidePrv = 1; // inside "Прв"
      final snapped = TtsService.snapToNextWordBoundary(text, insidePrv);
      expect(text.substring(snapped), startsWith('втор'));
    });

    test(
      'stop near sentence end → does not jump back to previous sentence',
      () {
        const text = 'Ова е првата реченица. Ова е втората реченица.';
        final inSecond = text.indexOf('втората') + 2;
        final snapped = TtsService.snapToNextWordBoundary(text, inSecond);
        // Forward only: past "втората" to "реченица."
        expect(text.substring(snapped), startsWith('реченица'));
        expect(snapped, greaterThan(text.indexOf('Ова е втората')));
        // Must not rewind to the first sentence
        expect(snapped, isNot(text.indexOf('Ова е првата')));
      },
    );

    test('stop near end of text → returns end', () {
      const text = 'Крај на текст';
      final insideLast = text.indexOf('текст') + 1;
      final snapped = TtsService.snapToNextWordBoundary(text, insideLast);
      expect(snapped, text.length);
    });

    test('no backward sentence replay from mid second sentence', () {
      const text = 'Прва реченица. Втора реченица овде.';
      final midVtora = text.indexOf('Втора') + 3;
      final snapped = TtsService.snapToNextWordBoundary(text, midVtora);
      expect(snapped, greaterThan(midVtora));
      expect(text.substring(snapped), startsWith('реченица'));
      // Must resume after "Втора", never rewind to index 0 / first sentence
      expect(snapped, greaterThan(text.indexOf('Втора')));
      expect(snapped, isNot(0));
    });

    test('clamps out-of-range offsets', () {
      const text = 'Крај';
      expect(TtsService.snapToNextWordBoundary(text, 100), text.length);
      expect(TtsService.snapToNextWordBoundary(text, -1), 0);
      expect(TtsService.snapToNextWordBoundary('', 5), 0);
    });
  });

  group('TtsService.estimateAbsoluteOffset', () {
    test('maps half audio progress to mid chunk', () {
      final offset = TtsService.estimateAbsoluteOffset(
        chunkBaseOffset: 10,
        chunkLength: 20,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 10),
        textLength: 40,
      );
      expect(offset, 20);
    });

    test('clamps to text length', () {
      final offset = TtsService.estimateAbsoluteOffset(
        chunkBaseOffset: 0,
        chunkLength: 10,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 10),
        textLength: 8,
      );
      expect(offset, 8);
    });

    test('falls back to base when duration unknown', () {
      final offset = TtsService.estimateAbsoluteOffset(
        chunkBaseOffset: 7,
        chunkLength: 20,
        position: const Duration(seconds: 1),
        duration: null,
        textLength: 30,
      );
      expect(offset, 7);
    });
  });
}
