import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/ui/profile_stat_card.dart';

class ProfileProgressSection extends StatelessWidget {
  final int ocrCount;
  final int ttsCount;

  const ProfileProgressSection({
    super.key,
    required this.ocrCount,
    required this.ttsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Мој напредок',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.3),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final metrics = [
              ProfileStatCard(
                value: '$ocrCount',
                label: 'скенирања',
                color: AppColors.mint,
                icon: Icons.document_scanner_outlined,
              ),
              ProfileStatCard(
                value: '$ttsCount',
                label: 'слушања',
                color: AppColors.lavender,
                icon: Icons.headphones_rounded,
              ),
            ];

            return Row(
              children: [
                Expanded(child: metrics[0]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: metrics[1]),
              ],
            );
          },
        ),
      ],
    );
  }
}
