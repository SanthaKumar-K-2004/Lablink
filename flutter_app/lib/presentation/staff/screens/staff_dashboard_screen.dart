import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../common/widgets/cards/stat_card.dart';
import '../../common/widgets/navigation/app_bar.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Staff Dashboard',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff Dashboard',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.lg,
              mainAxisSpacing: AppSpacing.lg,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                StatCard(
                  label: 'Items in Stock',
                  value: '956',
                  icon: Icons.inventory,
                  iconColor: AppColors.primary,
                ),
                StatCard(
                  label: 'Pending Approvals',
                  value: '24',
                  icon: Icons.pending_actions,
                  iconColor: AppColors.warning,
                ),
                StatCard(
                  label: 'Overdue Requests',
                  value: '5',
                  icon: Icons.error,
                  iconColor: AppColors.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
