import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

enum StatusType { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType status;
  final IconData? icon;

  const StatusBadge({
    Key? key,
    required this.label,
    required this.status,
    this.icon,
  }) : super(key: key);

  Color _getBackgroundColor() {
    return switch (status) {
      StatusType.success => AppColors.statusGreen.withOpacity(0.1),
      StatusType.warning => AppColors.statusYellow.withOpacity(0.1),
      StatusType.error => AppColors.statusRed.withOpacity(0.1),
      StatusType.info => AppColors.statusBlue.withOpacity(0.1),
      StatusType.neutral => AppColors.statusGray.withOpacity(0.1),
    };
  }

  Color _getTextColor() {
    return switch (status) {
      StatusType.success => AppColors.statusGreen,
      StatusType.warning => AppColors.statusYellow,
      StatusType.error => AppColors.statusRed,
      StatusType.info => AppColors.statusBlue,
      StatusType.neutral => AppColors.statusGray,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: _getTextColor(),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: _getTextColor(),
            ),
          ),
        ],
      ),
    );
  }
}
