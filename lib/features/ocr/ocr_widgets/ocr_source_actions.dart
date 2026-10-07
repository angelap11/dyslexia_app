import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/ui/icon_badge.dart';
import '../../../widgets/ui/tap_scale.dart';

class OcrSourceActions extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onDocument;
  final bool enabled;
  final bool compact;

  const OcrSourceActions({
    super.key,
    required this.onCamera,
    required this.onGallery,
    required this.onDocument,
    this.enabled = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          Expanded(
            child: _SourceCard(
              icon: Icons.photo_camera_rounded,
              color: AppColors.primary,
              title: 'Камера',
              subtitle: 'Сликај текст',
              onTap: enabled ? onCamera : null,
              tall: false,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SourceCard(
              icon: Icons.photo_library_rounded,
              color: AppColors.lavender,
              title: 'Галерија',
              subtitle: 'Избери слика',
              onTap: enabled ? onGallery : null,
              tall: false,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SourceCard(
              icon: Icons.picture_as_pdf_rounded,
              color: AppColors.coral,
              title: 'Документ',
              subtitle: 'Избери PDF',
              onTap: enabled ? onDocument : null,
              tall: false,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _SourceCard(
          icon: Icons.photo_camera_rounded,
          color: AppColors.primary,
          title: 'Камера',
          subtitle: 'Сликај текст',
          onTap: enabled ? onCamera : null,
          tall: true,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SourceCard(
                icon: Icons.photo_library_rounded,
                color: AppColors.lavender,
                title: 'Галерија',
                subtitle: 'Избери слика',
                onTap: enabled ? onGallery : null,
                tall: false,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _SourceCard(
                icon: Icons.picture_as_pdf_rounded,
                color: AppColors.coral,
                title: 'Документ',
                subtitle: 'Избери PDF',
                onTap: enabled ? onDocument : null,
                tall: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool tall;

  const _SourceCard({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.tall,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return TapScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: subtitle == null ? title : '$title. $subtitle',
        child: AnimatedOpacity(
          duration: AppMotion.short,
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: AppMotion.short,
            width: double.infinity,
            constraints: BoxConstraints(minHeight: tall ? 132 : 96),
            padding: EdgeInsets.all(tall ? AppSpacing.xxl : AppSpacing.lg),
            decoration: BoxDecoration(
              color: tall
                  ? color.withValues(alpha: context.isDark ? 0.22 : 0.12)
                  : context.appSurface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: tall ? color.withValues(alpha: 0.45) : context.appBorder,
                width: tall ? 2 : (context.highContrast ? 1.5 : 1),
              ),
              boxShadow: context.highContrast
                  ? AppElevation.none
                  : AppElevation.soft(context),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconBadge(
                  icon: icon,
                  color: color,
                  size: tall ? 64 : 48,
                  iconSize: tall ? 32 : 24,
                ),
                SizedBox(height: tall ? AppSpacing.md : AppSpacing.sm),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: tall ? 22 : 16,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appTextSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
