import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final Widget? appBar;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? bottomNavigationBar;
  final Color? backgroundColor;

  const AppShell({
    Key? key,
    required this.child,
    this.appBar,
    this.drawer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor = AppColors.backgroundPrimary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: appBar as PreferredSizeWidget?,
      drawer: isMobile ? drawer : null,
      backgroundColor: backgroundColor,
      body: isMobile
          ? child
          : Row(
              children: [
                if (drawer != null && !isMobile)
                  Container(
                    width: 260,
                    color: AppColors.secondary,
                    child: drawer!,
                  ),
                Expanded(child: child),
              ],
            ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar != null
          ? Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: bottomNavigationBar!,
              ),
            )
          : null,
    );
  }
}
