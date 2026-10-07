import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'icon_badge.dart';
import 'tap_scale.dart';

/// Primary Scan CTA — large icon + short label.
class HomePrimaryAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const HomePrimaryAction({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: AppMotion.tapScaleStrong,
      child: Semantics(
        button: true,
        label: subtitle == null ? title : '$title. $subtitle',
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.standard,
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: context.highContrast
                ? AppElevation.none
                : AppElevation.primaryGlow(0.28),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet secondary shortcut — icon + short title only.
class HomeSecondaryAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final VoidCallback onTap;

  const HomeSecondaryAction({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: subtitle == null ? title : '$title. $subtitle',
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: context.appBorder,
              width: context.highContrast ? 1.5 : 1,
            ),
            boxShadow: context.highContrast
                ? AppElevation.none
                : AppElevation.soft(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBadge(icon: icon, color: accent, size: 48, iconSize: 26),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 16, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scan / listen / saved texts shortcuts.
class HomeActionCluster extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onListen;
  final VoidCallback onHistory;
  final bool compact;
  final bool showPrimaryScan;

  const HomeActionCluster({
    super.key,
    required this.onScan,
    required this.onListen,
    required this.onHistory,
    required this.compact,
    this.showPrimaryScan = true,
  });

  @override
  Widget build(BuildContext context) {
    final secondaries = [
      HomeSecondaryAction(
        icon: Icons.graphic_eq_rounded,
        title: 'Слушај текст',
        subtitle: 'Слушни го текстот',
        accent: AppColors.lavender,
        onTap: onListen,
      ),
      HomeSecondaryAction(
        icon: Icons.history_rounded,
        title: 'Мои текстови',
        subtitle: 'Отвори ги зачуваните текстови',
        accent: AppColors.mint,
        onTap: onHistory,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPrimaryScan) ...[
          HomePrimaryAction(
            icon: Icons.document_scanner_rounded,
            title: 'Скенирај текст',
            subtitle: 'Сликај или избери текст',
            onTap: onScan,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (compact)
          Column(
            children: [
              for (int i = 0; i < secondaries.length; i++) ...[
                _CompactActionRow(
                  icon: secondaries[i].icon,
                  title: secondaries[i].title,
                  subtitle: secondaries[i].subtitle,
                  accent: secondaries[i].accent,
                  onTap: [onListen, onHistory][i],
                ),
                if (i < secondaries.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < secondaries.length; i++) ...[
                Expanded(child: secondaries[i]),
                if (i < secondaries.length - 1)
                  const SizedBox(width: AppSpacing.md),
              ],
            ],
          ),
      ],
    );
  }
}

class _CompactActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _CompactActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: subtitle == null ? title : '$title. $subtitle',
        child: AnimatedContainer(
          duration: AppMotion.short,
          constraints: const BoxConstraints(minHeight: AppTouch.comfortable),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              IconBadge(icon: icon, color: accent, size: 44, iconSize: 22),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(height: 1.25),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.appTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
