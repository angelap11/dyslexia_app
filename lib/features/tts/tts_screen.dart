import 'package:flutter/material.dart';
import 'tts_service.dart';
class TtsScreen extends StatefulWidget {
  const TtsScreen({super.key});
  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _tts.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TTS Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Ова е тест за читање текст на македонски јазик.',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _tts.speak(
                  'Ова е тест за читање текст на македонски јазик',
                );
              },
              child: const Text('   Слушај'),
            ),
            ElevatedButton(
              onPressed: () {
                _tts.stop();
              },
              child: const Text('⏹ Стоп'),
            ),
          ],
        ),
      ),
    );
  }
}