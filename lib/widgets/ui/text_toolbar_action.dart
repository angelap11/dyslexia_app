import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Compact icon action used in OCR/TTS text toolbars.
class TextToolbarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;

  const TextToolbarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? (active ? AppColors.primary : context.appTextSecondary);

    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: resolved, size: 22),
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: active
            ? (color ?? AppColors.primary).withValues(alpha: 0.12)
            : Colors.transparent,
      ),
    );
  }
}
