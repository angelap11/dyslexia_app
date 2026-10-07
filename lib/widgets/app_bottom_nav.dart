import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Floating pill navigation — visually distinct from standard bottom bars.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onReadTap;
  final VoidCallback onScanTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onReadTap,
    required this.onScanTap,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md + bottomInset,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.45 : 0.12,
                ),
                blurRadius: 28,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: context.appSurface,
            elevation: 0,
            shape: StadiumBorder(side: BorderSide(color: context.appBorder)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_rounded,
                      label: 'Дома',
                      selected: currentIndex == 0,
                      onTap: onHomeTap,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.menu_book_rounded,
                      label: 'Читај',
                      selected: currentIndex == 1,
                      onTap: onReadTap,
                    ),
                  ),
                  _ScanFab(selected: currentIndex == 2, onTap: onScanTap),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person_rounded,
                      label: 'Профил',
                      selected: currentIndex == 3,
                      onTap: onProfileTap,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.tune_rounded,
                      label: 'Поставки',
                      selected: currentIndex == 4,
                      onTap: onSettingsTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _ScanFab({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: selected
              ? AppColors.primaryButtonGradient
              : const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.document_scanner_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.appTextSecondary;

    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(icon, size: 20, color: color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              strutStyle: const StrutStyle(
                fontSize: 10,
                height: 1.0,
                leading: 0,
                forceStrutHeight: true,
              ),
              style: TextStyle(
                fontSize: 10,
                height: 1.0,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
