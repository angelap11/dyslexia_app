import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'simplify_prompt.dart';
import 'text_simplification_config.dart';

/// Result of a simplification request.
class TextSimplificationResult {
  final String simplifiedText;
  final bool usedMock;

  const TextSimplificationResult({
    required this.simplifiedText,
    required this.usedMock,
  });
}

/// Sends text to a remote LLM backend (or a labeled mock) for simplification.
class TextSimplificationService {
  TextSimplificationService({http.Client? httpClient})
    : _http = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  final http.Client _http;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) _http.close();
  }

  Future<TextSimplificationResult> simplify(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw const TextSimplificationException('Нема текст за поедноставување.');
    }

    if (TextSimplificationConfig.useMock) {
      debugPrint(
        '[Simplify] MOCK mode — set TEXT_SIMPLIFY_BASE_URL in .env for real API',
      );
      return TextSimplificationResult(
        simplifiedText: _mockSimplify(text),
        usedMock: true,
      );
    }

    final uri = TextSimplificationConfig.simplifyUri;
    if (uri == null) {
      throw const TextSimplificationException(
        'Сервисот за поедноставување не е конфигуриран.',
      );
    }

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      // ngrok free tier serves an HTML interstitial unless this is set;
      // without it JSON parse fails even when the tunnel is healthy.
      'ngrok-skip-browser-warning': 'true',
    };
    final key = TextSimplificationConfig.apiKey;
    if (key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
    }

    final body = jsonEncode({
      'text': text,
      'model': TextSimplificationConfig.modelId,
      'language': 'mk',
      'prompt_id': kMacedonianSimplifyPromptId,
      'system_prompt': kMacedonianSimplifySystemPrompt,
    });

    late final http.Response response;
    try {
      response = await _http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      debugPrint('[Simplify] network error: $e');
      throw const TextSimplificationException(
        'Не може да се поврземе со сервисот. Обиди се повторно.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[Simplify] HTTP ${response.statusCode}: ${response.body}');
      throw const TextSimplificationException(
        'Поедноставувањето не успеа. Обиди се повторно.',
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('unexpected JSON shape');
      }
      final simplified =
          (decoded['simplified_text'] ??
                  decoded['text'] ??
                  decoded['result'] ??
                  '')
              .toString()
              .trim();
      if (simplified.isEmpty) {
        throw const FormatException('empty simplified_text');
      }
      return TextSimplificationResult(
        simplifiedText: simplified,
        usedMock: false,
      );
    } catch (e) {
      debugPrint('[Simplify] parse error: $e');
      throw const TextSimplificationException(
        'Сервисот врати неочекуван одговор.',
      );
    }
  }

  /// Labeled demo output — not a real LLM. Clearly marked for local testing.
  static String _mockSimplify(String text) {
    // Light local heuristic: split on sentence punctuation and keep short.
    final parts = text
        .split(RegExp(r'(?<=[.!?。…])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final simplified = parts.isEmpty
        ? text
        : parts
              .map((s) {
                if (s.length <= 90) return s;
                final cut = s.substring(0, 87).trimRight();
                return '$cut…';
              })
              .join(' ');

    return '【DEMO】 $simplified';
  }
}

class TextSimplificationException implements Exception {
  final String message;
  const TextSimplificationException(this.message);

  @override
  String toString() => message;
}
