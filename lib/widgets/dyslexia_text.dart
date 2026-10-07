import 'package:flutter/material.dart';

class DyslexiaText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const DyslexiaText(this.text, {super.key, this.style});

  /// The exact style [DyslexiaText] renders with, for widgets that must lay
  /// out the same text identically.
  static TextStyle? styleFor(TextStyle? base) {
    return base?.copyWith(
      fontFamily: 'DyslexicFont',
      wordSpacing: (base.wordSpacing ?? 0) + 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: styleFor(style ?? Theme.of(context).textTheme.bodyLarge),
    );
  }
}
