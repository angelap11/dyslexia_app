import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../tts/tts_screen.dart';
import '../ocr/ocr_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _goToHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _goToRead(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TtsScreen()),
    );
  }

  void _goToScan(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OcrScreen()),
    );
  }

  void _goToSettings(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    const Text(
                      'Мој профил',
                      style: TextStyle(
                        color: Color(0xFF07162E),
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 26),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF63B5D2),
                            Color(0xFF638FDF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person_outline_rounded,
                              size: 58,
                              color: Color(0xFF3196C2),
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'Ана',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Твојот напредок и статистики',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    const _ProfileStatCard(
                      icon: Icons.local_fire_department_outlined,
                      title: '5 дена низ ред',
                      subtitle: 'Продолжи со читање секој ден',
                    ),

                    const SizedBox(height: 16),

                    const _ProfileStatCard(
                      icon: Icons.access_time_rounded,
                      title: '18 минути читање',
                      subtitle: 'Вкупно читање денес',
                    ),

                    const SizedBox(height: 16),

                    const _ProfileStatCard(
                      icon: Icons.menu_book_outlined,
                      title: '3 завршени текста',
                      subtitle: 'Одличен напредок!',
                    ),

                    const SizedBox(height: 16),

                    const _ProfileStatCard(
                      icon: Icons.emoji_events_outlined,
                      title: '64% дневна цел',
                      subtitle: 'Супер напредуваш денес',
                    ),
                  ],
                ),
              ),
            ),

            _BottomNavBar(
              currentIndex: 3,
              onHomeTap: () => _goToHome(context),
              onReadTap: () => _goToRead(context),
              onScanTap: () => _goToScan(context),
              onProfileTap: () {},
              onSettingsTap: () => _goToSettings(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProfileStatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE7E1D5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFCFF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3196C2),
              size: 32,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF07162E),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF505A70),
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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