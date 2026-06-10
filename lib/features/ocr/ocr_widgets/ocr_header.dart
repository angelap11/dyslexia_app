import 'package:flutter/material.dart';


class OcrHeader extends StatelessWidget {
  const OcrHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 50),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7ED6C2),
            Color(0xFF5FB3D9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Скенирај документ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),

          SizedBox(height: 14),

          Text(
            'Слика или PDF → извлечи текст веднаш',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 17,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}