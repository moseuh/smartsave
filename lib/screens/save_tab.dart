import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../services/tab_refresh_registry.dart';
import 'goals_dashboard.dart';
import 'roundup.dart';
import 'SetSavingsGoalScreen.dart' show GoalCreationScreen;
import 'LeaderboardPage.dart';

class SaveTab extends StatefulWidget {
  final String userId;
  const SaveTab({super.key, required this.userId});

  @override
  State<SaveTab> createState() => _SaveTabState();
}

class _SaveTabState extends State<SaveTab> {
  Map<String, dynamic>? _savings;
  List<Map<String, dynamic>> _goals = [];
  bool _loading = true;
  final fmt = NumberFormat('#,##0.00');

  void refresh() => _load();

  @override
  void initState() {
    super.initState();
    TabRefreshRegistry.register(1, refresh);
    _load();
  }

  @override
  void dispose() {
    TabRefreshRegistry.unregister(1);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_fetchSavings(), _fetchGoals()]);
    setState(() => _loading = false);
  }

  Future<void> _fetchSavings() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.userSavingsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _savings = d['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchGoals() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.goalsListById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _goals = List<Map<String, dynamic>>.from(d['data'] ?? []));
        }
      }
    } catch (_) {}
  }

  double get _totalSaved => double.tryParse(_savings?['total_saved']?.toString() ?? '0') ?? 0;
  double get _monthSaved => double.tryParse(_savings?['month_saved']?.toString() ?? '0') ?? 0;
  double get _roundupTotal => double.tryParse(_savings?['roundup_total']?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: RefreshIndicator(
        color: AppColors.financeGreenV3,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── White hero header ─────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.backgroundLight,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              expandedHeight: 170,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  color: AppTheme.backgroundLight,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Savings',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Build your wealth, step by step',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                _HeaderStat('Total Saved', _loading ? '…' : 'KES ${fmt.format(_totalSaved)}'),
                                _HeaderStat('This Month', _loading ? '…' : 'KES ${fmt.format(_monthSaved)}'),
                                _HeaderStat('Round-ups', _loading ? '…' : 'KES ${fmt.format(_roundupTotal)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppColors.coreWhiteW2),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Quick actions row
                  Row(
                    children: [
                      Expanded(child: _ActionCard(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'New Goal',
                        color: AppColors.financeGreen,
                        onTap: () => Navigator.push(context, _slide(GoalCreationScreen(userId: widget.userId))),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionCard(
                        icon: Icons.loop_rounded,
                        label: 'Round-ups',
                        color: AppColors.financeGreenV2,
                        onTap: () => Navigator.push(context, _slide(const RoundUpSettings())),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionCard(
                        icon: Icons.emoji_events_rounded,
                        label: 'Leaderboard',
                        color: const Color(0xFFF5A623),
                        onTap: () => Navigator.push(context, _slide(LeaderboardPage(userId: widget.userId))),
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Goals section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('My Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      GestureDetector(
                        onTap: () => Navigator.push(context, _slide(GoalsDashboard(userId: widget.userId))),
                        child: const Text('See all', style: TextStyle(fontSize: 13, color: AppColors.financeGreenV3, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_loading)
                    ...List.generate(2, (_) => const Padding(padding: EdgeInsets.only(bottom: 12), child: _Skeleton(height: 100)))
                  else if (_goals.isEmpty)
                    _EmptyGoals(onTap: () => Navigator.push(context, _slide(GoalCreationScreen(userId: widget.userId))))
                  else
                    ..._goals.map((g) => _GoalCard(goal: g, fmt: fmt)),

                  const SizedBox(height: 24),

                  // Savings tips
                  const Text('Smart Saving Tips', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  const _TipCard(
                    icon: Icons.loop_rounded,
                    title: 'Enable Round-ups',
                    body: 'Every M-Pesa transaction rounds up to the nearest 10 — small amounts that add up fast.',
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(height: 10),
                  const _TipCard(
                    icon: Icons.calendar_today_rounded,
                    title: '50/30/20 Rule',
                    body: 'Allocate 50% needs, 30% wants, 20% savings every month.',
                    color: AppColors.financeGreenV3,
                  ),
                  const SizedBox(height: 10),
                  const _TipCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Join Challenges',
                    body: 'Compete with others on the leaderboard and stay motivated to save.',
                    color: Color(0xFFF5A623),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Route _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      );
}

// ── _HeaderStat — dark text for light background ──────────────────────────────
class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

// ── _ActionCard — solid color, tall, icon in frosted circle ──────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _GoalCard ─────────────────────────────────────────────────────────────────
class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final NumberFormat fmt;
  const _GoalCard({required this.goal, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final saved = double.tryParse(goal['saved_amount']?.toString() ?? '0') ?? 0;
    final target = double.tryParse(goal['target_amount']?.toString() ?? '1') ?? 1;
    final pct = (saved / target).clamp(0.0, 1.0);
    final name = goal['goal_name'] ?? goal['name'] ?? 'Goal';
    final deadline = goal['deadline'] ?? goal['target_date'] ?? '';
    String dateStr = '';
    try { dateStr = DateFormat('d MMM yyyy').format(DateTime.parse(deadline)); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.financeGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag_rounded, color: AppColors.financeGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                    if (dateStr.isNotEmpty)
                      Text('Due $dateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.financeGreen)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation(AppColors.financeGreenV3),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KES ${fmt.format(saved)} saved', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              Text('of KES ${fmt.format(target)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _EmptyGoals ───────────────────────────────────────────────────────────────
class _EmptyGoals extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyGoals({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.coreWhiteW2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppColors.financeGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.financeGreen, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('Create your first goal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            const Text('People with goals save 3× more', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

// ── _TipCard ──────────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;
  const _TipCard({required this.icon, required this.title, required this.body, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _Skeleton ─────────────────────────────────────────────────────────────────
class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(16)),
      );
}
