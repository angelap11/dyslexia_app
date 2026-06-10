import 'package:flutter/material.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Поставки',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'Прилагоди ја апликацијата за себе',
          style: TextStyle(fontSize: 20),
        ),
      ],
    );
  }
}