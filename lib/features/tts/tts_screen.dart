// import 'package:flutter/material.dart';
//
// import 'tts_service.dart';
// import '../home/home_screen.dart';
// import '../ocr/ocr_screen.dart';
// import '../profile/profile_screen.dart';
// import '../settings/settings_screen.dart';
// import '../../widgets/app_bottom_nav.dart';
//
// class TtsScreen extends StatefulWidget {
//   const TtsScreen({super.key});
//
//   @override
//   State<TtsScreen> createState() => _TtsScreenState();
// }
//
// class _TtsScreenState extends State<TtsScreen> {
//   final TtsService _tts = TtsService();
//
//   final TextEditingController _controller = TextEditingController(
//     text:
//     'Читањето е прозорец кон светот. Со\nмалку помош, секој може да отвори\nнови приказни и идеи.',
//   );
//
//   bool _isReading = false;
//
//   int get _characterCount => _controller.text.length;
//
//   int get _wordCount {
//     final text = _controller.text.trim();
//
//     if (text.isEmpty) {
//       return 0;
//     }
//
//     return text
//         .split(RegExp(r'\s+'))
//         .where((word) => word.trim().isNotEmpty)
//         .length;
//   }
//
//   @override
//   void dispose() {
//     _tts.stop();
//     _controller.dispose();
//     super.dispose();
//   }
//
//   Future<void> _startReading() async {
//     final text = _controller.text.trim();
//
//     if (text.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Прво внеси текст!'),
//         ),
//       );
//       return;
//     }
//
//     setState(() {
//       _isReading = true;
//     });
//
//     await _tts.speak(text);
//   }
//
//   Future<void> _stopReading() async {
//     await _tts.stop();
//
//     if (!mounted) return;
//
//     setState(() {
//       _isReading = false;
//     });
//   }
//
//   void _open(BuildContext context, Widget screen) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => screen),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFFBFAF3),
//       body: SafeArea(
//         bottom: false,
//         child: Column(
//           children: [
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.only(bottom: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const _TtsHeader(),
//                     const SizedBox(height: 38),
//
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 28),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(28),
//                           border: Border.all(
//                             color: const Color(0xFFE7E1D5),
//                             width: 1,
//                           ),
//                         ),
//                         child: Column(
//                           children: [
//                             Padding(
//                               padding:
//                               const EdgeInsets.fromLTRB(26, 24, 26, 14),
//                               child: TextField(
//                                 controller: _controller,
//                                 maxLines: 9,
//                                 minLines: 9,
//                                 style: const TextStyle(
//                                   fontSize: 23,
//                                   height: 1.65,
//                                   color: Color(0xFF07162E),
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                                 decoration: const InputDecoration(
//                                   border: InputBorder.none,
//                                   hintText: 'Внеси или залепи текст...',
//                                   hintStyle: TextStyle(
//                                     color: Color(0xFF6A7284),
//                                   ),
//                                 ),
//                                 onChanged: (_) {
//                                   setState(() {});
//                                 },
//                               ),
//                             ),
//
//                             const Padding(
//                               padding: EdgeInsets.symmetric(horizontal: 26),
//                               child: Divider(
//                                 height: 1,
//                                 color: Color(0xFFE7E1D5),
//                               ),
//                             ),
//
//                             Padding(
//                               padding:
//                               const EdgeInsets.fromLTRB(26, 18, 26, 22),
//                               child: Row(
//                                 mainAxisAlignment:
//                                 MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Text(
//                                     '$_characterCount знаци',
//                                     style: const TextStyle(
//                                       color: Color(0xFF505A70),
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   Text(
//                                     '$_wordCount зборови',
//                                     style: const TextStyle(
//                                       color: Color(0xFF505A70),
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 32),
//
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 28),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: _PrimaryButton(
//                               icon: Icons.play_arrow_rounded,
//                               label:
//                               _isReading ? 'Чита...' : 'Започни читање',
//                               onTap: _startReading,
//                             ),
//                           ),
//                           const SizedBox(width: 18),
//                           Expanded(
//                             child: _StopButton(
//                               onTap: _stopReading,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                     const SizedBox(height: 28),
//
//                     const Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 32),
//                       child: Text(
//                         'Демо приказ — реален TTS може да се вклучи подоцна.',
//                         style: TextStyle(
//                           color: Color(0xFF505A70),
//                           fontSize: 16,
//                           height: 1.4,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             AppBottomNav(
//               currentIndex: 1,
//               onHomeTap: () => _open(context, HomeScreen()),
//               onReadTap: () {},
//               onScanTap: () => _open(context, OcrScreen()),
//               onProfileTap: () => _open(context, const ProfileScreen()),
//               onSettingsTap: () => _open(context, const SettingsScreen()),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _TtsHeader extends StatelessWidget {
//   const _TtsHeader();
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 20),
//       width: double.infinity,
//       padding: const EdgeInsets.fromLTRB(38, 72, 28, 48),
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             Color(0xFF63B5D2),
//             Color(0xFF638FDF),
//           ],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(38),
//           bottomRight: Radius.circular(38),
//         ),
//       ),
//       child: const Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Читај текст',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 38,
//               height: 1.05,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           SizedBox(height: 18),
//           Text(
//             'Внеси или залепи текст за гласно читање',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 19,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _PrimaryButton extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;
//
//   const _PrimaryButton({
//     required this.icon,
//     required this.label,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(24),
//       child: Container(
//         height: 92,
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         decoration: BoxDecoration(
//           gradient: const LinearGradient(
//             colors: [
//               Color(0xFF63B5D2),
//               Color(0xFF638FDF),
//             ],
//             begin: Alignment.centerLeft,
//             end: Alignment.centerRight,
//           ),
//           borderRadius: BorderRadius.circular(24),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, color: Colors.white, size: 34),
//             const SizedBox(width: 10),
//             Flexible(
//               child: Text(
//                 label,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 20,
//                   fontWeight: FontWeight.w800,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _StopButton extends StatelessWidget {
//   final VoidCallback onTap;
//
//   const _StopButton({
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(24),
//       child: Container(
//         height: 92,
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(24),
//           border: Border.all(
//             color: const Color(0xFFE7E1D5),
//             width: 1,
//           ),
//         ),
//         child: const Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.stop_rounded,
//               color: Color(0xFF07162E),
//               size: 34,
//             ),
//             SizedBox(width: 10),
//             Text(
//               'Стоп',
//               style: TextStyle(
//                 color: Color(0xFF07162E),
//                 fontSize: 20,
//                 fontWeight: FontWeight.w800,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:dyslexia_app/features/statistics/stats_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/provider.dart';
import '../../widgets/app_bottom_nav.dart';

import 'tts_service.dart';
import '../home/home_screen.dart';
import '../ocr/ocr_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

import 'tts_widgets/tts_header.dart';
import 'tts_widgets/tts_text_editor.dart';
import 'tts_widgets/tts_counter_row.dart';
import 'tts_widgets/tts_primary_button.dart';
import 'tts_widgets/tts_stop_button.dart';

class TtsScreen extends StatefulWidget {
  const TtsScreen({super.key});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  final TtsService _tts = TtsService();
  final StatsService _statsService = StatsService();

  final TextEditingController _controller = TextEditingController(
    text:
    'Читањето е прозорец кон светот. Со малку помош секој може да учи полесно.',
  );

  bool _isReading = false;

  int get _characters => _controller.text.length;

  int get _words {
    final text = _controller.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void dispose() {
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start(double speechRate) async {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Прво внеси текст.'),
        ),
      );
      return;
    }

    setState(() {
      _isReading = true;
    });

    await _tts.setSpeechRate(speechRate);
    await _tts.speak(text);
    await _statsService.incrementTTS();
  }

  Future<void> _stop() async {
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _isReading = false;
    });
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    const TtsHeader(),

                    const SizedBox(height: 38),

                    TtsTextEditor(
                      controller: _controller,
                      onChanged: () => setState(() {}),
                      fontSize: settings.fontSize,
                      dyslexiaFont: settings.dyslexiaFont,
                    ),

                    const SizedBox(height: 20),

                    TtsCounterRow(
                      characters: _characters,
                      words: _words,
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: TtsPrimaryButton(
                            isReading: _isReading,
                            onTap: () => _start(settings.speechRate),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: TtsStopButton(
                            onTap: _stop,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            AppBottomNav(
              currentIndex: 1,
              onHomeTap: () => _open(context, const HomeScreen()),
              onReadTap: () {},
              onScanTap: () => _open(context, const OcrScreen()),
              onProfileTap: () => _open(context, const ProfileScreen()),
              onSettingsTap: () => _open(context, const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}