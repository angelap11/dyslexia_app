import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/ui/icon_badge.dart';
import '../provider.dart';

/// Honest account-sync state for reading preferences.
class SettingsSyncStatusCard extends StatelessWidget {
  final PreferencesSyncStatus status;
  final bool waitingForNetwork;
  final VoidCallback? onRetry;

  static const localNote =
      'Темниот изглед и вклучувањето на линијарот важат само за овој уред.';

  const SettingsSyncStatusCard({
    super.key,
    required this.status,
    required this.waitingForNetwork,
    this.onRetry,
  });

  ({IconData icon, Color color, String message}) _content() {
    switch (status) {
      case PreferencesSyncStatus.synced:
        return (
          icon: Icons.cloud_done_rounded,
          color: AppColors.mint,
          message: 'Поставките за читање се зачувани во твојата сметка.',
        );
      case PreferencesSyncStatus.pending:
        return waitingForNetwork
            ? (
                icon: Icons.cloud_off_rounded,
                color: AppColors.gold,
                message:
                    'Нема интернет. Промените се зачувани на уредот и ќе се '
                    'испратат подоцна.',
              )
            : (
                icon: Icons.cloud_upload_rounded,
                color: AppColors.sky,
                message: 'Промените се зачувани на уредот и се испраќаат…',
              );
      case PreferencesSyncStatus.connecting:
        return waitingForNetwork
            ? (
                icon: Icons.cloud_off_rounded,
                color: AppColors.gold,
                message:
                    'Нема врска за синхронизација. Поставките се зачувани на '
                    'овој уред.',
              )
            : (
                icon: Icons.cloud_sync_rounded,
                color: AppColors.sky,
                message: 'Се проверуваат поставките во сметката…',
              );
      case PreferencesSyncStatus.failed:
        return (
          icon: Icons.error_outline_rounded,
          color: AppColors.coral,
          message:
              'Синхронизацијата не успеа. Промените остануваат зачувани на '
              'уредот.',
        );
      case PreferencesSyncStatus.unavailable:
        return (
          icon: Icons.cloud_off_rounded,
          color: AppColors.lavender,
          message:
              'Синхронизацијата не е достапна. Поставките се зачувани само на '
              'овој уред.',
        );
      case PreferencesSyncStatus.localOnly:
        return (
          icon: Icons.phone_android_rounded,
          color: AppColors.lavender,
          message: 'Поставките се зачувани на овој уред.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content();
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: content.icon,
            color: content.color,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    content.message,
                    style: textTheme.titleMedium?.copyWith(height: 1.3),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(localNote, style: textTheme.bodyMedium),
                if (status == PreferencesSyncStatus.failed &&
                    onRetry != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Обиди се пак'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
