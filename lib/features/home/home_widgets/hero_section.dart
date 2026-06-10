import 'package:flutter/material.dart';
import 'stat_row.dart';

class HomeHeroSection extends StatelessWidget {
  final String userName;

  const HomeHeroSection({
    super.key,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(34, 44, 34, 44),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Здраво, $userName 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Спремна ли си да читаш денес?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}