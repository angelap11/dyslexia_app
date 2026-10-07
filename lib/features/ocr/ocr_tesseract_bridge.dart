import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

import 'ocr_text_normalizer.dart';

/// Invokes the patched native Tesseract channel with explicit language + PSM.
///
/// The pub `TesseractOcr.extractText` API does not forward PSM options to
/// Android, so this bridge is required for document-quality recognition.
class OcrTesseractBridge {
  static const _channel = MethodChannel('tesseract_ocr');
  static const _tessDataConfig = 'assets/tessdata_config.json';
  static const _tessDataAssetPath = 'assets/tessdata';

  static String? _cachedTessDataParent;
  static Future<String>? _loading;
  static Map<String, dynamic>? _cachedAbiInfo;

  static Future<String> extractText({
    required String imagePath,
    String language = 'mkd',
    String pageSegMode = PageSegmentationMode.auto,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await extractTextWithLayout(
      imagePath: imagePath,
      language: language,
      pageSegMode: pageSegMode,
      timeout: timeout,
      includeLayout: false,
    );
    return result.rawText;
  }

  /// Same recognition as [extractText], optionally with line bounding boxes.
  static Future<OcrRecognitionResult> extractTextWithLayout({
    required String imagePath,
    String language = 'mkd',
    String pageSegMode = PageSegmentationMode.auto,
    Duration timeout = const Duration(seconds: 10),
    bool includeLayout = true,
  }) async {
    final tessData = await _ensureTessData();
    final trained = File(p.join(tessData, 'tessdata', 'mkd.traineddata'));
    if (!await trained.exists()) {
      throw StateError('mkd.traineddata missing at ${trained.path}');
    }

    final trainedBytes = await trained.length();
    debugPrint(
      '[OCR] language=$language traineddata=${trained.path} '
      'bytes=$trainedBytes',
    );

    final method = includeLayout ? 'extractTextWithLayout' : 'extractText';
    final raw = await _channel.invokeMethod<dynamic>(method, {
      'imagePath': imagePath,
      'tessData': tessData,
      'language': language,
      'pageSegMode': int.tryParse(pageSegMode) ?? 3,
      'timeoutMs': mathMax(3000, timeout.inMilliseconds - 500),
    });

    if (!includeLayout) {
      return OcrRecognitionResult(rawText: raw?.toString() ?? '');
    }

    if (raw is Map) {
      final text = (raw['text'] ?? '').toString();
      final linesRaw = raw['lines'];
      final lines = <OcrTextLine>[];
      if (linesRaw is List) {
        for (final item in linesRaw) {
          if (item is Map) {
            lines.add(OcrTextLine.fromMap(item));
          }
        }
      }
      debugPrint('[OCR-LAYOUT] nativeLines=${lines.length}');
      return OcrRecognitionResult(rawText: text, lines: lines);
    }

    return OcrRecognitionResult(rawText: raw?.toString() ?? '');
  }

  /// Logs runtime / packaged ABI once per process.
  static Future<void> logAbiInfo() async {
    try {
      final info = await getAbiInfo();
      debugPrint('[OCR] runtimeAbis=${info['runtimeAbis']}');
      debugPrint('[OCR] selectedAbi=${info['selectedAbi']}');
      debugPrint('[OCR] packagedAbis=${info['packagedAbis']}');
      debugPrint('[OCR] nativeLibraryDir=${info['nativeLibraryDir']}');
      debugPrint('[OCR] hasArm64NativeLib=${info['hasArm64NativeLib']}');
      debugPrint('[OCR] hasArmV7NativeLib=${info['hasArmV7NativeLib']}');
      debugPrint('[OCR] runtime64Abis=${info['runtime64Abis']}');
      debugPrint('[OCR] runtime32Abis=${info['runtime32Abis']}');
    } catch (e) {
      debugPrint('[OCR] ABI info unavailable: $e');
    }
  }

  static Future<Map<String, dynamic>> getAbiInfo() async {
    if (_cachedAbiInfo != null) return _cachedAbiInfo!;
    final raw = await _channel.invokeMethod<dynamic>('getAbiInfo');
    if (raw is Map) {
      _cachedAbiInfo = Map<String, dynamic>.from(raw);
      return _cachedAbiInfo!;
    }
    return <String, dynamic>{};
  }

  static int mathMax(int a, int b) => a > b ? a : b;

  static Future<String> _ensureTessData() {
    if (_cachedTessDataParent != null) {
      return Future.value(_cachedTessDataParent);
    }
    return _loading ??= _loadTessData().then((path) {
      _cachedTessDataParent = path;
      _loading = null;
      return path;
    });
  }

  static Future<String> _loadTessData() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final tessdataDirectory = Directory(p.join(appDirectory.path, 'tessdata'));
    if (!await tessdataDirectory.exists()) {
      await tessdataDirectory.create(recursive: true);
    }

    final config = await rootBundle.loadString(_tessDataConfig);
    final files = (jsonDecode(config) as Map<String, dynamic>)['files'] as List;
    for (final file in files) {
      final name = file.toString();
      final dest = File(p.join(tessdataDirectory.path, name));
      if (!await dest.exists()) {
        final data = await rootBundle.load(p.join(_tessDataAssetPath, name));
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await dest.writeAsBytes(bytes, flush: true);
      }
    }

    return appDirectory.path;
  }
}
