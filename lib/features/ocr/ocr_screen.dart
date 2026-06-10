// import 'package:dyslexia_app/features/home/home_screen.dart';
// import 'package:flutter/material.dart';
//
// import '../../widgets/app_bottom_nav.dart';
// import '../profile/profile_screen.dart';
// import '../settings/settings_screen.dart';
// import '../tts/tts_screen.dart';
// import 'ocr_service.dart';
// import '../tts/tts_service.dart';
// import '../statistics/stats_service.dart';
// import 'ocr_widgets/dyslexia_switch.dart';
// import 'ocr_widgets/ocr_header.dart';
// import 'ocr_widgets/upload_panel.dart';
// import 'ocr_widgets/extracted_text_box.dart';
// import 'ocr_widgets/listen_button.dart';
// import 'ocr_widgets/stop_button.dart';
// import 'ocr_widgets/file_upload_panel.dart';
//
// import '../files/files_service.dart';
//
// class OcrScreen extends StatefulWidget {
//   const OcrScreen({super.key});
//
//   @override
//   State<OcrScreen> createState() => _OcrScreenState();
// }
//
// class _OcrScreenState extends State<OcrScreen> {
//   final OcrService _ocrService = OcrService();
//   final TtsService _ttsService = TtsService();
//   final StatsService _statsService = StatsService();
//   final FileService _fileService = FileService();
//
//   String scannedText = '';
//   bool isLoading = false;
//   bool dyslexiaMode = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _ttsService.init();
//   }
//
//   @override
//   void dispose() {
//     _ocrService.dispose();
//     _ttsService.stop();
//     super.dispose();
//   }
//
//   Future<void> pickDocument() async {
//     setState(() {
//       isLoading = true;
//       scannedText = '';
//     });
//
//     final text = await _fileService.pickFileAndExtractText();
//
//     if (!mounted) return;
//
//     setState(() {
//       scannedText = text ?? '';
//       isLoading = false;
//     });
//
//     if (text == null || text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Не е пронајден текст во документот.'),
//         ),
//       );
//     }
//   }
//
//   Future<void> pickAndScan({bool fromCamera = false}) async {
//     setState(() {
//       isLoading = true;
//       scannedText = '';
//     });
//
//     final image =
//     await _ocrService.pickImage(fromCamera: fromCamera);
//
//     if (image == null) {
//       if (!mounted) return;
//
//       setState(() {
//         isLoading = false;
//       });
//
//       return;
//     }
//
//     final text = await _ocrService.scanText(image);
//
//     if (!mounted) return;
//
//     setState(() {
//       scannedText = text;
//       isLoading = false;
//     });
//
//     if (text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Не е пронајден текст во сликата.'),
//         ),
//       );
//     }
//
//     await _statsService.incrementOCR();
//   }
//
//   Future<void> _listen() async {
//       if (scannedText.trim().isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Прво прикачи документ или слика.'),
//           ),
//         );
//         return;
//       }
//
//       await _ttsService.speak(scannedText);
//       await _statsService.incrementTTS();
//   }
//
//   Future<void> _stop() async {
//     await _ttsService.stop();
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
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       body: SafeArea(
//         bottom: false,
//         child: Column(
//           children: [
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.only(bottom: 24),
//                 child: Column(
//                   children: [
//                     const OcrHeader(),
//
//                     const SizedBox(height: 28),
//
//                     FileUploadPanel(
//                       onPickFile: pickDocument,
//                     ),
//
//                     const SizedBox(height: 22),
//
//                     UploadPanel(
//                       onCamera: () =>
//                           pickAndScan(fromCamera: true),
//                       onGallery: () =>
//                           pickAndScan(fromCamera: false),
//                     ),
//
//                     const SizedBox(height: 22),
//
//                     DyslexiaSwitch(
//                       value: dyslexiaMode,
//                       onChanged: (v) =>
//                           setState(() => dyslexiaMode = v),
//                     ),
//
//                     const SizedBox(height: 28),
//
//                     const Text(
//                       'ИЗВЛЕЧЕН ТЕКСТ',
//                       style: TextStyle(
//                         fontSize: 17,
//                         fontWeight: FontWeight.w700,
//                         letterSpacing: 1.3,
//                       ),
//                     ),
//
//                     const SizedBox(height: 16),
//
//                     ExtractedTextBox(
//                       text: scannedText,
//                       isLoading: isLoading,
//                       dyslexiaMode: dyslexiaMode,
//                     ),
//
//                     if (scannedText.trim().isNotEmpty) ...[
//                       const SizedBox(height: 22),
//
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ListenButton(onTap: _listen),
//                           ),
//                           const SizedBox(width: 14),
//                           Expanded(
//                             child: StopButton(onTap: _stop),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//             AppBottomNav(
//               currentIndex: 2,
//               onHomeTap: () => _open(context, HomeScreen()),
//               onReadTap: () =>
//                   _open(context, const TtsScreen()),
//               onScanTap: () {},
//               onProfileTap: () =>
//                   _open(context, const ProfileScreen()),
//               onSettingsTap: () =>
//                   _open(context, const SettingsScreen()),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:dyslexia_app/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/provider.dart';
import '../../widgets/app_bottom_nav.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../tts/tts_screen.dart';
import 'ocr_service.dart';
import '../tts/tts_service.dart';
import '../statistics/stats_service.dart';
import 'ocr_widgets/dyslexia_switch.dart';
import 'ocr_widgets/ocr_header.dart';
import 'ocr_widgets/upload_panel.dart';
import 'ocr_widgets/extracted_text_box.dart';
import 'ocr_widgets/listen_button.dart';
import 'ocr_widgets/stop_button.dart';
import 'ocr_widgets/file_upload_panel.dart';
import '../files/files_service.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final OcrService _ocrService = OcrService();
  final TtsService _ttsService = TtsService();
  final StatsService _statsService = StatsService();
  final FileService _fileService = FileService();

  String scannedText = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _ttsService.init();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _ttsService.stop();
    super.dispose();
  }

  Future<void> pickDocument() async {
    setState(() {
      isLoading = true;
      scannedText = '';
    });

    final text = await _fileService.pickFileAndExtractText();

    if (!mounted) return;

    setState(() {
      scannedText = text ?? '';
      isLoading = false;
    });

    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не е пронајден текст во документот.'),
        ),
      );
    }
  }

  Future<void> pickAndScan({bool fromCamera = false}) async {
    setState(() {
      isLoading = true;
      scannedText = '';
    });

    final image = await _ocrService.pickImage(fromCamera: fromCamera);

    if (image == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      return;
    }

    final text = await _ocrService.scanText(image);

    if (!mounted) return;

    setState(() {
      scannedText = text;
      isLoading = false;
    });

    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не е пронајден текст во сликата.'),
        ),
      );
    }

    await _statsService.incrementOCR();
  }

  Future<void> _listen(double speechRate) async {
    if (scannedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Прво прикачи документ или слика.'),
        ),
      );
      return;
    }

    await _ttsService.setSpeechRate(speechRate);
    await _ttsService.speak(scannedText);
    await _statsService.incrementTTS();
  }

  Future<void> _stop() async {
    await _ttsService.stop();
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
                    const OcrHeader(),

                    const SizedBox(height: 28),

                    FileUploadPanel(
                      onPickFile: pickDocument,
                    ),

                    const SizedBox(height: 22),

                    UploadPanel(
                      onCamera: () => pickAndScan(fromCamera: true),
                      onGallery: () => pickAndScan(fromCamera: false),
                    ),

                    const SizedBox(height: 22),

                    DyslexiaSwitch(
                      value: settings.dyslexiaFont,
                      onChanged: settings.setDyslexiaFont,
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'ИЗВЛЕЧЕН ТЕКСТ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),

                    const SizedBox(height: 16),

                    ExtractedTextBox(
                      text: scannedText,
                      isLoading: isLoading,
                      dyslexiaMode: settings.dyslexiaFont,
                      fontSize: settings.fontSize,
                    ),

                    if (scannedText.trim().isNotEmpty) ...[
                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Expanded(
                            child: ListenButton(
                              onTap: () => _listen(settings.speechRate),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: StopButton(onTap: _stop),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            AppBottomNav(
              currentIndex: 2,
              onHomeTap: () => _open(context, const HomeScreen()),
              onReadTap: () => _open(context, const TtsScreen()),
              onScanTap: () {},
              onProfileTap: () => _open(context, const ProfileScreen()),
              onSettingsTap: () => _open(context, const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
