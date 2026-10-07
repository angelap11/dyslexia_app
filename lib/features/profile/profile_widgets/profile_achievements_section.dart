import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../profile_achievements.dart';

class ProfileAchievementsSection extends StatelessWidget {
  final List<ProfileAchievement> achievements;
  final int previewCount;

  const ProfileAchievementsSection({
    super.key,
    required this.achievements,
    this.previewCount = 4,
  });

  List<ProfileAchievement> get _ordered {
    final unlocked = achievements.where((a) => a.unlocked).toList();
    final locked = achievements.where((a) => !a.unlocked).toList();
    return [...unlocked, ...locked];
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;
    final unlockedCount = achievements.where((item) => item.unlocked).length;
    final showAll = ordered.length <= previewCount;
    final visible = showAll ? ordered : ordered.take(previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Достигнувања',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.3),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final achievement = visible[index];
              return SizedBox(
                width: 108,
                child: _AchievementTile(
                  achievement: achievement,
                  onTap: () => _showDetail(context, achievement),
                ),
              );
            },
          ),
        ),
        if (!showAll) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => _showAll(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(AppTouch.min, AppTouch.min),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: Text(
              'Види ги сите ($unlockedCount/${achievements.length})',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }

  void _showAll(BuildContext context) {
    final ordered = _ordered;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xl,
                AppSpacing.xxl,
                AppSpacing.xxxl,
              ),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appBorder,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Достигнувања',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final achievement in ordered) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: achievement.unlocked
                          ? achievement.color.withValues(alpha: 0.16)
                          : context.appSurfaceMuted,
                      child: Icon(
                        achievement.icon,
                        color: achievement.unlocked
                            ? achievement.color
                            : context.appTextSecondary,
                      ),
                    ),
                    title: Text(achievement.title),
                    trailing: Icon(
                      achievement.unlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_outline_rounded,
                      color: achievement.unlocked
                          ? AppColors.primary
                          : context.appTextSecondary,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showDetail(context, achievement);
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _showDetail(BuildContext context, ProfileAchievement achievement) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: achievement.unlocked
                      ? achievement.color.withValues(alpha: 0.16)
                      : context.appSurfaceMuted,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: achievement.unlocked
                        ? achievement.color.withValues(alpha: 0.4)
                        : context.appBorder,
                    width: 2,
                  ),
                ),
                child: Icon(
                  achievement.icon,
                  color: achievement.unlocked
                      ? achievement.color
                      : context.appTextSecondary,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                achievement.unlocked
                    ? achievement.description
                    : achievement.howToUnlock,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final ProfileAchievement achievement;
  final VoidCallback onTap;

  const _AchievementTile({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    return Material(
      color: unlocked ? context.appSurface : context.appSurfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(
          color: unlocked
              ? achievement.color.withValues(alpha: 0.35)
              : context.appBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unlocked
                      ? achievement.color.withValues(alpha: 0.16)
                      : context.appBorder.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  achievement.icon,
                  color: unlocked
                      ? achievement.color
                      : context.appTextSecondary.withValues(alpha: 0.7),
                  size: 22,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: Text(
                  achievement.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    fontSize: 12,
                    color: unlocked
                        ? context.appTextPrimary
                        : context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
