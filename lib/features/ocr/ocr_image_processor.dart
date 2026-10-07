import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Pass 1 — fast recognition (~1.0–1.3 MP, long side up to 1400).
const ocrPass1TargetMegapixels = 1.2;
const ocrPass1MaxLongSide = 1400;

/// One smaller retry if pass 1 times out (still aspect-preserving).
const ocrPass1RetryTargetMegapixels = 0.7;
const ocrPass1RetryMaxLongSide = 960;

/// Pass 2 — higher quality fallback when pass 1 is empty/poor (~1.5–2 MP).
const ocrPass2TargetMegapixels = 1.8;
const ocrPass2MaxLongSide = 1600;

/// Soft upper bound for the temporary OCR JPEG (not the main quality lever).
const ocrMaxProcessedBytes = 3 * 1024 * 1024;

/// Preprocessing style for document pages.
enum OcrPreprocessMode {
  /// Resize only — keep color JPEG (diagnostic / high-quality baseline).
  colorHighQuality,

  /// Resize → grayscale only (no contrast boost).
  grayscaleOnly,

  /// Resize → grayscale → mild contrast (default document path).
  documentGrayscale,

  /// Resize → grayscale only (no contrast boost) — fallback alternative.
  documentGrayscaleSoft,
}

/// Thrown when an image cannot be decoded for OCR preprocessing.
class OcrImageDecodeException implements Exception {
  final String sourcePath;
  final String details;

  OcrImageDecodeException(this.sourcePath, this.details);

  @override
  String toString() =>
      'OcrImageDecodeException(path: $sourcePath, details: $details)';
}

/// Message passed to the background isolate for image normalization.
class PrepareImageMessage {
  final Uint8List bytes;
  final String tempDirPath;
  final String sourcePath;
  final int timestamp;
  final double targetMegapixels;
  final int maxLongSide;
  final int jpegQuality;
  final String mode;

  const PrepareImageMessage({
    required this.bytes,
    required this.tempDirPath,
    required this.sourcePath,
    required this.timestamp,
    this.targetMegapixels = ocrPass1TargetMegapixels,
    this.maxLongSide = ocrPass1MaxLongSide,
    this.jpegQuality = 95,
    this.mode = 'documentGrayscale',
  });
}

/// Decode → EXIF orient → resize if needed → document grayscale → JPEG.
///
/// Never writes a full-resolution intermediate PNG.
Map<String, Object> prepareImageForOcrIsolate(PrepareImageMessage message) {
  final originalBytes = message.bytes.length;

  final decoded = img.decodeImage(message.bytes);
  if (decoded == null) {
    final extension = p.extension(message.sourcePath).toLowerCase();
    throw OcrImageDecodeException(
      message.sourcePath,
      'decodeImage returned null '
      '(extension: ${extension.isEmpty ? "unknown" : extension}, '
      'size: $originalBytes bytes)',
    );
  }

  var image = img.bakeOrientation(decoded);
  final originalWidth = image.width;
  final originalHeight = image.height;

  // Resize first — never encode a huge intermediate.
  image = resizeForOcr(
    image,
    targetMegapixels: message.targetMegapixels,
    maxLongSide: message.maxLongSide,
  );

  final mode = message.mode;
  if (mode == OcrPreprocessMode.colorHighQuality.name) {
    // Keep color — no grayscale / contrast.
  } else {
    image = img.grayscale(image);
    if (mode == OcrPreprocessMode.documentGrayscale.name) {
      // Very mild — stronger contrast can break thin Macedonian strokes.
      image = img.adjustColor(image, contrast: 1.02, brightness: 1.0);
    }
    // grayscaleOnly / documentGrayscaleSoft: grayscale only.
  }

  // High JPEG quality — resolution (not compression) is the size lever.
  final encoded = img.encodeJpg(
    image,
    quality: message.jpegQuality.clamp(92, 97),
  );

  final outPath = p.join(
    message.tempDirPath,
    'ocr_pass_${message.timestamp}_${image.width}x${image.height}.jpg',
  );
  File(outPath).writeAsBytesSync(encoded, flush: true);

  final megapixels = (image.width * image.height) / 1000000.0;

  return <String, Object>{
    'path': outPath,
    'originalWidth': originalWidth,
    'originalHeight': originalHeight,
    'originalBytes': originalBytes,
    'processedWidth': image.width,
    'processedHeight': image.height,
    'processedBytes': encoded.length,
    'processedMegapixels': megapixels,
    'preprocessMode': message.mode,
  };
}

/// Shrink so longest side ≤ [maxLongSide] and total pixels ≤ target MP.
/// Never upscales. Uses average interpolation to keep glyph edges cleaner.
img.Image resizeForOcr(
  img.Image image, {
  required double targetMegapixels,
  required int maxLongSide,
}) {
  var result = _resizeToMaxLongSide(image, maxLongSide);

  final targetPixels = (targetMegapixels * 1000000).round();
  final pixels = result.width * result.height;
  if (pixels <= targetPixels) {
    return result;
  }

  final scale = math.sqrt(targetPixels / pixels);
  final newW = math.max(1, (result.width * scale).round());
  final newH = math.max(1, (result.height * scale).round());

  return img.copyResize(
    result,
    width: newW,
    height: newH,
    interpolation: img.Interpolation.average,
  );
}

img.Image _resizeToMaxLongSide(img.Image image, int maxLongSide) {
  final longest = image.width > image.height ? image.width : image.height;
  if (longest <= maxLongSide) {
    return image;
  }

  if (image.width >= image.height) {
    return img.copyResize(
      image,
      width: maxLongSide,
      interpolation: img.Interpolation.average,
    );
  }

  return img.copyResize(
    image,
    height: maxLongSide,
    interpolation: img.Interpolation.average,
  );
}
