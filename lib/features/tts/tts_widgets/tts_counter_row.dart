import 'package:flutter/material.dart';

class TtsCounterRow extends StatelessWidget {
  final int characters;
  final int words;

  const TtsCounterRow({
    super.key,
    required this.characters,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$characters знаци'),
          Text('$words зборови'),
        ],
      ),
    );
  }
}