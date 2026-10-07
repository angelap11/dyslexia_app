import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

import 'ocr_accuracy_signals.dart';
import 'ocr_image_processor.dart';
import 'ocr_text_normalizer.dart';
import 'ocr_tesseract_bridge.dart';

/// Thrown when native/Dart OCR exceeds the safety timeout.
class OcrTimeoutException implements Exception {
  final String message;
  OcrTimeoutException(this.message);

  @override
  String toString() => 'OcrTimeoutException: $message';
}

/// Thrown for preprocess / platform failures (not empty recognition).
class OcrProcessingException implements Exception {
  final String message;
  OcrProcessingException(this.message);

  @override
  String toString() => 'OcrProcessingException: $message';
}

/// Single-pass camera/gallery OCR — preserves Tesseract reading order.
///
/// One preprocess + one recognition. Optional one-shot PSM 3 vs 6 bakeoff
/// (same prepared image) locks the winner for later launches.
class OcrService {
  static const _passTimeout = Duration(seconds: 18);
  static const _psmLockFileName = 'ocr_psm_locked.txt';

  /// Set true once to force a PSM 3 vs 6 bakeoff on the next scan.
  static const bool forcePsmBakeoff = false;

  static const double _pickMaxWidth = 2400;
  static const double _pickMaxHeight = 2400;
  static const int _pickQuality = 95;

  /// Baseline production PSM until bakeoff locks a winner (PSM 3).
  static const String _psmBaseline = PageSegmentationMode.auto;

  /// Candidate for photographed paragraph pages (PSM 6).
  static const String _psmCandidate = PageSegmentationMode.singleBlock;

  static String? _cachedLockedPsm;

  /// Camera and gallery both use this method.
  Future<String> scanText(XFile image) async {
    final totalSw = Stopwatch()..start();
    debugPrint('[OCR] scanText start path=${image.path}');
    debugPrint('[OCR] language=mkd');
    debugPrint('[OCR] mode=single_pass');

    final source = File(image.path);
    if (!await source.exists()) {
      throw OcrProcessingException(
        'Captured image file does not exist: ${image.path}',
      );
    }

    try {
      final prepared = await _prepareImageForOcr(
        image,
        targetMegapixels: ocrPass1TargetMegapixels,
        maxLongSide: ocrPass1MaxLongSide,
        mode: OcrPreprocessMode.documentGrayscale,
      );

      final w = prepared['processedWidth'];
      final h = prepared['processedHeight'];
      final mp = prepared['processedMegapixels'];
      final mode = prepared['preprocessMode'];
      debugPrint('[OCR] preprocessing mode=$mode');
      debugPrint('[OCR] dimensions=${w}x$h');
      debugPrint('[OCR] megapixels=$mp');

      final lockedPsm = await _readLockedPsm();
      final needBakeoff = forcePsmBakeoff || lockedPsm == null;

      late final String rawText;
      late final String usedPsm;

      if (needBakeoff) {
        final bake = await _runPsmBakeoff(prepared);
        rawText = bake.text;
        usedPsm = bake.psm;
        await _writeLockedPsm(usedPsm);
        _cachedLockedPsm = usedPsm;
      } else {
        usedPsm = lockedPsm;
        debugPrint('[OCR] PSM=$usedPsm (locked)');
        rawText = await _recognize(prepared: prepared, pageSegMode: usedPsm);
      }

      final finalText = normalizeOcrLineBreaks(rawText);
      final signals = scoreOcrAccuracySignals(rawText);
      logOcrAccuracySignals('production', signals);

      if (kDebugMode) {
        debugPrint('[OCR] ========== TEXT PIPELINE ==========');
        _logTextPreview('RAW OCR', rawText);
        _logTextPreview('NORMALIZED OCR', finalText);
        _logTextPreview('FINAL DISPLAY TEXT', finalText);
        debugPrint('[OCR] ===================================');
      }

      debugPrint('[OCR] PSM=$usedPsm');
      debugPrint('[OCR] duration=${totalSw.elapsedMilliseconds}ms');
      debugPrint('[OCR] rawChars=${rawText.length}');
      debugPrint('[OCR] finalChars=${finalText.length}');
      debugPrint(
        '[OCR] finalDecision=${finalText.trim().isEmpty ? "empty" : "success"}',
      );

      return finalText;
    } on TimeoutException catch (e) {
      debugPrint('[OCR] finalDecision=timeout');
      throw OcrTimeoutException(e.message ?? 'OCR timed out');
    } on OcrTimeoutException {
      debugPrint('[OCR] finalDecision=timeout');
      rethrow;
    } on OcrProcessingException {
      debugPrint('[OCR] finalDecision=error');
      rethrow;
    } on OcrImageDecodeException catch (e, st) {
      debugPrint('[OCR] decode failure: $e');
      debugPrint('[OCR] stack: $st');
      debugPrint('[OCR] finalDecision=error');
      throw OcrProcessingException(e.toString());
    } on PlatformException catch (e, st) {
      debugPrint('[OCR] PlatformException code=${e.code} message=${e.message}');
      debugPrint('[OCR] stack: $st');
      if (e.code == 'OCR_TIMEOUT') {
        debugPrint('[OCR] finalDecision=timeout');
        throw OcrTimeoutException(e.message ?? 'OCR timed out');
      }
      debugPrint('[OCR] finalDecision=error');
      throw OcrProcessingException(
        'OCR platform failure (${e.code}): ${e.message ?? e.toString()}',
      );
    } catch (e, st) {
      debugPrint('[OCR] unexpected failure: $e');
      debugPrint('[OCR] stack: $st');
      if (e is TimeoutException) {
        debugPrint('[OCR] finalDecision=timeout');
        throw OcrTimeoutException(e.message ?? 'OCR timed out');
      }
      debugPrint('[OCR] finalDecision=error');
      throw OcrProcessingException(e.toString());
    }
  }

