import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Playback lifecycle for Azure TTS audio.
enum TtsPlaybackState { idle, speaking, stopped, completed }

/// Azure Neural TTS via HTTP + [AudioPlayer].
///
/// Progress is estimated from audio position/duration (no word callbacks),
/// then mapped to a character offset in the source text so Stop → Слушај
/// can resume near where playback left off.
class TtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Completer<void>? _playbackCompleter;
  late final StreamSubscription<void> _completeSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  double _speechRate = 0.5;

  /// Full text of the current reading session (trimmed).
  String _trackedText = '';

  /// Absolute character offset into [_trackedText] to resume from.
  int _savedOffset = 0;

  /// Offset where the current audio chunk begins in [_trackedText].
  int _chunkBaseOffset = 0;

  /// Substring currently being synthesized/played.
  String _chunkText = '';

  Duration? _duration;
  Duration _position = Duration.zero;
  DateTime? _lastProgressLogAt;

  TtsPlaybackState _playbackState = TtsPlaybackState.idle;
  bool _stopRequested = false;

  TtsService() {
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _onPlaybackCompleted();
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((pos) {
      _position = pos;
      _updateSavedOffsetFromAudio();
      _maybeLogProgress();
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((dur) {
      _duration = dur;
      _updateSavedOffsetFromAudio();
    });
  }

  String get _apiKey => dotenv.env['AZURE_TTS_API_KEY'] ?? '';
  String get _region => dotenv.env['AZURE_TTS_REGION'] ?? '';

  /// Last known absolute character offset (for tests / debugging).
  int get savedOffset => _savedOffset;

  String get trackedText => _trackedText;

  TtsPlaybackState get playbackState => _playbackState;

  Future<void> init() async {}

  /// Clears resume state so the next [speak] starts from the beginning.
  void resetProgress() {
    _savedOffset = 0;
    _trackedText = '';
    _chunkBaseOffset = 0;
    _chunkText = '';
    _position = Duration.zero;
    _duration = null;
    _playbackState = TtsPlaybackState.idle;
    debugPrint('[TTS] resetProgress offset=0');
  }

  void _finishPlaybackCompleter() {
    final completer = _playbackCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _playbackCompleter = null;
  }

  Future<void> dispose() async {
    await _completeSubscription.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    _finishPlaybackCompleter();
    await _audioPlayer.dispose();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
  }

  String _azureRateValue() {
    if (_speechRate <= 0.2) return '-30.00%';
    if (_speechRate <= 0.3) return '-20.00%';
    if (_speechRate <= 0.4) return '-10.00%';
    if (_speechRate <= 0.5) return '-5.00%';
    if (_speechRate <= 0.6) return '0.00%';
    if (_speechRate <= 0.7) return '10.00%';
    if (_speechRate <= 0.8) return '20.00%';
    if (_speechRate <= 0.9) return '30.00%';
    return '40.00%';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  void _updateSavedOffsetFromAudio() {
    if (_chunkText.isEmpty) return;
    final absolute = estimateAbsoluteOffset(
      chunkBaseOffset: _chunkBaseOffset,
      chunkLength: _chunkText.length,
      position: _position,
      duration: _duration,
      textLength: _trackedText.length,
    );
    _savedOffset = absolute;
  }

  void _maybeLogProgress() {
    final now = DateTime.now();
    if (_lastProgressLogAt != null &&
        now.difference(_lastProgressLogAt!) <
            const Duration(milliseconds: 800)) {
      return;
    }
    _lastProgressLogAt = now;
    final end = (_savedOffset + 1).clamp(0, _trackedText.length);
    debugPrint('[TTS] progress start=$_savedOffset end=$end');
  }

  void _onPlaybackCompleted() {
    if (_stopRequested) {
      _finishPlaybackCompleter();
      return;
    }
    _savedOffset = 0;
    _chunkBaseOffset = 0;
    _chunkText = '';
    _position = Duration.zero;
    _duration = null;
    _playbackState = TtsPlaybackState.completed;
    debugPrint('[TTS] completed resetOffset=0');
    _finishPlaybackCompleter();
  }

  /// Forward resume: end of the word at [offset], then first char of the next word.
  ///
  /// Never snaps backward to a previous sentence or earlier words.
  static int snapToNextWordBoundary(String text, int offset) {
    if (text.isEmpty) return 0;
    if (offset <= 0) return 0;
    if (offset >= text.length) return text.length;

    var i = offset;

    // Inside (or at start of) a word → advance to the end of that word.
    if (_isWordChar(text[i])) {
      while (i < text.length && _isWordChar(text[i])) {
        i++;
      }
    }

    // Skip whitespace and punctuation separators only (not whole sentences of words).
    while (i < text.length && !_isWordChar(text[i])) {
      i++;
    }

    return i;
  }

  static bool _isWhitespace(String ch) =>
      ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t';

  static bool _isWordChar(String ch) {
    if (_isWhitespace(ch)) return false;
    // Treat letters/digits as word content; punctuation as separators.
    final code = ch.codeUnitAt(0);
    // ASCII letters/digits
    if ((code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122)) {
      return true;
    }
    // Common Cyrillic block (covers Macedonian)
    if (code >= 0x0400 && code <= 0x04FF) return true;
    // Apostrophe / soft hyphen inside words (rare); keep as separator otherwise.
    return false;
  }

  /// Maps audio progress within the current chunk to an absolute text offset.
  static int estimateAbsoluteOffset({
    required int chunkBaseOffset,
    required int chunkLength,
    required Duration position,
    required Duration? duration,
    required int textLength,
  }) {
    if (chunkLength <= 0 || textLength <= 0) return 0;
    if (duration == null || duration.inMilliseconds <= 0) {
      return chunkBaseOffset.clamp(0, textLength);
    }
    final ratio = (position.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final relative = (ratio * chunkLength).floor();
    return (chunkBaseOffset + relative).clamp(0, textLength);
  }

  Future<void> speak(String text) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    // New / edited text → start from the beginning.
    if (cleanText != _trackedText) {
      _trackedText = cleanText;
      _savedOffset = 0;
    }

    // Saved offset is already next-word from Stop; only clamp/validate here.
    var offset = _savedOffset.clamp(0, cleanText.length);
    if (offset >= cleanText.length) {
      offset = 0;
      _savedOffset = 0;
    }

    final remaining = offset > 0 ? cleanText.substring(offset) : cleanText;
    if (remaining.trim().isEmpty) {
      offset = 0;
      _savedOffset = 0;
    }

    final speakText = offset > 0 ? cleanText.substring(offset) : cleanText;
    if (speakText.trim().isEmpty) {
      return;
    }

    _chunkBaseOffset = offset;
    _chunkText = speakText;
    _savedOffset = offset;
    _position = Duration.zero;
    _duration = null;
    _stopRequested = false;
    _playbackState = TtsPlaybackState.speaking;

    if (offset > 0) {
      final preview = speakText.length > 32
          ? '${speakText.substring(0, 32)}…'
          : speakText;
      debugPrint('[TTS] resume from offset=$offset');
      debugPrint('[TTS] resume text starts="$preview"');
    } else {
      debugPrint('[TTS] start offset=0');
    }

    if (_apiKey.isEmpty || _region.isEmpty) {
      debugPrint('TTS Error: Azure API key or region is missing from .env');
      _playbackState = TtsPlaybackState.idle;
      return;
    }

    final url = Uri.parse(
      'https://$_region.tts.speech.microsoft.com/cognitiveservices/v1',
    );

    final safeText = _escapeXml(speakText);
    final rate = _azureRateValue();

    final ssml =
        """
<speak version='1.0' xml:lang='mk-MK'>
  <voice xml:lang='mk-MK' xml:gender='Female' name='mk-MK-MarijaNeural'>
    <prosody rate='$rate'>$safeText</prosody>
  </voice>
</speak>
""";

    try {
      final response = await http.post(
        url,
        headers: {
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
          'Content-Type': 'application/ssml+xml',
          'Ocp-Apim-Subscription-Key': _apiKey,
        },
        body: ssml,
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_audio.mp3');

        await file.writeAsBytes(bytes);

        _finishPlaybackCompleter();
        _playbackCompleter = Completer<void>();

        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(file.path));
        await _playbackCompleter!.future;
      } else {
        debugPrint('Error from Azure: ${response.statusCode}');
        debugPrint(response.body);
        _playbackState = TtsPlaybackState.idle;
      }
    } catch (e) {
      debugPrint('Error with connection: $e');
      _playbackState = TtsPlaybackState.idle;
    }
  }

  Future<void> stop() async {
    _stopRequested = true;

    // Prefer live player position at stop time.
    try {
      final pos = await _audioPlayer.getCurrentPosition();
      if (pos != null) _position = pos;
      final dur = await _audioPlayer.getDuration();
      if (dur != null) _duration = dur;
    } catch (_) {}

    _updateSavedOffsetFromAudio();
    final estimated = _savedOffset;
    debugPrint('[TTS] stop estimatedOffset=$estimated');

    if (_trackedText.isNotEmpty) {
      _savedOffset = snapToNextWordBoundary(_trackedText, estimated);
      _savedOffset = _savedOffset.clamp(0, _trackedText.length);
    }

    debugPrint('[TTS] stop nextWordOffset=$_savedOffset');

    await _audioPlayer.stop();
    _playbackState = TtsPlaybackState.stopped;
    _finishPlaybackCompleter();
  }
}
