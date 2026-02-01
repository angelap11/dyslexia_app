import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/tts/tts_screen.dart';
import 'features/ocr/ocr_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dyslexia App',
      theme: appTheme,
      home: Scaffold(
        appBar: AppBar(title: const Text('Dyslexia App')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(
            builder: (context) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TtsScreen(),
                        ),
                      );
                    },
                    child: const Text('🗣 TTS Test'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanScreen(),
                        ),
                      );
                    },
                    child: const Text('OCR Scan'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

