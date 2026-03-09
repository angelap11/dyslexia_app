import 'package:flutter/material.dart';
import 'ocr_service.dart';
import '../../widgets/dyslexia_text.dart';
import '../tts/tts_service.dart';
import '../files/files_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {

  final OcrService _ocrService = OcrService();
  final TtsService _ttsService = TtsService();

  String scannedText = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _ttsService.init();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> pickAndScan({bool fromCamera = false}) async {

    setState(() {
      isLoading = true;
      scannedText = '';
    });

    final image = await _ocrService.pickImage(fromCamera: fromCamera);

    if (image != null) {

      final text = await _ocrService.scanText(image);

      setState(() {
        scannedText = text;
        isLoading = false;
      });

    } else {

      setState(() {
        isLoading = false;
      });

    }
  }

  Future<void> openFilesScreen() async {

    final text = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FilesScreen(),
      ),
    );

    if (text != null) {

      setState(() {
        scannedText = text;
      });

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('OCR Scan'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            ElevatedButton(
              onPressed: () => pickAndScan(fromCamera: true),
              child: const Text('📷 Камера'),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () => pickAndScan(fromCamera: false),
              child: const Text('🖼 Галерија'),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: openFilesScreen,
              child: const Text('📄 Upload File'),
            ),

            const SizedBox(height: 20),

            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),

            if (!isLoading && scannedText.isNotEmpty) ...[

              Expanded(
                child: SingleChildScrollView(
                  child: DyslexiaText(scannedText),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () => _ttsService.speak(scannedText),
                child: const Text('🔊 Слушај'),
              ),

              ElevatedButton(
                onPressed: () => _ttsService.stop(),
                child: const Text('⏹ Стоп'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}