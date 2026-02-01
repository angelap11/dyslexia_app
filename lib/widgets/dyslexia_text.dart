import 'package:flutter/material.dart';

class DyslexiaText extends StatelessWidget {
  final String text;
  const DyslexiaText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        // fontFamily: 'DyslexiaFZF',
        fontSize: 20,
        height: 1.6,
      ),
    );
  }
}