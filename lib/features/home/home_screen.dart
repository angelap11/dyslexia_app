import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../history/history_screen.dart';
import '../statistics/stats_screen.dart';
import '../statistics/stats_service.dart';
import '../tts/tts_screen.dart';
import '../ocr/ocr_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

import '../../widgets/app_bottom_nav.dart';
import '../../widgets/ui/decorative_background.dart';
import '../../widgets/ui/home_action_cluster.dart';
import '../../widgets/ui/home_greeting_header.dart';
import '../../widgets/ui/home_layout.dart';
import '../../widgets/ui/home_progress_card.dart';
import '../../core/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final StatsService _stats = StatsService();

  /// null = still resolving display name (do not show fallback "Корисник").
  String? userName;
  int todayActivity = 0;
  int streak = 0;
  StreamSubscription<User?>? _userSub;

  @override
  void initState() {
    super.initState();
    _resolveUserName();
    _userSub = _authService.userChanges().listen((user) {
      if (!mounted) return;
      final name = user?.displayName?.trim();
      if (name != null && name.isNotEmpty) {
        setState(() => userName = name);
      }
    });
    _loadHomeData();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveUserName() async {
    final name = await _authService.resolveDisplayName();
    if (!mounted) return;
    setState(() {
      // Only fall back after reload — never flash "Корисник" first.
      userName = (name != null && name.isNotEmpty) ? name : 'Корисник';
    });
  }

  Future<void> _loadHomeData() async {
    final today = await _stats.getTodayActivityCount();
    final readingStreak = await _stats.getReadingStreak();

    if (!mounted) return;

    setState(() {
      todayActivity = today;
      streak = readingStreak;
    });
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, b) => screen,
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    ).then((_) {
      _loadHomeData();
      _resolveUserName();
    });
  }

  String _greetingMessage() {
    if (streak > 0) return '🔥 $streak';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final nameReady = userName != null;
    final firstName = nameReady ? userName!.split(' ').first : '';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';

    return Scaffold(
      backgroundColor: context.appBackground,
      body: DecorativeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final pad = HomeLayout.horizontalPadding(width);
                    final compact = HomeLayout.isCompact(width);

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        pad,
                        AppSpacing.xl,
                        pad,
                        AppSpacing.xxl,
                      ),
                      child: HomeLayout.constrain(
                        screenWidth: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HomeGreetingHeader(
                              firstName: firstName,
                              initial: initial,
                              message: _greetingMessage(),
                              nameLoading: !nameReady,
                              onAvatarTap: () => _open(const ProfileScreen()),
                              onSettingsTap: () =>
                                  _open(const SettingsScreen()),
                            ),
                            const SizedBox(height: AppSpacing.xxxl),
                            HomeActionCluster(
                              compact: compact,
                              onScan: () => _open(const OcrScreen()),
                              onListen: () => _open(const TtsScreen()),
                              onHistory: () => _open(const HistoryScreen()),
                            ),
                            const SizedBox(height: AppSpacing.xxxl),
                            HomeProgressCard(
                              todayActivity: todayActivity,
                              onViewStats: () => _open(const StatsScreen()),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              AppBottomNav(
                currentIndex: 0,
                onHomeTap: () {},
                onReadTap: () => _open(const TtsScreen()),
                onScanTap: () => _open(const OcrScreen()),
                onProfileTap: () => _open(const ProfileScreen()),
                onSettingsTap: () => _open(const SettingsScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
