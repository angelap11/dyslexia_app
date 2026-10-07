import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../features/settings/provider.dart';

/// Soft organic blobs behind screen content — calm, not busy.
/// Hidden in Focus Mode and High Contrast to reduce distractions.
class DecorativeBackground extends StatelessWidget {
  final Widget child;
  final bool showBlobs;

  const DecorativeBackground({
    super.key,
    required this.child,
    this.showBlobs = true,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final renderBlobs =
        showBlobs && !settings.focusMode && !settings.highContrastMode;

    return Stack(
      children: [
        if (renderBlobs) ...[
          Positioned(
            top: -90,
            right: -70,
            child: _Blob(
              size: 200,
              color: context.isDark
                  ? AppColors.primary.withValues(alpha: 0.07)
                  : AppColors.blobSage.withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            top: 140,
            left: -100,
            child: _Blob(
              size: 160,
              color: context.isDark
                  ? AppColors.sky.withValues(alpha: 0.05)
                  : AppColors.blobSky.withValues(alpha: 0.4),
            ),
          ),
          Positioned(
            bottom: 160,
            right: -50,
            child: _Blob(
              size: 120,
              color: context.isDark
                  ? AppColors.lavender.withValues(alpha: 0.05)
                  : AppColors.blobLavender.withValues(alpha: 0.32),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
