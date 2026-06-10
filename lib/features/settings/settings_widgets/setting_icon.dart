import 'package:flutter/material.dart';

class SettingIcon extends StatelessWidget {
  final IconData icon;

  const SettingIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFCFF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF3196C2),
        size: 31,
      ),
    );
  }
}