  /// One-time PSM 3 vs 6 on the SAME prepared image (not every scan).
  Future<({String text, String psm})> _runPsmBakeoff(
    Map<String, Object> prepared,
  ) async {
    debugPrint('[OCR-COMPARE] ========== PSM BAKEOFF START ==========');
    debugPrint(
      '[OCR-COMPARE] same preprocess dimensions='
      '${prepared['processedWidth']}x${prepared['processedHeight']}',
    );

    final sw3 = Stopwatch()..start();
    final text3 = await _recognize(
      prepared: prepared,
      pageSegMode: _psmBaseline,
    );
    final dur3 = sw3.elapsedMilliseconds;
    final sig3 = scoreOcrAccuracySignals(text3);

    debugPrint('[OCR-COMPARE] BASELINE');
    debugPrint('[OCR-COMPARE] preprocessing=documentGrayscale contrast=1.02');
    debugPrint('[OCR-COMPARE] PSM=$_psmBaseline');
    debugPrint(
      '[OCR-COMPARE] dimensions='
      '${prepared['processedWidth']}x${prepared['processedHeight']}',
    );
    debugPrint('[OCR-COMPARE] OCR duration=${dur3}ms');
    logOcrAccuracySignals('BASELINE', sig3);
    _logTextPreview('BASELINE rawText', text3);

    final sw6 = Stopwatch()..start();
    final text6 = await _recognize(
      prepared: prepared,
      pageSegMode: _psmCandidate,
    );
    final dur6 = sw6.elapsedMilliseconds;
    final sig6 = scoreOcrAccuracySignals(text6);

    debugPrint('[OCR-COMPARE] CANDIDATE');
    debugPrint('[OCR-COMPARE] preprocessing=documentGrayscale contrast=1.02');
    debugPrint('[OCR-COMPARE] PSM=$_psmCandidate');
    debugPrint(
      '[OCR-COMPARE] dimensions='
      '${prepared['processedWidth']}x${prepared['processedHeight']}',
    );
    debugPrint('[OCR-COMPARE] OCR duration=${dur6}ms');
    logOcrAccuracySignals('CANDIDATE', sig6);
    _logTextPreview('CANDIDATE rawText', text6);

    final pickCandidate = _preferCandidate(
      baseline: sig3,
      candidate: sig6,
      baselineMs: dur3,
      candidateMs: dur6,
    );

    final winnerPsm = pickCandidate ? _psmCandidate : _psmBaseline;
    final winnerText = pickCandidate ? text6 : text3;
    debugPrint(
      '[OCR-COMPARE] winner=PSM $winnerPsm '
      '(${pickCandidate ? "candidate" : "baseline"})',
    );
    debugPrint('[OCR-COMPARE] ========== PSM BAKEOFF END ==========');

    return (text: winnerText, psm: winnerPsm);
  }

