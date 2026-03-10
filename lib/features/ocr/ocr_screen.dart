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
    _ttsService.stop();
    super.dispose();
  }

  Future<void> pickAndScan({bool fromCamera = false}) async {
    final image = await _ocrService.pickImage(fromCamera: fromCamera);
    if (image != null) {
      setState(() {
        isLoading = true;
        scannedText = '';
      });
      final text = await _ocrService.scanText(image);
      setState(() {
        scannedText = text;
        isLoading = false;
      });
    }
  }

  Future<void> openFilesScreen() async {
    final text = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FilesScreen()),
    );

    if (text != null && text is String) {
      setState(() {
        scannedText = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('СКЕНИРАЈ ТЕКСТ')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _buildSourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: "Камера",
                  onTap: () => pickAndScan(fromCamera: true),
                ),
                const SizedBox(width: 10),
                _buildSourceButton(
                  icon: Icons.image_rounded,
                  label: "Галерија",
                  onTap: () => pickAndScan(fromCamera: false),
                ),
                const SizedBox(width: 10),
                _buildSourceButton(
                  icon: Icons.file_present_rounded,
                  label: "Фајл",
                  onTap: openFilesScreen,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : scannedText.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                  child: DyslexiaText(scannedText),
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (scannedText.isNotEmpty && !isLoading) _buildAudioControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.deepPurple, size: 24),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.text_fields_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          "Изберете слика или фајл за скенирање",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildAudioControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _ttsService.speak(scannedText),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("Слушај"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: () => _ttsService.stop(),
            icon: const Icon(Icons.stop_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              padding: const EdgeInsets.all(15),
            ),
          ),
        ],
      ),
    );
  }
}