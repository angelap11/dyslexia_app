import 'package:flutter/material.dart';

import 'ocr_service.dart';
import '../../widgets/dyslexia_text.dart';
import '../tts/tts_service.dart';
import '../tts/tts_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final OcrService _ocrService = OcrService();
  final TtsService _ttsService = TtsService();

  String scannedText = '';
  bool isLoading = false;
  bool dyslexiaMode = true;

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
  }

  Future<void> _listenScannedText() async {
    if (scannedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Прво скенирај слика.'),
        ),
      );
      return;
    }

    await _ttsService.speak(scannedText);
  }

  Future<void> _stopTts() async {
    await _ttsService.stop();
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _goToRead() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TtsScreen()),
    );
  }

  void _goToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _goToSettings() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF3),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _OcrHeader(),

                    const SizedBox(height: 28),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 34, 22, 34),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFE1DDD3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 102,
                              height: 102,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFA5DDBB),
                                    Color(0xFF77D0D5),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Icon(
                                Icons.file_upload_outlined,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),

                            const SizedBox(height: 24),

                            const Text(
                              'Прикачи документ',
                              style: TextStyle(
                                color: Color(0xFF07162E),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            const SizedBox(height: 12),

                            const Text(
                              'Сликај или избери слика од галерија',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF505A70),
                                fontSize: 17,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F1E7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'JPG · PNG',
                                style: TextStyle(
                                  color: Color(0xFF07162E),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 26),

                            Row(
                              children: [
                                Expanded(
                                  child: _UploadButton(
                                    label: 'Камера',
                                    icon: Icons.photo_camera_outlined,
                                    onTap: () => pickAndScan(fromCamera: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _UploadButton(
                                    label: 'Галерија',
                                    icon: Icons.image_outlined,
                                    onTap: () => pickAndScan(fromCamera: false),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE7E1D5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_outlined,
                              color: Color(0xFF3196C2),
                              size: 30,
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Дислексија режим',
                                    style: TextStyle(
                                      color: Color(0xFF07162E),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Посебен фонт и простор',
                                    style: TextStyle(
                                      color: Color(0xFF505A70),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: dyslexiaMode,
                              activeColor: Colors.white,
                              activeTrackColor: const Color(0xFF7DD3C7),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFE8E5DC),
                              onChanged: (value) {
                                setState(() {
                                  dyslexiaMode = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'ИЗВЛЕЧЕН ТЕКСТ',
                        style: TextStyle(
                          fontSize: 17,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4D5870).withOpacity(0.95),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(
                          minHeight: 190,
                        ),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFE7E1D5),
                          ),
                        ),
                        child: _buildExtractedText(),
                      ),
                    ),

                    if (scannedText.trim().isNotEmpty) ...[
                      const SizedBox(height: 22),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ListenButton(
                                onTap: _listenScannedText,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _StopButton(
                                onTap: _stopTts,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            _BottomNavBar(
              currentIndex: 2,
              onHomeTap: _goToHome,
              onReadTap: _goToRead,
              onScanTap: () {},
              onProfileTap: _goToProfile,
              onSettingsTap: _goToSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedText() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3196C2),
        ),
      );
    }

    if (scannedText.trim().isEmpty) {
      return const Center(
        child: Text(
          'Прикачи документ за да го видиш\nизвлечениот текст.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF6A7284),
            fontSize: 18,
            height: 1.5,
          ),
        ),
      );
    }

    if (dyslexiaMode) {
      return SingleChildScrollView(
        child: DyslexiaText(scannedText),
      );
    }

    return SingleChildScrollView(
      child: Text(
        scannedText,
        style: const TextStyle(
          color: Color(0xFF07162E),
          fontSize: 18,
          height: 1.6,
        ),
      ),
    );
  }
}

class _OcrHeader extends StatelessWidget {
  const _OcrHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(38, 72, 28, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFA5DDBB),
            Color(0xFF77D0D5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(38),
          bottomRight: Radius.circular(38),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Скенирај документ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Слика или документ — извади го текстот',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _UploadButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFA5DDBB),
              Color(0xFF77D0D5),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListenButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ListenButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF63B5D2),
              Color(0xFF638FDF),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_up_outlined, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text(
              'Слушај',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StopButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE7E1D5),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stop_rounded, color: Color(0xFF07162E), size: 28),
            SizedBox(width: 10),
            Text(
              'Стоп',
              style: TextStyle(
                color: Color(0xFF07162E),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onReadTap;
  final VoidCallback onScanTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onHomeTap,
    required this.onReadTap,
    required this.onScanTap,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE7E1D5).withOpacity(0.8),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(
            icon: Icons.home_outlined,
            label: 'Дома',
            selected: currentIndex == 0,
            onTap: onHomeTap,
          ),
          _BottomNavItem(
            icon: Icons.menu_book_outlined,
            label: 'Читај',
            selected: currentIndex == 1,
            onTap: onReadTap,
          ),
          _BottomNavItem(
            icon: Icons.document_scanner_outlined,
            label: 'Скенирај',
            selected: currentIndex == 2,
            onTap: onScanTap,
          ),
          _BottomNavItem(
            icon: Icons.person_outline_rounded,
            label: 'Профил',
            selected: currentIndex == 3,
            onTap: onProfileTap,
          ),
          _BottomNavItem(
            icon: Icons.settings_outlined,
            label: 'Поставки',
            selected: currentIndex == 4,
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFF3196C2);
    final Color inactiveColor = const Color(0xFF5E6677);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFCFF2FF) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 29,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}