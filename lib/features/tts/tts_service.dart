import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  double _speechRate = 0.5;

  String get _apiKey => dotenv.env['AZURE_TTS_API_KEY'] ?? '';
  String get _region => dotenv.env['AZURE_TTS_REGION'] ?? '';

  Future<void> init() async {}

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

  Future<void> speak(String text) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    if (_apiKey.isEmpty || _region.isEmpty) {
      print('TTS Error: Azure API key or region is missing from .env');
      return;
    }

    final url = Uri.parse(
      'https://$_region.tts.speech.microsoft.com/cognitiveservices/v1',
    );

    final safeText = _escapeXml(cleanText);
    final rate = _azureRateValue();

    final ssml = """
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
