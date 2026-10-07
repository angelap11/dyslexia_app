import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Compact, personal greeting — avatar opens Profile, gear opens Settings.
class HomeGreetingHeader extends StatelessWidget {
  final String firstName;
  final String initial;
  final String message;
  final bool nameLoading;
  final VoidCallback onAvatarTap;
  final VoidCallback onSettingsTap;

  const HomeGreetingHeader({
    super.key,
    required this.firstName,
    required this.initial,
    required this.message,
    this.nameLoading = false,
    required this.onAvatarTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = nameLoading
        ? 'Здраво'
        : (firstName.isEmpty ? 'Здраво' : 'Здраво, $firstName');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: 'Отвори профил',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAvatarTap,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Center(
                  child: nameLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          initial.isNotEmpty ? initial : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            height: 1,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ЧитајЛесно',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                greeting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 24, height: 1.2),
              ),
              if (message.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: onSettingsTap,
          tooltip: 'Поставки',
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: context.appSurface,
            side: BorderSide(color: context.appBorder),
          ),
          icon: Icon(Icons.settings_rounded, color: context.appTextSecondary),
        ),
      ],
    );
  }
}
