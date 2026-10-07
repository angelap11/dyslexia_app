import 'dart:ui' show TextRange;

import 'package:dyslexia_app/core/app_settings.dart';
import 'package:dyslexia_app/core/word_focus_selection.dart';
import 'package:flutter_test/flutter_test.dart';

String _slice(String text, TextRange? range) =>
    range == null ? '<null>' : text.substring(range.start, range.end);

void main() {
  group('wordFocusRangeAt', () {
    test('selects the whole token under the offset', () {
      const text = 'Ова е куќа.';
      final range = wordFocusRangeAt(text, text.indexOf('ќ'));
      expect(range, const TextRange(start: 6, end: 11));
      expect(_slice(text, range), 'куќа.');
    });

    test('repeated words are separate occurrences by offset', () {
      const text = 'мама и мама';
      final first = wordFocusRangeAt(text, 1);
      final second = wordFocusRangeAt(text, text.lastIndexOf('мама') + 1);

      expect(first, const TextRange(start: 0, end: 4));
      expect(second, const TextRange(start: 7, end: 11));
      expect(first, isNot(second));
      expect(toggleWordFocus(first, second!), second);
    });

    test('handles Macedonian Cyrillic letters ѓ ќ љ њ џ ѕ', () {
      const text = 'Ѓорѓи, ќерка, љубов, њива, џеб, ѕвезда!';
      const expected = [
        'Ѓорѓи,',
        'ќерка,',
        'љубов,',
        'њива,',
        'џеб,',
        'ѕвезда!',
      ];
      for (final token in expected) {
        final start = text.indexOf(token);
        expect(_slice(text, wordFocusRangeAt(text, start)), token);
        expect(
          _slice(text, wordFocusRangeAt(text, start + token.length - 1)),
          token,
        );
      }
    });

    test('keeps Macedonian quotes and punctuation attached to the word', () {
      const text = '„Здраво“, рече таа… Дали дојде?';
      expect(_slice(text, wordFocusRangeAt(text, 0)), '„Здраво“,');
      expect(_slice(text, wordFocusRangeAt(text, 3)), '„Здраво“,');
      expect(_slice(text, wordFocusRangeAt(text, text.indexOf('таа'))), 'таа…');
      expect(
        _slice(text, wordFocusRangeAt(text, text.indexOf('дојде'))),
        'дојде?',
      );
    });

    test('paragraph breaks separate words', () {
      const text = 'Прв ред.\n\nВтор пасус';
      expect(
        _slice(text, wordFocusRangeAt(text, text.indexOf('Втор'))),
        'Втор',
      );
      expect(_slice(text, wordFocusRangeAt(text, 4)), 'ред.');
    });

    test('returns null for whitespace, standalone punctuation and bounds', () {
      const text = 'Еден — два';
      expect(wordFocusRangeAt(text, 4), isNull);
      expect(wordFocusRangeAt(text, text.indexOf('—')), isNull);
      expect(wordFocusRangeAt(text, -1), isNull);
      expect(wordFocusRangeAt(text, text.length), isNull);
      expect(wordFocusRangeAt('', 0), isNull);
    });
  });

  group('wordFocusRangeForCaret', () {
    test('caret right after a word resolves to that word', () {
      const text = 'мама и тато';
      expect(_slice(text, wordFocusRangeForCaret(text, 4)), 'мама');
      expect(_slice(text, wordFocusRangeForCaret(text, text.length)), 'тато');
    });

    test('caret at a word start resolves to that word', () {
      const text = 'мама и тато';
      expect(_slice(text, wordFocusRangeForCaret(text, 7)), 'тато');
    });
  });

  group('toggleWordFocus', () {
    const word = TextRange(start: 0, end: 4);
    const other = TextRange(start: 7, end: 11);

    test('tapping the focused word clears focus', () {
      expect(toggleWordFocus(word, word), isNull);
    });

    test('tapping another word moves focus', () {
      expect(toggleWordFocus(word, other), other);
      expect(toggleWordFocus(null, word), word);
    });
  });

  test('isWordFocusRangeValid rejects ranges outside changed text', () {
    const range = TextRange(start: 7, end: 11);
    expect(isWordFocusRangeValid(range, 'мама и мама'), isTrue);
    expect(isWordFocusRangeValid(range, 'мама'), isFalse);
    expect(isWordFocusRangeValid(null, 'мама'), isFalse);
    expect(
      isWordFocusRangeValid(const TextRange.collapsed(2), 'мама'),
      isFalse,
    );
  });

  group('retired global word focus setting', () {
    test('old saved keys are ignored and other settings survive', () {
      final restored = AppSettings.fromMap(const {
        'fontScale': 1.2,
        'dyslexiaFont': false,
        'darkMode': true,
        'readingRulerEnabled': true,
        'speechRate': 0.8,
        'wordFocusEnabled': true,
        'wordFocusBlur': 'stronger',
      });

      expect(restored.fontScale, 1.2);
      expect(restored.dyslexiaFont, isFalse);
      expect(restored.darkMode, isTrue);
      expect(restored.readingRulerEnabled, isTrue);
      expect(restored.speechRate, 0.8);
    });

    test('word focus is no longer persisted', () {
      final map = AppSettings.defaults.toMap();
      for (final key in AppSettings.retiredKeys) {
        expect(map.containsKey(key), isFalse);
      }
    });
  });
}
