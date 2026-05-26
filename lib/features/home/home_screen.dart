import 'package:flutter/material.dart';

import '../tts/tts_screen.dart';
import '../ocr/ocr_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openTts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TtsScreen()),
    );
  }

  void _openOcr(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OcrScreen()),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
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
                    const _HeroSection(),

                    const SizedBox(height: 34),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'ШТО САКАШ ДА НАПРАВИШ?',
                        style: TextStyle(
                          fontSize: 17,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4D5870).withOpacity(0.95),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    _ActionCard(
                      icon: Icons.menu_book_rounded,
                      iconColor: const Color(0xFF5F9DDD),
                      title: 'Читај текст',
                      subtitle: 'Внеси текст и слушни го гласно\n(TTS)',
                      onTap: () => _openTts(context),
                    ),

                    const SizedBox(height: 18),

                    _ActionCard(
                      icon: Icons.document_scanner_outlined,
                      iconColor: const Color(0xFF8DD8C6),
                      title: 'Скенирај документ',
                      subtitle: 'Слика или PDF — прочитај го\nлесно',
                      onTap: () => _openOcr(context),
                    ),

                    const SizedBox(height: 18),

                    _ActionCard(
                      icon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFFFFC297),
                      title: 'Мој профил',
                      subtitle: 'Твојот напредок и статистики',
                      onTap: () => _openProfile(context),
                    ),

                    const SizedBox(height: 38),

                    const _TipCard(),
                  ],
                ),
              ),
            ),

            _BottomNavBar(
              currentIndex: 0,
              onHomeTap: () {},
              onReadTap: () => _openTts(context),
              onScanTap: () => _openOcr(context),
              onProfileTap: () => _openProfile(context),
              onSettingsTap: () => _openSettings(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.fromLTRB(34, 44, 34, 44),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 23),
              SizedBox(width: 12),
              Text(
                'Добро утро',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Здраво, Ана 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Готова ли си да читаш денес?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 36),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 118,
                  height: 118,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 118,
                        height: 118,
                        child: CircularProgressIndicator(
                          value: 0.64,
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '64%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'ДЕНЕС',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 34),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatRow(
                        icon: Icons.local_fire_department_outlined,
                        text: '5 дена низ ред',
                      ),
                      SizedBox(height: 15),
                      _StatRow(
                        icon: Icons.access_time_rounded,
                        text: '18 мин читање',
                      ),
                      SizedBox(height: 15),
                      _StatRow(
                        icon: Icons.menu_book_outlined,
                        text: '3 завршени текста',
                      ),
                    ],
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

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 25),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: const Color(0xFFE7E1D5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),

              const SizedBox(width: 22),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF07162E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.45,
                        color: Color(0xFF505A70),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF31415B),
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: const Color(0xFFE7E1D5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'СОВЕТ НА ДЕНОТ\n\n',
                style: TextStyle(
                  color: Color(0xFF4D5870),
                  fontSize: 16,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: 'Пробај го ',
                style: TextStyle(
                  color: Color(0xFF07162E),
                  fontSize: 22,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'Дислексија режимот',
                style: TextStyle(
                  color: Color(0xFF3196C2),
                  fontSize: 22,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' —\nпоголем простор меѓу зборовите\nпомага при читање.',
                style: TextStyle(
                  color: Color(0xFF07162E),
                  fontSize: 22,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
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