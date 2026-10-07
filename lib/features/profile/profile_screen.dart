import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../history/saved_texts_controller.dart';
import '../home/home_screen.dart';
import '../tts/tts_screen.dart';
import '../ocr/ocr_screen.dart';
import '../settings/provider.dart';
import '../settings/settings_screen.dart';
import '../statistics/stats_screen.dart';
import '../statistics/stats_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/ui/decorative_background.dart';
import '../../widgets/ui/home_layout.dart';
import '../../widgets/ui/icon_badge.dart';
import '../../widgets/ui/tap_scale.dart';
import '../../core/theme.dart';
import '../auth/auth_service.dart';
import 'profile_achievements.dart';
import 'profile_widgets/profile_achievements_section.dart';
import 'profile_widgets/profile_identity_header.dart';
import 'profile_widgets/profile_progress_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final StatsService _stats = StatsService();

  String userName = 'Корисник';
  int ocrCount = 0;
  int ttsCount = 0;
  int savedCount = 0;
  int streak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _authService.resolveDisplayName();
    final o = await _stats.getOCRCount();
    final t = await _stats.getTTSCount();
    final s = await _stats.getSavedTexts();
    final readingStreak = await _stats.getReadingStreak();
    if (!mounted) return;
    setState(() {
      userName = (name != null && name.isNotEmpty) ? name : 'Корисник';
      ocrCount = o;
      ttsCount = t;
      savedCount = s;
      streak = readingStreak;
    });
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _load());
  }

  Future<void> _confirmLogout() async {
    final settingsPending = context.read<SettingsProvider>().hasPendingSync;
    final textsPending =
        context.read<SavedTextsController?>()?.hasPendingSync ?? false;
    final pendingWhat = settingsPending && textsPending
        ? 'Некои промени во поставките и зачуваните текстови'
        : settingsPending
        ? 'Некои промени во поставките'
        : 'Некои зачувани текстови';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Одјави се?'),
        content: Text(
          settingsPending || textsPending
              ? 'Ќе се вратиш на екранот за најава.\n\n'
                    '$pendingWhat уште не се синхронизирани. '
                    'Остануваат зачувани на овој уред и ќе се испратат '
                    'кога повторно ќе се најавиш тука.'
              : 'Ќе се вратиш на екранот за најава.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Одјави се'),
          ),
        ],
      ),
    );

    if (ok == true) await _logout();
  }

  Future<void> _logout() async {
    // Send pending preference edits while this account is still signed in;
    // anything unacknowledged stays pending under this account's uid.
    final savedTexts = context.read<SavedTextsController?>();
    await Future.wait([
      context.read<SettingsProvider>().flushPendingSync(),
      if (savedTexts != null) savedTexts.flushPendingSync(),
    ]);
    // AuthGate listens to authStateChanges and replaces the session Navigator
    // with LoginScreen — clearing Profile/Home from the stack.
    await _authService.logout();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = userName.split(' ').first;
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
    final achievements = buildProfileAchievements(
      ocrCount: ocrCount,
      ttsCount: ttsCount,
      savedCount: savedCount,
    );

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
                    final padding = HomeLayout.horizontalPadding(width);

                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          padding,
                          AppSpacing.xl,
                          padding,
                          AppSpacing.xxl,
                        ),
                        child: HomeLayout.constrain(
                          screenWidth: width,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProfileIdentityHeader(
                                initial: initial,
                                name: firstName,
                                status: readerStatusLabel(
                                  ocrCount: ocrCount,
                                  ttsCount: ttsCount,
                                ),
                                streak: streak,
                              ),

                              const SizedBox(height: AppSpacing.xxxl),

                              ProfileProgressSection(
                                ocrCount: ocrCount,
                                ttsCount: ttsCount,
                              ),

                              const SizedBox(height: AppSpacing.xxxl),

                              ProfileAchievementsSection(
                                achievements: achievements,
                              ),

                              const SizedBox(height: AppSpacing.xxxl),

                              _ProfileNavButton(
                                icon: Icons.insights_rounded,
                                color: AppColors.mint,
                                title: 'Мој напредок',
                                onTap: () => _open(const StatsScreen()),
                              ),

                              const SizedBox(height: AppSpacing.md),

                              _ProfileNavButton(
                                icon: Icons.settings_rounded,
                                color: context.appTextSecondary,
                                title: 'Поставки',
                                onTap: () => _open(const SettingsScreen()),
                              ),

                              const SizedBox(height: AppSpacing.xxl),

                              _ProfileLogoutButton(onTap: _confirmLogout),

                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              AppBottomNav(
                currentIndex: 3,
                onHomeTap: () => _open(const HomeScreen()),
                onReadTap: () => _open(const TtsScreen()),
                onScanTap: () => _open(const OcrScreen()),
                onProfileTap: () {},
                onSettingsTap: () => _open(const SettingsScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileNavButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _ProfileNavButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: AppTouch.comfortable),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: context.appBorder),
          boxShadow: context.highContrast
              ? AppElevation.none
              : AppElevation.soft(context),
        ),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 44, iconSize: 22),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(height: 1.25),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _ProfileLogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileLogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.45)),
          minimumSize: const Size(double.infinity, AppTouch.min),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
        child: const Text(
          'Одјави се',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }
}
