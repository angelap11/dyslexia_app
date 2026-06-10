import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool dyslexiaFont = true;
  bool focusMode = false;
  double fontSize = 17;
  double speechRate = 0.5;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    dyslexiaFont = prefs.getBool('dyslexiaFont') ?? true;
    focusMode = prefs.getBool('focusMode') ?? false;
    fontSize = prefs.getDouble('fontSize') ?? 17;
    speechRate = prefs.getDouble('speechRate') ?? 0.5;

    notifyListeners();
  }

  Future<void> setDyslexiaFont(bool value) async {
    dyslexiaFont = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dyslexiaFont', value);
  }

  Future<void> setFocusMode(bool value) async {
    focusMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('focusMode', value);
  }

  Future<void> setFontSize(double value) async {
    fontSize = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', value);
  }

  Future<void> setSpeechRate(double value) async {
    speechRate = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speechRate', value);
  }
}
