import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../features/statistics/stats_service.dart';

/// Simple daily goal on Home.
class HomeProgressCard extends StatelessWidget {
  final int todayActivity;
  final VoidCallback onViewStats;

  const HomeProgressCard({
    super.key,
    required this.todayActivity,
    required this.onViewStats,
  });

  static String _readingWord(int count) {
    return count == 1 ? 'читање' : 'читања';
  }

  @override
  Widget build(BuildContext context) {
    final goal = StatsService.dailyGoal;
    final done = todayActivity.clamp(0, goal);
    final progress = goal == 0 ? 0.0 : (todayActivity / goal).clamp(0.0, 1.0);
    final completed = todayActivity >= goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Мојата цел денес',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.3),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: InkWell(
            onTap: onViewStats,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Ink(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: context.appBorder),
                boxShadow: context.highContrast
                    ? AppElevation.none
                    : AppElevation.soft(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completed
                        ? 'Завршено! ✓'
                        : '$done од $goal ${_readingWord(goal)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 14,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
