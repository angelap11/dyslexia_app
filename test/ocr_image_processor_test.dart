import 'dart:io';
import 'dart:typed_data';

import 'package:dyslexia_app/features/ocr/ocr_image_processor.dart';
import 'package:dyslexia_app/features/ocr/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('pass1 keeps document resolution near 1400 long side (~1.2 MP)', () {
    final huge = img.Image(width: 4000, height: 3000);
    img.fill(huge, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(
      huge,
      x1: 200,
      y1: 1400,
      x2: 3800,
      y2: 1600,
      color: img.ColorRgb8(20, 20, 20),
    );

    final bytes = Uint8List.fromList(img.encodeJpg(huge, quality: 95));
    final tempDir = Directory.systemTemp.createTempSync('ocr_q1_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final result = prepareImageForOcrIsolate(
      PrepareImageMessage(
        bytes: bytes,
        tempDirPath: tempDir.path,
        sourcePath: 'camera_huge.jpg',
        timestamp: 1,
        targetMegapixels: ocrPass1TargetMegapixels,
        maxLongSide: ocrPass1MaxLongSide,
        jpegQuality: 95,
        mode: OcrPreprocessMode.documentGrayscale.name,
      ),
    );

    final w = result['processedWidth'] as int;
    final h = result['processedHeight'] as int;
    final mp = result['processedMegapixels'] as double;
    expect(w <= ocrPass1MaxLongSide, isTrue);
    expect(h <= ocrPass1MaxLongSide, isTrue);
    expect(mp, lessThanOrEqualTo(ocrPass1TargetMegapixels + 0.05));
    expect(mp, greaterThan(0.7));
    expect(File(result['path']! as String).path.contains('.jpg'), isTrue);
    expect(result['preprocessMode'], 'documentGrayscale');
  });

  test('pass2 stays around 1.5–2 MP', () {
    final huge = img.Image(width: 4000, height: 3000);
    img.fill(huge, color: img.ColorRgb8(255, 255, 255));
    final bytes = Uint8List.fromList(img.encodeJpg(huge, quality: 95));
    final tempDir = Directory.systemTemp.createTempSync('ocr_q2_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final result = prepareImageForOcrIsolate(
      PrepareImageMessage(
        bytes: bytes,
        tempDirPath: tempDir.path,
        sourcePath: 'camera_huge.jpg',
        timestamp: 2,
        targetMegapixels: ocrPass2TargetMegapixels,
        maxLongSide: ocrPass2MaxLongSide,
        mode: OcrPreprocessMode.documentGrayscaleSoft.name,
      ),
    );

    final mp = result['processedMegapixels'] as double;
    expect(mp, lessThanOrEqualTo(ocrPass2TargetMegapixels + 0.05));
    expect(mp, greaterThan(1.0));
  });

  test('quality score penalizes fragmented single-char tokens', () {
    final good = OcrService.scoreOcrQuality(
      'Читањето е важен дел од учењето и комуникацијата во секојдневието.',
    );
    final bad = OcrService.scoreOcrQuality(
      'Ч и т а њ е т о е в а ж е н д е л о д у ч е њ е т о',
    );
    expect(good, greaterThan(bad));
    expect(bad, lessThan(0.5));
  });

  test('selection never discards non-empty poor-quality text', () {
    const poor = 'Ч и т а њ е т о е в а ж е н';
    final poorScore = OcrService.scoreOcrQuality(poor);

    final onlyPass1 = OcrService.selectNonEmptyResult(
      raw1: poor,
      score1: poorScore,
    );
    expect(onlyPass1.text, poor);
    expect(onlyPass1.pass, 1);

    final pass2Empty = OcrService.selectNonEmptyResult(
      raw1: poor,
      score1: poorScore,
      raw2: '',
      score2: 0,
    );
    expect(pass2Empty.text, poor);
    expect(pass2Empty.pass, 1);

    final bothEmpty = OcrService.selectNonEmptyResult(
      raw1: '',
      score1: 0,
      raw2: '   ',
      score2: 0,
    );
    expect(bothEmpty.text.trim(), isEmpty);
  });

  test('selection prefers higher-quality non-empty pass', () {
    const good = 'Читањето е важен дел од учењето и комуникацијата.';
    const poor = 'Ч и т а њ е т о';
    final selected = OcrService.selectNonEmptyResult(
      raw1: poor,
      score1: OcrService.scoreOcrQuality(poor),
      raw2: good,
      score2: OcrService.scoreOcrQuality(good),
    );
    expect(selected.pass, 2);
    expect(selected.text, good);
  });

  test('does not upscale small images', () {
    final small = img.Image(width: 800, height: 600);
    img.fill(small, color: img.ColorRgb8(255, 255, 255));
    final bytes = Uint8List.fromList(img.encodeJpg(small, quality: 90));
    final tempDir = Directory.systemTemp.createTempSync('ocr_small_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final result = prepareImageForOcrIsolate(
      PrepareImageMessage(
        bytes: bytes,
        tempDirPath: tempDir.path,
        sourcePath: 'small.jpg',
        timestamp: 3,
      ),
    );

    expect(result['processedWidth'], 800);
    expect(result['processedHeight'], 600);
  });
}
