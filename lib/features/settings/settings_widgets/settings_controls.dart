import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/ui/icon_badge.dart';
import '../../../widgets/ui/tap_scale.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.3),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
  }
}

/// Compact visual setting tile: icon + short label + value / check.
class SettingsVisualTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? valueLabel;
  final bool? selected;
  final VoidCallback onTap;

  const SettingsVisualTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.valueLabel,
    this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = selected == true;
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.short,
        curve: AppMotion.standard,
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isOn
              ? color.withValues(alpha: context.isDark ? 0.22 : 0.12)
              : context.appSurface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isOn ? color : context.appBorder,
            width: isOn ? 2 : (context.highContrast ? 1.5 : 1),
          ),
          boxShadow: context.highContrast
              ? AppElevation.none
              : AppElevation.soft(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                IconBadge(icon: icon, color: color, size: 44, iconSize: 22),
                const Spacer(),
                if (selected != null)
                  Icon(
                    selected!
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 22,
                    color: selected! ? color : context.appTextSecondary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(height: 1.2),
            ),
            if (valueLabel != null && valueLabel!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                valueLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Responsive wrap of visual setting tiles (2 cols mobile, 3–4 on wide).
class SettingsTileGrid extends StatelessWidget {
  final List<Widget> tiles;

  const SettingsTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 720
            ? 4
            : w >= 520
            ? 3
            : 2;
        final gap = AppSpacing.md;
        final tileW = (w - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: tileW, child: tile),
          ],
        );
      },
    );
  }
}

/// Bottom sheet for a continuous value (font size, speech rate, …).
Future<void> showSettingsSliderSheet({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Color color,
  required double value,
  required double min,
  required double max,
  required int divisions,
  required String Function(double) valueLabel,
  required ValueChanged<double> onChanged,
  String lowLabel = 'A',
  String highLabel = 'A',
  double lowLabelSize = 14,
  double highLabelSize = 22,
  Widget Function(double value)? previewBuilder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (ctx) {
      var local = value.clamp(min, max);
      return StatefulBuilder(
        builder: (context, setLocal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
                    IconBadge(icon: icon, color: color, size: 48, iconSize: 24),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(height: 1.25),
                      ),
                    ),
                    Text(
                      valueLabel(local),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (previewBuilder != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  previewBuilder(local),
                ],
                const SizedBox(height: AppSpacing.md),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 20,
                    ),
                  ),
                  child: Slider(
                    value: local,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: (v) {
                      setLocal(() => local = v);
                      onChanged(v);
                    },
                  ),
                ),
                Row(
                  children: [
                    Text(
                      lowLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: lowLabelSize,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      highLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: highLabelSize,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Compact toggle: icon + short title + switch. No paragraph / status text.
class SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggleRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              IconBadge(icon: icon, color: color, size: 44, iconSize: 22),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(height: 1.25),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact slider: icon + short title + value + control.
class SettingsSliderBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String lowLabel;
  final String highLabel;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final double lowLabelSize;
  final double highLabelSize;

  const SettingsSliderBlock({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.lowLabel,
    required this.highLabel,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.lowLabelSize = 15,
    this.highLabelSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: color, size: 44, iconSize: 22),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(height: 1.25),
                ),
              ),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            children: [
              Text(
                lowLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: lowLabelSize,
                  color: context.appTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                highLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: highLabelSize,
                  height: 1,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String badge;

  const SettingsInfoRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 44, iconSize: 22),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(height: 1.25),
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.sm),
          ],
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.mint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ThemeChoiceRow extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const ThemeChoiceRow({
    super.key,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SettingsVisualTile(
            icon: Icons.wb_sunny_rounded,
            color: AppColors.gold,
            title: 'Светла',
            selected: !isDark,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SettingsVisualTile(
            icon: Icons.dark_mode_rounded,
            color: AppColors.lavender,
            title: 'Темна',
            selected: isDark,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

/// Compact multi-option pill/row selector (font size, speed, appearance).
class SettingsChoiceChips extends StatelessWidget {
  final List<SettingsChoiceOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SettingsChoiceChips({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          Expanded(
            child: _ChoiceChip(
              option: options[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ),
          if (i < options.length - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

class SettingsChoiceOption {
  final String label;
  final IconData? icon;

  const SettingsChoiceOption({required this.label, this.icon});
}

class _ChoiceChip extends StatelessWidget {
  final SettingsChoiceOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.short,
        curve: AppMotion.standard,
        constraints: const BoxConstraints(minHeight: AppTouch.min),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: context.isDark ? 0.28 : 0.14)
              : context.appSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? color : context.appBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 22,
                color: selected ? color : context.appTextSecondary,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: selected ? color : context.appTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded surface wrapping compact setting rows.
class SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroupCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.appBorder),
        boxShadow: context.highContrast
            ? AppElevation.none
            : AppElevation.soft(context),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 76, color: context.appBorder),
          ],
        ],
      ),
    );
  }
}

/// Labeled block with a choice row underneath.
class SettingsLabeledChoice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<SettingsChoiceOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SettingsLabeledChoice({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, color: color, size: 44, iconSize: 22),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(height: 1.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SettingsChoiceChips(
            options: options,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}
