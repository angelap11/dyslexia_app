import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  String get _apiKey => dotenv.env['AZURE_TTS_API_KEY'] ?? '';
  String get _region => dotenv.env['AZURE_TTS_REGION'] ?? '';

  Future<void> init() async {}

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      return;
    }

    if (_apiKey.isEmpty || _region.isEmpty) {
      print('TTS Error: Azure API key or region is missing from .env');
      return;
    }

    final url = Uri.parse(
      'https://$_region.tts.speech.microsoft.com/cognitiveservices/v1',
    );

    final ssml = """
<speak version='1.0' xml:lang='mk-MK'>
  <voice xml:lang='mk-MK' xml:gender='Female' name='mk-MK-MarijaNeural'>
    <prosody rate='-10.00%'>$text</prosody>
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

        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(file.path));
      } else {
        print('Error from Azure: ${response.statusCode}');
        print(response.body);
      }
    } catch (e) {
      print('Error with connection: $e');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}