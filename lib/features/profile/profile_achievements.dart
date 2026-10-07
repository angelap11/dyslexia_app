import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ProfileAchievement {
  final String id;
  final String title;
  final String description;
  final String howToUnlock;
  final IconData icon;
  final Color color;
  final bool unlocked;

  const ProfileAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.howToUnlock,
    required this.icon,
    required this.color,
    required this.unlocked,
  });
}

List<ProfileAchievement> buildProfileAchievements({
  required int ocrCount,
  required int ttsCount,
  required int savedCount,
}) {
  return [
    ProfileAchievement(
      id: 'first_scan',
      title: 'Прво скенирање',
      description: 'Го скенираше првиот текст. Одлично!',
      howToUnlock: 'Скенирај една страница или слика.',
      icon: Icons.document_scanner_rounded,
      color: AppColors.primary,
      unlocked: ocrCount >= 1,
    ),
    ProfileAchievement(
      id: 'first_listen',
      title: 'Прво слушање',
      description: 'Го слушна првиот текст на глас.',
      howToUnlock: 'Слушај еден текст.',
      icon: Icons.headphones_rounded,
      color: AppColors.lavender,
      unlocked: ttsCount >= 1,
    ),
    ProfileAchievement(
      id: 'five_scans',
      title: '5 скенирања',
      description: 'Скенираше пет текстови. Продолжуваш супер.',
      howToUnlock: 'Скенирај вкупно 5 текстови.',
      icon: Icons.auto_stories_rounded,
      color: AppColors.mint,
      unlocked: ocrCount >= 5,
    ),
    ProfileAchievement(
      id: 'ten_listens',
      title: '10 слушања',
      description: 'Слушаше десет текстови. Увото ти помага при читање.',
      howToUnlock: 'Слушај вкупно 10 текстови.',
      icon: Icons.graphic_eq_rounded,
      color: AppColors.coral,
      unlocked: ttsCount >= 10,
    ),
    ProfileAchievement(
      id: 'saved_text',
      title: 'Зачуван текст',
      description: 'Зачува документ за повторно читање.',
      howToUnlock: 'Скенирај или отвори документ што се зачувува.',
      icon: Icons.bookmark_rounded,
      color: AppColors.gold,
      unlocked: savedCount >= 1,
    ),
    ProfileAchievement(
      id: 'active_reader',
      title: 'Активен читач',
      description: 'Направи пет читачки активности. Ти си во ритам.',
      howToUnlock: 'Направи вкупно 5 скенирања или слушања.',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.coral,
      unlocked: (ocrCount + ttsCount) >= 5,
    ),
  ];
}

String readerStatusLabel({required int ocrCount, required int ttsCount}) {
  final total = ocrCount + ttsCount;
  if (total >= 25) return 'Супер читач';
  if (total >= 10) return 'Вешт читач';
  if (total >= 1) return 'Активен читач';
  return 'Нов читач';
}

class NextAchievementGoal {
  final String title;
  final String message;
  final int current;
  final int target;
  final IconData icon;
  final Color color;

  const NextAchievementGoal({
    required this.title,
    required this.message,
    required this.current,
    required this.target,
    required this.icon,
    required this.color,
  });

  int get remaining => (target - current).clamp(0, target);
}

NextAchievementGoal? nextAchievementGoal({
  required int ocrCount,
  required int ttsCount,
  required int savedCount,
}) {
  if (ocrCount < 1) {
    return NextAchievementGoal(
      title: 'Прво скенирање',
      message: 'Скенирај ја првата страница.',
      current: ocrCount,
      target: 1,
      icon: Icons.document_scanner_rounded,
      color: AppColors.primary,
    );
  }
  if (ttsCount < 1) {
    return NextAchievementGoal(
      title: 'Прво слушање',
      message: 'Слушај еден текст.',
      current: ttsCount,
      target: 1,
      icon: Icons.headphones_rounded,
      color: AppColors.lavender,
    );
  }
  if (savedCount < 1) {
    return NextAchievementGoal(
      title: 'Зачуван текст',
      message: 'Зачувај еден документ за повторно читање.',
      current: savedCount,
      target: 1,
      icon: Icons.bookmark_rounded,
      color: AppColors.gold,
    );
  }
  if (ocrCount + ttsCount < 5) {
    return NextAchievementGoal(
      title: 'Активен читач',
      message:
          'Направи уште ${(5 - ocrCount - ttsCount).clamp(1, 5)} активности.',
      current: ocrCount + ttsCount,
      target: 5,
      icon: Icons.local_fire_department_rounded,
      color: AppColors.coral,
    );
  }
  if (ocrCount < 5) {
    return NextAchievementGoal(
      title: '5 скенирања',
      message:
          'Скенирај уште ${5 - ocrCount} ${5 - ocrCount == 1 ? 'документ' : 'документи'}.',
      current: ocrCount,
      target: 5,
      icon: Icons.auto_stories_rounded,
      color: AppColors.mint,
    );
  }
  if (ttsCount < 10) {
    return NextAchievementGoal(
      title: '10 слушања',
      message:
          'Слушај уште ${10 - ttsCount} ${10 - ttsCount == 1 ? 'текст' : 'текстови'}.',
      current: ttsCount,
      target: 10,
      icon: Icons.graphic_eq_rounded,
      color: AppColors.coral,
    );
  }
  return null;
}
