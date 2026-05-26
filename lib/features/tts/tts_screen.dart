import 'package:flutter/material.dart';

import 'tts_service.dart';
import '../home/home_screen.dart';
import '../ocr/ocr_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class TtsScreen extends StatefulWidget {
  const TtsScreen({super.key});

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  final TtsService _tts = TtsService();

  final TextEditingController _controller = TextEditingController(
    text:
    'Читањето е прозорец кон светот. Со\nмалку помош, секој може да отвори\nнови приказни и идеи.',
  );

  bool _isReading = false;

  int get _characterCount => _controller.text.length;

  int get _wordCount {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      return 0;
    }

    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }

  @override
  void dispose() {
    _tts.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startReading() async {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Прво внеси текст!'),
        ),
      );
      return;
    }

    setState(() {
      _isReading = true;
    });

    await _tts.speak(text);
  }

  Future<void> _stopReading() async {
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _isReading = false;
    });
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _goToScan() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OcrScreen()),
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
                    const _TtsHeader(),
                    const SizedBox(height: 38),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFE7E1D5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding:
                              const EdgeInsets.fromLTRB(26, 24, 26, 14),
                              child: TextField(
                                controller: _controller,
                                maxLines: 9,
                                minLines: 9,
                                style: const TextStyle(
                                  fontSize: 23,
                                  height: 1.65,
                                  color: Color(0xFF07162E),
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Внеси или залепи текст...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF6A7284),
                                  ),
                                ),
                                onChanged: (_) {
                                  setState(() {});
                                },
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 26),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFE7E1D5),
                              ),
                            ),

                            Padding(
                              padding:
                              const EdgeInsets.fromLTRB(26, 18, 26, 22),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$_characterCount знаци',
                                    style: const TextStyle(
                                      color: Color(0xFF505A70),
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '$_wordCount зборови',
                                    style: const TextStyle(
                                      color: Color(0xFF505A70),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PrimaryButton(
                              icon: Icons.play_arrow_rounded,
                              label:
                              _isReading ? 'Чита...' : 'Започни читање',
                              onTap: _startReading,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _StopButton(
                              onTap: _stopReading,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Демо приказ — реален TTS може да се вклучи подоцна.',
                        style: TextStyle(
                          color: Color(0xFF505A70),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _BottomNavBar(
              currentIndex: 1,
              onHomeTap: _goToHome,
              onReadTap: () {},
              onScanTap: _goToScan,
              onProfileTap: _goToProfile,
              onSettingsTap: _goToSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _TtsHeader extends StatelessWidget {
  const _TtsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(38, 72, 28, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF63B5D2),
            Color(0xFF638FDF),
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
            'Читај текст',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Внеси или залепи текст за гласно читање',
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

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF63B5D2),
              Color(0xFF638FDF),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 34),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
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

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StopButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE7E1D5),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.stop_rounded,
              color: Color(0xFF07162E),
              size: 34,
            ),
            SizedBox(width: 10),
            Text(
              'Стоп',
              style: TextStyle(
                color: Color(0xFF07162E),
                fontSize: 20,
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