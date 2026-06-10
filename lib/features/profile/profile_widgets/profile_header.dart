import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String userName;
  const ProfileHeader({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF63B5D2), Color(0xFF638FDF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_rounded,
            size: 42,
            color: Colors.white,
          ),
          SizedBox(height: 8),
          Text(
            userName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}