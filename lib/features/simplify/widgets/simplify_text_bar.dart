import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Compact controls: „Поедностави“ + optional Оригинален / Поедноставен toggle.
class SimplifyTextBar extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final bool hasSimplified;
  final bool showingSimplified;
  final VoidCallback onSimplify;
  final ValueChanged<bool> onShowingSimplifiedChanged;

  const SimplifyTextBar({
    super.key,
    required this.enabled,
    required this.isLoading,
    required this.hasSimplified,
    required this.showingSimplified,
    required this.onSimplify,
    required this.onShowingSimplifiedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSimplified) ...[
          _VersionToggle(
            showingSimplified: showingSimplified,
            enabled: !isLoading,
            onChanged: onShowingSimplifiedChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: (!enabled || isLoading) ? null : onSimplify,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(
              isLoading ? 'Се поедноставува…' : 'Поедностави',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Equal-width tabs so long MK labels stay fully readable on small screens.
class _VersionToggle extends StatelessWidget {
  final bool showingSimplified;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _VersionToggle({
    required this.showingSimplified,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appSurfaceMuted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.appBorder),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: _VersionTab(
                label: 'Оригинален текст',
                selected: !showingSimplified,
                enabled: enabled,
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _VersionTab(
                label: 'Поедноставен текст',
                selected: showingSimplified,
                enabled: enabled,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _VersionTab({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 12.5,
      height: 1.15,
      fontWeight: FontWeight.w800,
      color: selected ? AppColors.primary : context.appTextSecondary,
    );

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: context.isDark ? 0.22 : 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg - 1),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg - 1),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: labelStyle,
            ),
          ),
        ),
      ),
    );
  }
}
