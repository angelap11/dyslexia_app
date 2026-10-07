import 'package:dyslexia_app/features/ocr/ocr_text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeOcrLineBreaks (plain-text fallback)', () {
    test('joins visual wraps inside a paragraph', () {
      expect(
        normalizeOcrLineBreaks(
          'Ова е еден македонски\nтекст кој продолжува нормално во истиот пасус.',
        ),
        'Ова е еден македонски текст кој продолжува нормално во истиот пасус.',
      );
      expect(
        normalizeOcrLineBreaks(
          'Децата учат во\nучилиштето и секој\nден читаат различни\nкниги.',
        ),
        'Децата учат во училиштето и секој ден читаат различни книги.',
      );
      expect(
        normalizeOcrLineBreaks(
          'Неговиот проблем е во\nсфаќањето на таа слобода',
        ),
        'Неговиот проблем е во сфаќањето на таа слобода',
      );
    });

    test('joins hyphenated syllable wraps', () {
      expect(normalizeOcrLineBreaks('пред-\nвид'), 'предвид');
      expect(
        normalizeOcrLineBreaks('македонски-\nте ерминии'),
        'македонските ерминии',
      );
    });

    test('drops wrap hyphen between two full words', () {
      expect(
        normalizeOcrLineBreaks(
          'Ова е еден македонски-\nтекст кој продолжува нормално.',
        ),
        'Ова е еден македонски текст кој продолжува нормално.',
      );
    });

    test('keeps in-word hyphens that are not line wraps', () {
      expect(normalizeOcrLineBreaks('сино-зелена боја'), 'сино-зелена боја');
    });

    test('keeps paragraph breaks from blank lines', () {
      expect(
        normalizeOcrLineBreaks(
          'Ова е првиот пасус.\nОва е неговото продолжение.\n\nОва е вториот пасус.',
        ),
        'Ова е првиот пасус. Ова е неговото продолжение.\n\nОва е вториот пасус.',
      );
      expect(
        normalizeOcrLineBreaks(
          'Првиот пасус завршува тука.\n\nВториот пасус започнува тука.',
        ),
        'Првиот пасус завршува тука.\n\nВториот пасус започнува тука.',
      );
    });

    test('three paragraphs via blank lines', () {
      expect(
        normalizeOcrLineBreaks('Еден\nред.\n\nДва\nред.\n\nТри\nред.'),
        'Еден ред.\n\nДва ред.\n\nТри ред.',
      );
    });

    test('does not correct recognized words', () {
      expect(
        normalizeOcrLineBreaks('македонски-\nте ермини'),
        'македонските ермини',
      );
    });

    test('TTS text keeps paragraph breaks but not visual wraps', () {
      final text = normalizeOcrLineBreaks(
        'Прва реченица што\nсе преломува.\n\nВтора реченица што\nисто се преломува.',
      );
      expect(text.contains('\n\n'), isTrue);
      expect(text.split('\n\n').length, 2);
      expect(text.contains('\n'), isTrue); // only as paragraph separator
      expect(RegExp(r'[^\n]\n[^\n]').hasMatch(text), isFalse);
      expect(
        text,
        'Прва реченица што се преломува.\n\n'
        'Втора реченица што исто се преломува.',
      );
    });

    test('collapses false blank line before lowercase continuation', () {
      expect(
        normalizeOcrLineBreaks(
          'Разбра или не ра\n\nт знае оти Господ не ги тепа правите.',
        ),
        'Разбра или не рат знае оти Господ не ги тепа правите.',
      );
    });

    test('keeps real paragraph before capital / sentence start', () {
      expect(
        normalizeOcrLineBreaks('Ова е првиот пасус.\n\nОва е вториот пасус.'),
        'Ова е првиот пасус.\n\nОва е вториот пасус.',
      );
    });

    test('joins short wrap fragments without inventing letters', () {
      // "ра" + "т" across a wrap → one token; does not invent missing chars.
      expect(normalizeOcrLineBreaks('не ра\nт знае'), 'не рат знае');
    });

    test('does not glue standalone е onto the next word', () {
      expect(
        normalizeOcrLineBreaks('Тоа е\nчовек на патот.'),
        'Тоа е човек на патот.',
      );
    });

    test('regression: photographed paragraph with false blank lines', () {
      const raw =
          'што викаш така. Цел с\n'
          'тепа. Разбра или не ра\n\n'
          'т знае оти Господ не ги\n'
          'тепа правите, ами к\n'
          'треба да викаш, ако си\n'
          'умен и р.';
      final text = normalizeOcrLineBreaks(raw);
      expect(text.contains('\n\n'), isFalse);
      expect(text.contains('не рат знае'), isTrue);
      expect(
        text,
        'што викаш така. Цел с тепа. Разбра или не рат знае оти '
        'Господ не ги тепа правите, ами к треба да викаш, ако си '
        'умен и р.',
      );
    });
  });

  group('reconstructOcrTextFromLines (spatial layout)', () {
    OcrTextLine line(String text, int top, {int height = 40, int left = 10}) {
      return OcrTextLine(
        text: text,
        left: left,
        top: top,
        right: left + text.length * 12,
        bottom: top + height,
      );
    }

    test('wrapped sentence across multiple image lines → one paragraph', () {
      final text = reconstructOcrTextFromLines([
        line('Ова е првиот пасус кој продолжува', 10),
        line('во следниот визуелен ред.', 58), // gap ~8 (normal wrap)
      ]);
      expect(
        text,
        'Ова е првиот пасус кој продолжува во следниот визуелен ред.',
      );
      expect(text.contains('\n'), isFalse);
    });

    test('two real paragraphs → blank line separator', () {
      final text = reconstructOcrTextFromLines([
        line('Ова е првиот пасус кој продолжува', 10),
        line('во следниот визуелен ред.', 58),
        line('Ова е вториот пасус кој исто така', 160), // large gap
        line('продолжува во следниот ред.', 208),
      ]);
      expect(
        text,
        'Ова е првиот пасус кој продолжува во следниот визуелен ред.\n\n'
        'Ова е вториот пасус кој исто така продолжува во следниот ред.',
      );
    });

    test('three paragraphs', () {
      final text = reconstructOcrTextFromLines([
        line('Пасус еден ред еден', 10),
        line('Пасус еден ред два', 55),
        line('Пасус два', 150),
        line('Пасус три', 250),
      ]);
      expect(text.split('\n\n').length, 3);
      expect(text.startsWith('Пасус еден ред еден Пасус еден ред два'), isTrue);
    });

    test('hyphenated word across a visual line', () {
      final text = reconstructOcrTextFromLines([
        line('македонски-', 10),
        line('те зборови', 55),
      ]);
      expect(text, 'македонските зборови');
    });

    test('heading + paragraph via large vertical gap', () {
      final text = reconstructOcrTextFromLines([
        line('Наслов', 10, height: 36),
        line('Првата реченица од пасусот', 120),
        line('продолжува овде.', 165),
      ]);
      expect(text, 'Наслов\n\nПрвата реченица од пасусот продолжува овде.');
    });
  });

  group('reconstructOcrText entry', () {
    test('no paragraph metadata fallback uses blank lines', () {
      final text = reconstructOcrText(
        rawText: 'Еден\nпасус.\n\nДва\nпасус.',
        lines: const [],
      );
      expect(text, 'Еден пасус.\n\nДва пасус.');
    });

    test('ignores layout boxes to preserve Tesseract reading order', () {
      final text = reconstructOcrText(
        rawText: 'прва\nлинија\n\nвтор пасус',
        lines: [
          const OcrTextLine(
            text: 'втор пасус',
            left: 0,
            top: 0,
            right: 100,
            bottom: 40,
          ),
          const OcrTextLine(
            text: 'прва линија',
            left: 0,
            top: 48,
            right: 100,
            bottom: 88,
          ),
        ],
      );
      // Must follow rawText order, not bbox sort order.
      expect(text, 'прва линија\n\nвтор пасус');
    });
  });
}
