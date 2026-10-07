import 'dart:async';

import 'package:dyslexia_app/features/tts/tts_service.dart';

/// Records calls; [speak] never completes, like audio that is still playing.
class FakeTtsService implements TtsService {
  int speakCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> speak(String text) {
    speakCalls++;
    return Completer<void>().future;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  void resetProgress() {}

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
