import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../ocr/ocr_screen.dart';
import '../../profile/profile_achievements.dart';
import '../stats_service.dart';

/// Child-friendly progress overview for "Мој напредок".
class ProgressOverview extends StatelessWidget {
  final int ocr;
  final int tts;
  final int saved;
  final int streak;
  final int todayActivity;
  final int todayOcr;
  final int todayTts;
  final int todaySaved;
  final List<DayActivity> weekly;
  final WeekComparison weekComparison;

  const ProgressOverview({
    super.key,
    required this.ocr,
    required this.tts,
    required this.saved,
    required this.streak,
    required this.todayActivity,
    required this.todayOcr,
    required this.todayTts,
    required this.todaySaved,
    required this.weekly,
    required this.weekComparison,
  });

  int get total => ocr + tts + saved;
  bool get isEmpty => total == 0 && todayActivity == 0;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return const _EmptyProgress();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NextAchievementCard(ocr: ocr, tts: tts, saved: saved),
        const SizedBox(height: AppSpacing.xxl),
        _WeekSummaryCard(
          weekTotal: weekComparison.thisWeek,
          ocr: ocr,
          tts: tts,
        ),
        if (streak > 0) ...[
          const SizedBox(height: AppSpacing.xxl),
          _StreakCard(streak: streak),
        ],
      ],
    );
  }
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(
          alpha: context.isDark ? 0.18 : 0.08,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Започни',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(height: 1.3),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OcrScreen()),
                );
              },
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('Скенирај текст'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextAchievementCard extends StatelessWidget {
  final int ocr;
  final int tts;
  final int saved;

  const _NextAchievementCard({
    required this.ocr,
    required this.tts,
    required this.saved,
  });

  @override
  Widget build(BuildContext context) {
    final goal = nextAchievementGoal(
      ocrCount: ocr,
      ttsCount: tts,
      savedCount: saved,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Следна цел',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(height: 1.3),
          ),
          const SizedBox(height: AppSpacing.md),
          if (goal == null)
            Text(
              'Сите цели!',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.4),
            )
          else ...[
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: goal.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(goal.icon, color: goal.color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: goal.target == 0 ? 0 : goal.current / goal.target,
                minHeight: 12,
                backgroundColor: goal.color.withValues(alpha: 0.14),
                color: goal.color,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${goal.current.clamp(0, goal.target)} од ${goal.target}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            if (goal.remaining > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Уште ${goal.remaining} до следната цел',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appTextSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final int weekTotal;
  final int ocr;
  final int tts;

  const _WeekSummaryCard({
    required this.weekTotal,
    required this.ocr,
    required this.tts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Оваа недела',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(height: 1.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$weekTotal ${weekTotal == 1 ? 'активност' : 'активности'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Вкупно',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('$ocr скенирања', style: Theme.of(context).textTheme.bodyLarge),
          Text('$tts слушања', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: context.isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.coral,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '$streak ${streak == 1 ? 'ден' : 'дена'} по ред',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
