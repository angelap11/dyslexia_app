import 'package:flutter/material.dart';

class TtsPrimaryButton extends StatelessWidget {
  final bool isReading;
  final VoidCallback onTap;

  const TtsPrimaryButton({
    super.key,
    required this.isReading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF63B5D2), Color(0xFF638FDF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Започни читање',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}