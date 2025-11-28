import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onLeadingTap;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
    this.onLeadingTap,
    this.bottom,
    this.centerTitle = false,
    this.elevation = 0,
    this.backgroundColor = AppColors.secondary,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: AppTypography.headlineLarge.copyWith(
          color: AppColors.white,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      elevation: elevation,
      leading: leading,
      actions: actions,
      bottom: bottom,
      iconTheme: const IconThemeData(color: AppColors.white),
    );
  }
}
