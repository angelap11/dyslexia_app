import 'package:flutter/material.dart';

class StopButton extends StatelessWidget {
  final VoidCallback onTap;

  const StopButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey),
        ),
        child: const Center(
          child: Text('Стоп'),
        ),
      ),
    );
  }
}