  /// Keep candidate only if accuracy clearly improves without large slowdown.
  bool _preferCandidate({
    required OcrAccuracySignals baseline,
    required OcrAccuracySignals candidate,
    required int baselineMs,
    required int candidateMs,
  }) {
    final scoreDelta = candidate.score - baseline.score;
    final slower =
        candidateMs > baselineMs &&
        candidateMs > (baselineMs * 1.35).round() &&
        candidateMs - baselineMs > 1500;

    if (slower && scoreDelta < 0.08) {
      debugPrint(
        '[OCR-COMPARE] keep baseline — candidate slower without clear gain',
      );
      return false;
    }
    if (scoreDelta > 0.03) {
      debugPrint('[OCR-COMPARE] keep candidate — higher accuracy score');
      return true;
    }
    if (scoreDelta < -0.03) {
      debugPrint('[OCR-COMPARE] keep baseline — candidate worse');
      return false;
    }
    if (candidate.suspiciousShortPairs < baseline.suspiciousShortPairs) {
      debugPrint('[OCR-COMPARE] keep candidate — fewer suspicious splits');
      return true;
    }
    if (candidate.fragRatio + 0.02 < baseline.fragRatio) {
      debugPrint('[OCR-COMPARE] keep candidate — lower fragmentation');
      return true;
    }
    debugPrint('[OCR-COMPARE] keep baseline — no clear accuracy win');
    return false;
  }

