import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../statistics/stats_service.dart';
import 'statistics_widgets/stats_dashboard.dart';
import '../../widgets/ui/decorative_background.dart';
import '../../widgets/ui/home_layout.dart';
import '../../core/theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with WidgetsBindingObserver {
  final StatsService _service = StatsService();

  int ocr = 0;
  int tts = 0;
  int saved = 0;
  int streak = 0;
  int todayActivity = 0;
  int todayOcr = 0;
  int todayTts = 0;
  int todaySaved = 0;
  List<DayActivity> weekly = const [];
  WeekComparison weekComparison = const WeekComparison(
    thisWeek: 0,
    lastWeek: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) loadStats();
  }

  Future<void> loadStats() async {
    final o = await _service.getOCRCount();
    final t = await _service.getTTSCount();
    final s = await _service.getSavedTexts();
    final readingStreak = await _service.getReadingStreak();
    final today = await _service.getTodayBreakdown();
    final week = await _service.getWeeklyActivity();
    final comparison = await _service.getWeekComparison();

    if (!mounted) return;
    setState(() {
      ocr = o;
      tts = t;
      saved = s;
      streak = readingStreak;
      todayActivity = today.total;
      todayOcr = today.ocr;
      todayTts = today.tts;
      todaySaved = today.saved;
      weekly = week;
      weekComparison = comparison;
    });
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: DecorativeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final padding = HomeLayout.horizontalPadding(width);

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: loadStats,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    padding,
                    AppSpacing.sm,
                    padding,
                    AppSpacing.huge,
                  ),
                  child: HomeLayout.constrain(
                    screenWidth: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _goBack,
                              tooltip: 'Назад',
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            Expanded(
                              child: Text(
                                'Мој напредок',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(height: 1.2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ProgressOverview(
                          ocr: ocr,
                          tts: tts,
                          saved: saved,
                          streak: streak,
                          todayActivity: todayActivity,
                          todayOcr: todayOcr,
                          todayTts: todayTts,
                          todaySaved: todaySaved,
                          weekly: weekly,
                          weekComparison: weekComparison,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
