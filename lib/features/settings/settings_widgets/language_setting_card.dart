import 'package:flutter/material.dart';
import 'setting_icon.dart';

class LanguageSettingCard extends StatelessWidget {
  const LanguageSettingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7E1D5)),
      ),
      child: Row(
        children: const [
          SettingIcon(icon: Icons.language),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Јазик'),
                Text('Македонски (кирилица)'),
              ],
            ),
          ),
          Text('MK'),
        ],
      ),
    );
  }
}