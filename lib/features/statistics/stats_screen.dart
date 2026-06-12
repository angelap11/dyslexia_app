// import 'package:flutter/material.dart';
//
// import '../home/home_screen.dart';
// import '../statistics/stats_service.dart';
// import 'statistics_widgets/stat_card.dart';
//
// class StatsScreen extends StatefulWidget {
//   const StatsScreen({super.key});
//
//   @override
//   State<StatsScreen> createState() => _StatsScreenState();
// }
//
// class _StatsScreenState extends State<StatsScreen> {
//   final StatsService _service = StatsService();
//
//   int ocr = 0;
//   int tts = 0;
//   int saved = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     loadStats();
//   }
//
//   Future<void> loadStats() async {
//     final o = await _service.getOCRCount();
//     final t = await _service.getTTSCount();
//     final s = await _service.getSavedTexts();
//
//     setState(() {
//       ocr = o;
//       tts = t;
//       saved = s;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (_) => const HomeScreen()),
//             );
//           },
//         ),
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       "Статистика",
//                       style: TextStyle(
//                         fontSize: 34,
//                         fontWeight: FontWeight.w800,
//                         color: Color(0xFF07162E),
//                       ),
//                     ),
//
//                     const SizedBox(height: 30),
//
//                     StatCard(
//                       title: "Прочитани документи",
//                       value: ocr.toString(),
//                       icon: Icons.document_scanner_rounded,
//                     ),
//
//                     StatCard(
//                       title: "Слушани текстови",
//                       value: tts.toString(),
//                       icon: Icons.volume_up,
//                     ),
//
//                     StatCard(
//                       title: "Зачувани текстови",
//                       value: saved.toString(),
//                       icon: Icons.save,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
//
// import '../home/home_screen.dart';
// import '../statistics/stats_service.dart';
// import 'statistics_widgets/stat_card.dart';
// import 'package:fl_chart/fl_chart.dart';
//
//
// class StatsScreen extends StatefulWidget {
//   const StatsScreen({super.key});
//
//   @override
//   State<StatsScreen> createState() => _StatsScreenState();
// }
//
// class _StatsScreenState extends State<StatsScreen>
//     with WidgetsBindingObserver {
//   final StatsService _service = StatsService();
//
//   int ocr = 0;
//   int tts = 0;
//   int saved = 0;
//
//   @override
//   void initState() {
//     super.initState();
//
//     WidgetsBinding.instance.addObserver(this);
//     loadStats();
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }
//
//   // 🔥 AUTOMATIC REFRESH when returning to app
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       loadStats();
//     }
//   }
//
//   Future<void> loadStats() async {
//     final o = await _service.getOCRCount();
//     final t = await _service.getTTSCount();
//     final s = await _service.getSavedTexts();
//
//     if (!mounted) return;
//
//     setState(() {
//       ocr = o;
//       tts = t;
//       saved = s;
//     });
//   }
//
//   Future<void> _refresh() async {
//     await loadStats();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (_) => const HomeScreen()),
//             );
//           },
//         ),
//       ),
//
//       body: SafeArea(
//         child: RefreshIndicator(
//           onRefresh: _refresh,
//           child: ListView(
//             padding: const EdgeInsets.all(24),
//             children: [
//               const Text(
//                 "Статистика",
//                 style: TextStyle(
//                   fontSize: 34,
//                   fontWeight: FontWeight.w800,
//                   color: Color(0xFF07162E),
//                 ),
//               ),
//
//               const SizedBox(height: 30),
//
//               StatCard(
//                 title: "Прочитани документи",
//                 value: ocr.toString(),
//                 icon: Icons.document_scanner_rounded,
//               ),
//
//               StatCard(
//                 title: "Слушани текстови",
//                 value: tts.toString(),
//                 icon: Icons.volume_up,
//               ),
//
//               StatCard(
//                 title: "Зачувани текстови",
//                 value: saved.toString(),
//                 icon: Icons.save,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../statistics/stats_service.dart';
import 'statistics_widgets/stat_card.dart';
import 'statistics_widgets/stats_pie_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with WidgetsBindingObserver {
  final StatsService _service = StatsService();

  int ocr = 0;
  int tts = 0;
  int saved = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadStats();
    }
  }

  Future<void> loadStats() async {
    final o = await _service.getOCRCount();
    final t = await _service.getTTSCount();
    final s = await _service.getSavedTexts();

    if (!mounted) return;

    setState(() {
      ocr = o;
      tts = t;
      saved = s;
    });
  }

  Future<void> _refresh() async {
    await loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
        ),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                "Статистика",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF07162E),
                ),
              ),

              const SizedBox(height: 25),

              StatsPieChart(
                ocr: ocr,
                tts: tts,
                saved: saved,
              ),

              const SizedBox(height: 25),

              StatCard(
                title: "Прочитани документи",
                value: ocr.toString(),
                icon: Icons.document_scanner_rounded,
              ),

              StatCard(
                title: "Слушани текстови",
                value: tts.toString(),
                icon: Icons.volume_up,
              ),

              StatCard(
                title: "Зачувани текстови",
                value: saved.toString(),
                icon: Icons.save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}