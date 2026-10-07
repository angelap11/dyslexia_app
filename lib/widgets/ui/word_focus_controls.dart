import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Visible on-screen «Фокус на збор» switch for a reading card.
///
/// [onChanged] null disables the switch. [action] (e.g. «Уреди текст») sits
/// beside the switch on wide layouts and wraps below it on narrow ones or
/// with large text.
class WordFocusSwitchRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? hint;
  final Widget? action;

  const WordFocusSwitchRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.action,
  });

  static const String label = 'Фокус на збор';

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final active = value && enabled;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inlineAction =
              action != null &&
              constraints.maxWidth >=
                  MediaQuery.textScalerOf(context).scale(420);

          final row = Row(
            children: [
              Icon(
                Icons.blur_on_rounded,
                size: 22,
                color: active ? AppColors.primary : context.appTextSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: enabled
                              ? context.appTextPrimary
                              : context.appTextSecondary,
                        ),
                      ),
                      if (hint != null)
                        Text(
                          hint!,
                          style: textTheme.bodySmall?.copyWith(height: 1.25),
                        ),
                    ],
                  ),
                ),
              ),
              if (inlineAction) ...[
                const SizedBox(width: AppSpacing.xs),
                action!,
              ],
              Semantics(
                label: label,
                hint: hint,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          );

          if (action == null || inlineAction) return row;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row,
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
            ],
          );
        },
      ),
    );
  }
}

/// Sharp, always-visible way to clear the focused word (also for screen
/// readers). Word Focus itself stays enabled.
class WordFocusClearButton extends StatelessWidget {
  final VoidCallback onPressed;

  const WordFocusClearButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      elevation: context.highContrast ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.blur_off_rounded, size: 20),
        label: const Text('Тргни фокус'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(AppTouch.min, AppTouch.min),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
