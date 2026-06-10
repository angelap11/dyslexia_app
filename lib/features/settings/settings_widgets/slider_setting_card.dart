import 'package:flutter/material.dart';

class SliderSettingCard extends StatelessWidget {
  final double fontSize;
  final ValueChanged<double> onChanged;

  const SliderSettingCard({
    super.key,
    required this.fontSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? const Color(0xFF333333)
              : const Color(0xFFE7E1D5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Големина на фонт'),
                  Text('${fontSize.round()}px'),
                ],
              ),
            ],
          ),

          Slider(
            value: fontSize,
            min: 14,
            max: 26,
            divisions: 12,
            onChanged: onChanged,
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF1EEE8),
            child: Text(
              'Преглед на текст',
              style: TextStyle(
                fontSize: fontSize,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}