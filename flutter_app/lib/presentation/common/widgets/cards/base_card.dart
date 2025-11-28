import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';

class BaseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final BorderRadius? borderRadius;
  final bool isClickable;

  const BaseCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.backgroundColor = AppColors.white,
    this.border,
    this.boxShadow,
    this.borderRadius,
    this.isClickable = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final finalBorder = border ??
        Border.all(
          color: AppColors.borderLight,
          width: 1,
        );

    final finalBorderRadius = borderRadius ?? AppRadius.borderRadiusLg;

    return GestureDetector(
      onTap: isClickable ? onTap : null,
      child: MouseRegion(
        cursor: isClickable ? SystemMouseCursors.click : MouseCursor.defer,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: finalBorder,
            borderRadius: finalBorderRadius,
            boxShadow: boxShadow ?? AppShadows.subtle,
          ),
          child: child,
        ),
      ),
    );
  }
}
