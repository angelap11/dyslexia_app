import 'package:flutter/material.dart';
import 'tts_service.dart';

class TtsScreen extends StatefulWidget {
  const TtsScreen({super.key});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  final TtsService _tts = TtsService();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Текст во говор')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 8,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Внеси текст...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.deepPurple, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      _tts.speak(_controller.text);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Прво внеси текст!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Слушај'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
                IconButton.filled(
                  onPressed: () => _tts.stop(),
                  icon: const Icon(Icons.stop),
                  style: IconButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}