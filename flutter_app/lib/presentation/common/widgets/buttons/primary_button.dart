import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final Size? size;
  final Widget? icon;
  final IconPosition iconPosition;

  const PrimaryButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.size = Size.medium,
    this.icon,
    this.iconPosition = IconPosition.left,
  }) : super(key: key);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

enum Size { small, medium, large }
enum IconPosition { left, right }

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = !widget.isDisabled && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled
          ? (_) => _animationController.forward()
          : null,
      onTapUp: isEnabled
          ? (_) {
            _animationController.reverse();
            widget.onPressed?.call();
          }
          : null,
      onTapCancel: isEnabled ? _animationController.reverse : null,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.02).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        ),
        child: Container(
          padding: _getPadding(),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: AppRadius.borderRadiusLg,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null && widget.iconPosition == IconPosition.left) ...[
                widget.icon!,
                const SizedBox(width: AppSpacing.sm),
              ],
              if (widget.isLoading)
                SizedBox(
                  width: _getLoadingSize(),
                  height: _getLoadingSize(),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getTextColor(),
                    ),
                  ),
                )
              else
                Text(
                  widget.label,
                  style: _getTextStyle(),
                ),
              if (widget.icon != null && widget.iconPosition == IconPosition.right) ...[
                const SizedBox(width: AppSpacing.sm),
                widget.icon!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case Size.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingSmall,
          vertical: AppSpacing.sm,
        );
      case Size.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingMedium,
          vertical: AppSpacing.sm,
        );
      case Size.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingLarge,
          vertical: AppSpacing.lg,
        );
    }
  }

  Color _getBackgroundColor() {
    if (widget.isLoading || widget.isDisabled) {
      return AppColors.disabled;
    }
    return AppColors.primary;
  }

  Color _getTextColor() {
    if (widget.isDisabled) {
      return AppColors.white.withOpacity(0.6);
    }
    return AppColors.white;
  }

  TextStyle _getTextStyle() {
    final baseStyle = switch (widget.size) {
      Size.small => AppTypography.labelMedium,
      Size.medium => AppTypography.labelLarge,
      Size.large => AppTypography.headlineSmall,
    };

    return baseStyle.copyWith(
      color: _getTextColor(),
      opacity: widget.isLoading ? 0.3 : 1.0,
    );
  }

  double _getLoadingSize() {
    return switch (widget.size) {
      Size.small => 14,
      Size.medium => 18,
      Size.large => 22,
    };
  }
}
