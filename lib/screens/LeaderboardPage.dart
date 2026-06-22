import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class LeaderboardPage extends StatelessWidget {
  final String userId;
  const LeaderboardPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Leaderboard',
                      style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ComingSoonIcon(),
                      SizedBox(height: 24),
                      Text('Coming Soon',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      SizedBox(height: 10),
                      Text(
                        'The leaderboard is under construction.\nCompete with other savers — coming very soon.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6),
                      ),
                      SizedBox(height: 32),
                      _NotifyBadge(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonIcon extends StatelessWidget {
  const _ComingSoonIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          color: AppColors.financeGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.leaderboard_outlined, size: 42, color: AppColors.financeGreen),
      );
}

class _NotifyBadge extends StatelessWidget {
  const _NotifyBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.financeGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.25)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_outlined, color: AppColors.financeGreen, size: 18),
          SizedBox(width: 8),
          Text('We\'ll notify you when it\'s ready',
              style: TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
}
