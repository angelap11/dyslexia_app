import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../statistics/stats_screen.dart';
import '../tts/tts_screen.dart';
import '../ocr/ocr_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import '../auth/auth_service.dart';

import 'home_widgets/hero_section.dart';
import 'home_widgets/action_card.dart';
import '../../widgets/app_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = 'Корисник';

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        userName = user?.displayName ?? 'Корисник';
      });
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeroSection(
                      userName: userName,
                    ),

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

                    ActionCard(
                      icon: Icons.menu_book_rounded,
                      iconColor: const Color(0xFF5F9DDD),
                      title: 'Читај текст',
                      subtitle: 'Внеси текст и слушни го гласно',
                      onTap: () => _open(context, const TtsScreen()),
                    ),

                    const SizedBox(height: 18),

                    ActionCard(
                      icon: Icons.document_scanner_outlined,
                      iconColor: const Color(0xFF8DD8C6),
                      title: 'Скенирај документ',
                      subtitle: 'Слика или PDF — прочитај го лесно',
                      onTap: () => _open(context, const OcrScreen()),
                    ),

                    const SizedBox(height: 18),

                    ActionCard(
                      icon: Icons.bar_chart_rounded,
                      iconColor: const Color(0xFFB39DDB),
                      title: 'Статистика',
                      subtitle: 'Следи го твојот напредок и навики',
                      onTap: () => _open(context, const StatsScreen()),
                    ),

                    const SizedBox(height: 18),

                    ActionCard(
                      icon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFFFFC297),
                      title: 'Мој профил',
                      subtitle: 'Твојот напредок и статистики',
                      onTap: () => _open(context, const ProfileScreen()),
                    ),

                    const SizedBox(height: 38),
                  ],
                ),
              ),
            ),

            AppBottomNav(
              currentIndex: 0,
              onHomeTap: () {},
              onReadTap: () => _open(context, const TtsScreen()),
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