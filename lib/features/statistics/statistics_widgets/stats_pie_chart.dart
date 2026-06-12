import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsPieChart extends StatelessWidget {
  final int ocr;
  final int tts;
  final int saved;

  const StatsPieChart({
    super.key,
    required this.ocr,
    required this.tts,
    required this.saved,
  });

  @override
  Widget build(BuildContext context) {
    final total = (ocr + tts + saved).toDouble();

    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text("Нема податоци уште"),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            "Преглед на активност",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF07162E),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: ocr.toDouble(),
                    title: 'OCR',
                    color: Colors.blue,
                    radius: 60,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: tts.toDouble(),
                    title: 'TTS',
                    color: Colors.green,
                    radius: 60,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: saved.toDouble(),
                    title: 'Saved',
                    color: Colors.orange,
                    radius: 60,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}