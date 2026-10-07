import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../features/settings/provider.dart';
import 'text_toolbar_action.dart';

/// Compact Copy / Save / Speed / Delete row for the Listen (TTS) text card.
class ListenTextToolbar extends StatelessWidget {
  final int wordCount;
  final String speedLabel;
  final VoidCallback onCopy;
  final VoidCallback onSpeed;
  final VoidCallback onClear;
  final String title;

  /// Save to History; null hides the action.
  final VoidCallback? onSave;
  final bool saved;
  final bool saving;

  /// Shown next to the word count, e.g. the sync state of the saved item.
  final Widget? status;

  const ListenTextToolbar({
    super.key,
    required this.wordCount,
    required this.speedLabel,
    required this.onCopy,
    required this.onSpeed,
    required this.onClear,
    this.title = 'Текст',
    this.onSave,
    this.saved = false,
    this.saving = false,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.lavender.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.hero),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 340;

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$wordCount',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (status != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(child: status!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              TextToolbarAction(
                icon: Icons.copy_rounded,
                tooltip: 'Копирај',
                onTap: onCopy,
              ),
              if (onSave != null)
                TextToolbarAction(
                  key: const ValueKey('save-text-action'),
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_outlined,
                  tooltip: saved ? 'Зачувано' : 'Зачувај',
                  onTap: saving ? null : onSave,
                  active: saved,
                ),
              if (!narrow)
                TextToolbarAction(
                  icon: Icons.speed_rounded,
                  tooltip: 'Брзина на гласот ($speedLabel)',
                  onTap: onSpeed,
                  color: AppColors.lavender,
                )
              else
                TextToolbarAction(
                  icon: Icons.speed_rounded,
                  tooltip: 'Брзина ($speedLabel)',
                  onTap: onSpeed,
                  color: AppColors.lavender,
                ),
              TextToolbarAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Избриши',
                onTap: onClear,
              ),
            ],
          );
        },
      ),
    );
  }
}

String speechRateLabel(double rate) {
  final presets = AppSettings.speechRatePresets;
  final labels = AppSettings.speechRateLabels;
  var best = 0;
  var bestDist = (rate - presets[0]).abs();
  for (var i = 1; i < presets.length; i++) {
    final d = (rate - presets[i]).abs();
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return labels[best];
}

/// Bottom sheet: Бавно / Нормално / Брзо — same values as Settings.
Future<void> showSpeechRatePicker({
  required BuildContext context,
  required SettingsProvider settings,
}) {
  final presets = AppSettings.speechRatePresets;
  final labels = AppSettings.speechRateLabels;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                'Брзина на гласот',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < presets.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _SpeedOptionTile(
                  label: labels[i],
                  selected: speechRateLabel(settings.speechRate) == labels[i],
                  onTap: () {
                    settings.setSpeechRate(presets[i]);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _SpeedOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.lavender.withValues(alpha: context.isDark ? 0.22 : 0.12)
          : context.appSurfaceMuted.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.lavender : context.appBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: AppColors.lavender),
            ],
          ),
        ),
      ),
    );
  }
}
