import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'tap_scale.dart';

/// Prominent circular play/stop controls for TTS and OCR read-aloud.
class ReadingControls extends StatelessWidget {
  final bool isReading;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  const ReadingControls({
    super.key,
    required this.isReading,
    required this.onPlay,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.standard,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(
          color: context.appBorder,
          width: context.highContrast ? 1.5 : 1,
        ),
        boxShadow: context.highContrast
            ? AppElevation.none
            : AppElevation.card(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleButton(
            icon: isReading
                ? Icons.graphic_eq_rounded
                : Icons.play_arrow_rounded,
            label: isReading ? 'Слуша' : 'Слушај',
            color: AppColors.primary,
            size: 72,
            onTap: onPlay,
            filled: true,
          ),
          const SizedBox(width: AppSpacing.xxxl),
          _CircleButton(
            icon: Icons.stop_rounded,
            label: 'Стоп',
            color: context.appTextSecondary,
            size: 56,
            onTap: onStop,
            filled: false,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final bool filled;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.size,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: AppMotion.tapScaleStrong,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: filled ? color : context.appSurfaceMuted,
              shape: BoxShape.circle,
              border: filled
                  ? null
                  : Border.all(color: context.appBorder, width: 2),
              boxShadow: filled && !context.highContrast
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: filled ? Colors.white : color,
              size: size * 0.45,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.appTextSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