  Future<String?> _readLockedPsm() async {
    if (_cachedLockedPsm != null) return _cachedLockedPsm;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(p.join(docs.path, _psmLockFileName));
      if (!await file.exists()) return null;
      final value = (await file.readAsString()).trim();
      if (value == _psmBaseline || value == _psmCandidate) {
        _cachedLockedPsm = value;
        return value;
      }
    } catch (e) {
      debugPrint('[OCR-COMPARE] read lock skipped: $e');
    }
    return null;
  }

  Future<void> _writeLockedPsm(String psm) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(p.join(docs.path, _psmLockFileName));
      await file.writeAsString(psm, flush: true);
      debugPrint('[OCR-COMPARE] locked PSM=$psm path=${file.path}');
    } catch (e) {
      debugPrint('[OCR-COMPARE] write lock skipped: $e');
    }
  }

  void _logTextPreview(String label, String text) {
    if (!kDebugMode) return;
    final preview = text.length <= 400 ? text : '${text.substring(0, 400)}…';
    debugPrint('[OCR] $label="$preview"');
  }

  Future<String> _recognize({
    required Map<String, Object> prepared,
    required String pageSegMode,
  }) async {
    final preparedPath = prepared['path']! as String;
    final file = File(preparedPath);
    if (!await file.exists()) {
      throw OcrProcessingException('Prepared OCR image missing: $preparedPath');
    }

    final bytes = await file.length();
    if (bytes > ocrMaxProcessedBytes) {
      throw OcrProcessingException(
        'Processed OCR image still too large ($bytes bytes)',
      );
    }

    await _saveDebugCopy(file);

    debugPrint('[OCR] input image path=$preparedPath bytes=$bytes');

    final sw = Stopwatch()..start();
    try {
      final text =
          await OcrTesseractBridge.extractText(
            imagePath: preparedPath,
            language: 'mkd',
            pageSegMode: pageSegMode,
            timeout: _passTimeout,
          ).timeout(
            _passTimeout,
            onTimeout: () {
              throw TimeoutException('OCR timed out after $_passTimeout');
            },
          );

      debugPrint('[OCR] recognition duration=${sw.elapsedMilliseconds}ms');
      debugPrint('[OCR] recognized chars=${text.length}');
      return text;
    } on TimeoutException {
      debugPrint(
        '[OCR] recognition timed out after ${sw.elapsedMilliseconds}ms',
      );
      rethrow;
    }
  }

  Future<Map<String, Object>> _prepareImageForOcr(
    XFile image, {
    required double targetMegapixels,
    required int maxLongSide,
    required OcrPreprocessMode mode,
  }) async {
    final prepSw = Stopwatch()..start();
    final bytes = await image.readAsBytes();
    final tempDir = await getTemporaryDirectory();

    final result = await compute(
      prepareImageForOcrIsolate,
      PrepareImageMessage(
        bytes: bytes,
        tempDirPath: tempDir.path,
        sourcePath: image.path,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        targetMegapixels: targetMegapixels,
        maxLongSide: maxLongSide,
        jpegQuality: 95,
        mode: mode.name,
      ),
    );

    final path = result['path']! as String;
    result['processedBytes'] = await File(path).length();

    debugPrint(
      '[OCR] original dimensions='
      '${result['originalWidth']}x${result['originalHeight']}',
    );
    debugPrint('[OCR] preprocess duration=${prepSw.elapsedMilliseconds}ms');

    return result;
  }

  Future<void> _saveDebugCopy(File prepared) async {
    try {
      final docs = await getTemporaryDirectory();
      final debugPath = p.join(docs.path, 'ocr_debug_last.jpg');
      await prepared.copy(debugPath);
      debugPrint('[OCR] debug preprocessed image saved: $debugPath');
    } catch (e) {
      debugPrint('[OCR] debug image save skipped: $e');
    }
  }

  @visibleForTesting
  static double scoreOcrQuality(String text) {
    return scoreOcrAccuracySignals(text).score;
  }

  @visibleForTesting
  static ({int pass, String text, double score}) selectNonEmptyResult({
    required String raw1,
    required double score1,
    String? raw2,
    double? score2,
  }) {
    final has1 = raw1.trim().isNotEmpty;
    final has2 = raw2 != null && raw2.trim().isNotEmpty;

    if (!has1 && !has2) {
      return (pass: raw2 == null ? 1 : 2, text: '', score: 0);
    }
    if (!has1 && has2) {
      return (pass: 2, text: raw2, score: score2 ?? 0);
    }
    if (has1 && !has2) {
      return (pass: 1, text: raw1, score: score1);
    }

    final text2 = raw2 as String;
    final s2 = score2 ?? 0;
    if (s2 > score1 + 0.02) {
      return (pass: 2, text: text2, score: s2);
    }
    if (score1 > s2 + 0.02) {
      return (pass: 1, text: raw1, score: score1);
    }
    if (text2.trim().length > raw1.trim().length) {
      return (pass: 2, text: text2, score: s2);
    }
    return (pass: 1, text: raw1, score: score1);
  }

  Future<XFile?> pickImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    try {
      debugPrint('[OCR] pickImage camera=$fromCamera');
      final image = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: _pickQuality,
        maxWidth: _pickMaxWidth,
        maxHeight: _pickMaxHeight,
        preferredCameraDevice: CameraDevice.rear,
      );
      debugPrint(
        '[OCR] ${fromCamera ? "camera" : "gallery"} pick '
        'result=${image?.path ?? "cancelled"}',
      );
      return image;
    } catch (e, st) {
      debugPrint('[OCR] Image picker exception: $e');
      debugPrint('[OCR] stack: $st');
      rethrow;
    }
  }

  void dispose() {}
}
