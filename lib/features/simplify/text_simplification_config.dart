import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for the remote text-simplification (LLM) backend.
///
/// The model [modelId] runs on a separate API — never inside the Flutter app.
/// Set [TEXT_SIMPLIFY_BASE_URL] in `.env` when the backend is ready.
class TextSimplificationConfig {
  TextSimplificationConfig._();

  /// Model selected for Macedonian dyslexia-friendly simplification.
  static const String modelId = 'LVSTCK/domestic-yak-8B-instruct';

  /// Relative path appended to [baseUrl].
  static const String simplifyPath = '/v1/simplify';

  /// Base URL only, e.g. `https://api.example.com` — no trailing slash.
  /// Leave empty until the real backend exists.
  static String get baseUrl =>
      (dotenv.env['TEXT_SIMPLIFY_BASE_URL'] ?? '').trim();

  /// Optional bearer / API key for the simplification service.
  static String get apiKey =>
      (dotenv.env['TEXT_SIMPLIFY_API_KEY'] ?? '').trim();

  /// When true, always use the local mock. When unset, mock is used iff
  /// [baseUrl] is empty so the app never calls a made-up production URL.
  static bool get useMock {
    final flag = (dotenv.env['TEXT_SIMPLIFY_USE_MOCK'] ?? '')
        .trim()
        .toLowerCase();
    if (flag == 'true' || flag == '1' || flag == 'yes') return true;
    if (flag == 'false' || flag == '0' || flag == 'no') return false;
    return baseUrl.isEmpty;
  }

  static Uri? get simplifyUri {
    if (baseUrl.isEmpty) return null;
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$simplifyPath');
  }
}
