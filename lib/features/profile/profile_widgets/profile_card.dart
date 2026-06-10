import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF63B5D2), Color(0xFF638FDF)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: const [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person_outline_rounded,
              size: 55,
              color: Color(0xFF3196C2),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Ана',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Добредојде во твојот профил',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}