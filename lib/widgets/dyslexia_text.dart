import 'package:flutter/material.dart';

class DyslexiaText extends StatelessWidget {
  final String text;
  final double fontSize;

  const DyslexiaText(
      this.text, {
        super.key,
        this.fontSize = 22,
      });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'DyslexicFont',
        fontSize: fontSize,
        height: 1.8,
        letterSpacing: 0.5,
        wordSpacing: 2.0,
      ),
    );
  }
}
