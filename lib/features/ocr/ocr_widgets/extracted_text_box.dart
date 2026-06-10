import 'package:flutter/material.dart';
import '../../../widgets/dyslexia_text.dart';

class ExtractedTextBox extends StatelessWidget {
  final String text;
  final bool isLoading;
  final bool dyslexiaMode;
  final double fontSize;

  const ExtractedTextBox({
    super.key,
    required this.text,
    required this.isLoading,
    required this.dyslexiaMode,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 190,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE7E1D5),
        ),
      ),
      child: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3196C2),
        ),
      )
          : text.trim().isEmpty
          ? const Center(
        child: Text(
          'Прикачи документ или слика...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF6A7284),
            fontSize: 18,
            height: 1.5,
          ),
        ),
      )
          : SingleChildScrollView(
        child: dyslexiaMode
            ? DyslexiaText(
          text,
          fontSize: fontSize,
        )
            : Text(
          text,
          style: TextStyle(
            color: const Color(0xFF07162E),
            fontSize: fontSize,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
