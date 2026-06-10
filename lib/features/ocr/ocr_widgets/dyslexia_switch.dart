import 'package:flutter/material.dart';

class DyslexiaSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const DyslexiaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      activeColor: Colors.white,
      activeTrackColor: const Color(0xFF7DD3C7),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFE8E5DC),
      onChanged: onChanged,
    );
  }
}