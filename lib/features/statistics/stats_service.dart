import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  Future<void> incrementOCR() async {
    final prefs = await SharedPreferences.getInstance();
    int value = prefs.getInt('ocr_count') ?? 0;
    await prefs.setInt('ocr_count', value + 1);
  }

  Future<void> incrementTTS() async {
    final prefs = await SharedPreferences.getInstance();
    int value = prefs.getInt('tts_count') ?? 0;
    await prefs.setInt('tts_count', value + 1);
  }

  Future<int> getOCRCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ocr_count') ?? 0;
  }

  Future<int> getTTSCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('tts_count') ?? 0;
  }

  Future<int> getSavedTexts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('saved_texts') ?? 0;
  }

  Future<void> incrementSavedTexts() async {
    final prefs = await SharedPreferences.getInstance();
    int value = prefs.getInt('saved_texts') ?? 0;
    await prefs.setInt('saved_texts', value + 1);
  }
}