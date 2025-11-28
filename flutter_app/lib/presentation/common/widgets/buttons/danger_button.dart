import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';

class DangerButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isDisabled;
  final Widget? icon;

  const DangerButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.isDisabled = false,
    this.icon,
  }) : super(key: key);

  @override
  State<DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<DangerButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: widget.isDisabled ? null : widget.onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingMedium,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _isPressed && !widget.isDisabled
              ? AppColors.errorDark
              : AppColors.error,
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
                color: AppColors.white,
                opacity: widget.isDisabled ? 0.6 : 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
