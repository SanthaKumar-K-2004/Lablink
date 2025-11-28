import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';

class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isDisabled;
  final Widget? icon;

  const SecondaryButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.isDisabled = false,
    this.icon,
  }) : super(key: key);

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingMedium,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _isHovered && !widget.isDisabled
                ? AppColors.neutral50
                : AppColors.white,
            border: Border.all(
              color: _isHovered && !widget.isDisabled
                  ? AppColors.neutral400
                  : AppColors.neutral200,
              width: 2,
            ),
            borderRadius: AppRadius.borderRadiusLg,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                widget.label,
                style: AppTypography.labelLarge.copyWith(
                  color: widget.isDisabled
                      ? AppColors.neutral400
                      : AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
