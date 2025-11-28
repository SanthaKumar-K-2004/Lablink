import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isDisabled;
  final Widget? icon;

  const GhostButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.isDisabled = false,
    this.icon,
  }) : super(key: key);

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
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
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _isHovered && !widget.isDisabled
                ? AppColors.neutral50
                : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
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
