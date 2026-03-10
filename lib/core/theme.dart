import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF673AB7),
    primary: const Color(0xFF673AB7),
    secondary: const Color(0xFF03DAC6),
    surface: const Color(0xFFF5F5F7), // Попријатна позадина
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F5F7),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: Color(0xFF1D1D1F),
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  ),
);