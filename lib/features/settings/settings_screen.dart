import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/ui/decorative_background.dart';
import '../../widgets/ui/home_layout.dart';
import '../../widgets/ui/icon_badge.dart';
import '../home/home_screen.dart';
import '../ocr/ocr_screen.dart';
import '../profile/profile_screen.dart';
import '../tts/tts_screen.dart';
import 'provider.dart';
import 'settings_widgets/settings_controls.dart';
import 'settings_widgets/settings_sync_status.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _fontPresets = <double>[14, 17, 26];
  static List<double> get _speedPresets => AppSettings.speechRatePresets;

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  int _nearestIndex(double value, List<double> presets) {
    var best = 0;
    var bestDist = (value - presets[0]).abs();
    for (var i = 1; i < presets.length; i++) {
      final d = (value - presets[i]).abs();
      if (d < bestDist) {
        best = i;
        bestDist = d;
      }
    }
    return best;
  }

  int _appearanceIndex(SettingsProvider settings) {
    if (settings.highContrastMode) return 2;
    if (settings.darkMode) return 1;
    return 0;
  }

  Future<void> _confirmReset(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Да ги вратиме поставките?'),
        content: const Text(
          'Сите поставки ќе се вратат на почетните вредности.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Откажи'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Врати'),
          ),
        ],
      ),
    );
    if (ok == true) await settings.resetToDefaults();
  }

  Future<void> _setAppearance(SettingsProvider settings, int index) async {
    switch (index) {
      case 1:
        await settings.setHighContrastMode(false);
        await settings.setDarkMode(true);
      case 2:
        await settings.setHighContrastMode(true);
      default:
        await settings.setHighContrastMode(false);
        await settings.setDarkMode(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final fontIndex = _nearestIndex(settings.fontSize, _fontPresets);
    final speedIndex = _nearestIndex(settings.speechRate, _speedPresets);
    final appearanceIndex = _appearanceIndex(settings);

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

                    return SingleChildScrollView(
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
                            Row(
                              children: [
                                IconBadge(
                                  icon: Icons.tune_rounded,
                                  color: AppColors.primary,
                                  size: 48,
                                  iconSize: 26,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    'Поставки',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(height: 1.2),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.xxl),

                            SettingsSection(
                              title: 'Читање',
                              children: [
                                SettingsGroupCard(
                                  children: [
                                    SettingsToggleRow(
                                      icon: Icons.font_download_rounded,
                                      color: AppColors.coral,
                                      title: 'Полесен фонт',
                                      value: settings.dyslexiaFont,
                                      onChanged: settings.setDyslexiaFont,
                                    ),
                                    SettingsLabeledChoice(
                                      icon: Icons.format_size_rounded,
                                      color: AppColors.primary,
                                      title: 'Големина на текст',
                                      options: const [
                                        SettingsChoiceOption(label: 'Мал'),
                                        SettingsChoiceOption(label: 'Среден'),
                                        SettingsChoiceOption(label: 'Голем'),
                                      ],
                                      selectedIndex: fontIndex,
                                      onSelected: (i) =>
                                          settings.setFontSize(_fontPresets[i]),
                                    ),
                                    SettingsToggleRow(
                                      icon: Icons.horizontal_rule_rounded,
                                      color: AppColors.sky,
                                      title: 'Линијар за читање',
                                      value: settings.readingRulerEnabled,
                                      onChanged:
                                          settings.setReadingRulerEnabled,
                                    ),
                                    SettingsToggleRow(
                                      icon: Icons.center_focus_strong_rounded,
                                      color: AppColors.mint,
                                      title: 'Фокус при читање',
                                      value: settings.focusMode,
                                      onChanged: settings.setFocusMode,
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.xxxl),

                            SettingsSection(
                              title: 'Слушање',
                              children: [
                                SettingsGroupCard(
                                  children: [
                                    SettingsLabeledChoice(
                                      icon: Icons.speed_rounded,
                                      color: AppColors.lavender,
                                      title: 'Брзина на гласот',
                                      options: const [
                                        SettingsChoiceOption(label: 'Бавно'),
                                        SettingsChoiceOption(label: 'Нормално'),
                                        SettingsChoiceOption(label: 'Брзо'),
                                      ],
                                      selectedIndex: speedIndex,
                                      onSelected: (i) => settings.setSpeechRate(
                                        _speedPresets[i],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.xxxl),

                            SettingsSection(
                              title: 'Изглед',
                              children: [
                                SettingsGroupCard(
                                  children: [
                                    SettingsLabeledChoice(
                                      icon: Icons.palette_rounded,
                                      color: AppColors.gold,
                                      title: 'Тема',
                                      options: const [
                                        SettingsChoiceOption(
                                          label: 'Светло',
                                          icon: Icons.wb_sunny_rounded,
                                        ),
                                        SettingsChoiceOption(
                                          label: 'Темно',
                                          icon: Icons.dark_mode_rounded,
                                        ),
                                        SettingsChoiceOption(
                                          label: 'Висок контраст',
                                          icon: Icons.contrast_rounded,
                                        ),
                                      ],
                                      selectedIndex: appearanceIndex,
                                      onSelected: (i) =>
                                          _setAppearance(settings, i),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.xxxl),

                            SettingsSyncStatusCard(
                              status: settings.syncStatus,
                              waitingForNetwork: settings.syncWaitingForNetwork,
                              onRetry: settings.retrySync,
                            ),

                            const SizedBox(height: AppSpacing.xxl),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _confirmReset(context, settings),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.appTextSecondary,
                                  side: BorderSide(color: context.appBorder),
                                  minimumSize: const Size(
                                    double.infinity,
                                    AppTouch.min,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                    vertical: AppSpacing.lg,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xl,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Врати стандардни поставки',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              AppBottomNav(
                currentIndex: 4,
                onHomeTap: () => _navigate(context, const HomeScreen()),
                onReadTap: () => _navigate(context, const TtsScreen()),
                onScanTap: () => _navigate(context, const OcrScreen()),
                onProfileTap: () => _navigate(context, const ProfileScreen()),
                onSettingsTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
