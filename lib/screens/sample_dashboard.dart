import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/balance_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/feature_card.dart';
import '../widgets/transaction_item.dart';
import '../widgets/empty_state.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/page_animations.dart';

/// Beautiful Sample Dashboard - Showcasing all new components
class SampleDashboard extends StatelessWidget {
  const SampleDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '💰 SmartSave',
        gradient: AppTheme.primaryGradient,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: AnimatedPage(
        child: SingleChildScrollView(
          padding: Responsive.getPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Text
              Text(
                'Welcome back! 👋',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Here\'s your financial overview',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),

              // Balance Card
              BalanceCard(
                balance: 125450.75,
                title: 'Total Savings',
                icon: Icons.account_balance_wallet,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View wallet tapped!')),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Statistics Section
              Text(
                'Quick Stats',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: Responsive.getGridCount(context, mobile: 2),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  StaggeredListItem(
                    index: 0,
                    child: StatCard(
                      title: 'Active Goals',
                      value: '8',
                      icon: Icons.flag,
                      color: AppTheme.accentColor,
                      onTap: () {},
                    ),
                  ),
                  StaggeredListItem(
                    index: 1,
                    child: StatCard(
                      title: 'Completed',
                      value: '24',
                      icon: Icons.check_circle,
                      color: AppTheme.successColor,
                      onTap: () {},
                    ),
                  ),
                  StaggeredListItem(
                    index: 2,
                    child: StatCard(
                      title: 'This Month',
                      value: 'KSh 45K',
                      icon: Icons.trending_up,
                      color: AppTheme.infoColor,
                      onTap: () {},
                    ),
                  ),
                  StaggeredListItem(
                    index: 3,
                    child: StatCard(
                      title: 'Loan Offers',
                      value: '3',
                      icon: Icons.monetization_on,
                      color: AppTheme.warningColor,
                      onTap: () {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Features Section
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  StaggeredListItem(
                    index: 4,
                    child: FeatureCard(
                      title: 'Add Money',
                      icon: Icons.add_card,
                      onTap: () {
                        _showFeatureDialog(context, 'Add Money');
                      },
                      color: AppTheme.successColor,
                    ),
                  ),
                  StaggeredListItem(
                    index: 5,
                    child: FeatureCard(
                      title: 'Send',
                      icon: Icons.send,
                      onTap: () {
                        _showFeatureDialog(context, 'Send Money');
                      },
                      color: AppTheme.infoColor,
                    ),
                  ),
                  StaggeredListItem(
                    index: 6,
                    child: FeatureCard(
                      title: 'Pay Bills',
                      icon: Icons.receipt_long,
                      onTap: () {
                        _showFeatureDialog(context, 'Pay Bills');
                      },
                      color: AppTheme.warningColor,
                    ),
                  ),
                  StaggeredListItem(
                    index: 7,
                    child: FeatureCard(
                      title: 'Goals',
                      icon: Icons.track_changes,
                      onTap: () {
                        _showFeatureDialog(context, 'Savings Goals');
                      },
                      color: AppTheme.accentColor,
                    ),
                  ),
                  StaggeredListItem(
                    index: 8,
                    child: FeatureCard(
                      title: 'Loans',
                      icon: Icons.account_balance,
                      onTap: () {
                        _showFeatureDialog(context, 'Loans');
                      },
                      color: AppTheme.primaryColor,
                      badge: 'New',
                    ),
                  ),
                  StaggeredListItem(
                    index: 9,
                    child: FeatureCard(
                      title: 'More',
                      icon: Icons.apps,
                      onTap: () {
                        _showFeatureDialog(context, 'More Features');
                      },
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Transactions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sample Transactions
              StaggeredListItem(
                index: 10,
                child: TransactionItem(
                  title: 'Salary Deposit',
                  subtitle: 'Monthly Income',
                  amount: 75000,
                  date: DateTime.now().subtract(const Duration(days: 1)),
                  isIncome: true,
                  icon: Icons.work,
                ),
              ),
              StaggeredListItem(
                index: 11,
                child: TransactionItem(
                  title: 'Savings Goal',
                  subtitle: 'Emergency Fund',
                  amount: 5000,
                  date: DateTime.now().subtract(const Duration(days: 2)),
                  isIncome: false,
                  icon: Icons.savings,
                ),
              ),
              StaggeredListItem(
                index: 12,
                child: TransactionItem(
                  title: 'M-PESA Deposit',
                  subtitle: 'From +254712345678',
                  amount: 2500,
                  date: DateTime.now().subtract(const Duration(days: 3)),
                  isIncome: true,
                  icon: Icons.phone_android,
                ),
              ),
              StaggeredListItem(
                index: 13,
                child: TransactionItem(
                  title: 'Loan Payment',
                  subtitle: 'Monthly Installment',
                  amount: 3500,
                  date: DateTime.now().subtract(const Duration(days: 5)),
                  isIncome: false,
                  icon: Icons.payment,
                ),
              ),

              const SizedBox(height: 32),

              // Tips Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentColor.withOpacity(0.1),
                      AppTheme.primaryColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accentColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lightbulb,
                        color: AppTheme.accentColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Savings Tip 💡',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentColor,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set up automatic savings! Even small amounts add up over time.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showFeatureDialog(context, 'Quick Add Money');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Money'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _showFeatureDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(feature),
          ],
        ),
        content: Text(
          'This beautiful $feature feature is ready to be implemented with your existing logic!',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
