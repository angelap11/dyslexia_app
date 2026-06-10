import 'package:flutter/material.dart';

class TtsHeader extends StatelessWidget {
  const TtsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // 🔥 FULL WIDTH
      padding: const EdgeInsets.fromLTRB(38, 72, 28, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF63B5D2), Color(0xFF638FDF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(38),
          bottomRight: Radius.circular(38),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Читај текст',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Внеси текст за гласно читање',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}