import 'package:flutter/material.dart';
import '../../history/history_screen.dart';

class ProfileHistoryCard extends StatelessWidget {
  const ProfileHistoryCard({super.key});

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openHistory(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE7E1D5),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3196C2).withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // ICON BUBBLE
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFCFF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF3196C2),
                size: 28,
              ),
            ),

            const SizedBox(width: 16),

            // TEXT
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Историја',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF07162E),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Преглед на отворени документи',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5E6677),
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF5E6677),
            ),
          ],
        ),
      ),
    );
  }
}