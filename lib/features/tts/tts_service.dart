import 'package:flutter_tts/flutter_tts.dart';
class TtsService {
  final FlutterTts _tts = FlutterTts();
  Future init() async {
    await _tts.setLanguage("mk");
    await _tts.setSpeechRate(0.4);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }
  Future speak(String text) async {
    await _tts.speak(text);
  }
  Future stop() async {
    await _tts.stop();
  }
}