import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/tts/tts_screen.dart';
import 'features/ocr/ocr_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dyslexia App',
      theme: appTheme,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ДИСЛЕКСИЈА АСИСТЕНТ')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Добредојдовте,",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const Text(
              "Изберете алатка:",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            _buildFeatureCard(
              context,
              title: "Текст во говор",
              desc: "Внесете текст за гласно читање",
              icon: Icons.record_voice_over_rounded,
              color: Colors.blue.shade700,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TtsScreen())),
            ),

            const SizedBox(height: 16),

            _buildFeatureCard(
              context,
              title: "Скенирај документ",
              desc: "Претвори слика или PDF во текст",
              icon: Icons.document_scanner_rounded,
              color: Colors.indigo.shade800,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, {required String title, required String desc, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(desc, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}