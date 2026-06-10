import 'package:flutter/material.dart';

class TtsTextEditor extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  final double fontSize;
  final bool dyslexiaFont;

  const TtsTextEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.fontSize = 17,
    this.dyslexiaFont = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          maxLines: 9,
          minLines: 9,
          style: TextStyle(
            fontSize: fontSize,
            height: 1.6,
            fontFamily: dyslexiaFont ? 'DyslexicFont' : null,
            color: const Color(0xFF07162E),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(20),
            hintText: 'Внеси текст...',
          ),
        ),
      ),
    );
  }
}