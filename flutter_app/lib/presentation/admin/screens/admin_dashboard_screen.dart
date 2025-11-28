import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../common/widgets/cards/stat_card.dart';
import '../../common/widgets/navigation/app_bar.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Admin Dashboard',
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
              'Dashboard',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: AppSpacing.lg,
              mainAxisSpacing: AppSpacing.lg,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                StatCard(
                  label: 'Total Items',
                  value: '1,234',
                  icon: Icons.inventory,
                  iconColor: AppColors.primary,
                ),
                StatCard(
                  label: 'Active Users',
                  value: '856',
                  icon: Icons.people,
                  iconColor: AppColors.secondary,
                ),
                StatCard(
                  label: 'Pending Requests',
                  value: '42',
                  icon: Icons.pending_actions,
                  iconColor: AppColors.warning,
                ),
                StatCard(
                  label: 'Overdue Items',
                  value: '8',
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
