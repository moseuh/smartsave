import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import 'SetSavingsGoalScreen.dart';

// ── Goal transaction history ─────────────────────────────────────────────────
class GoalHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> goal;
  const GoalHistoryScreen({super.key, required this.goal});

  @override
  State<GoalHistoryScreen> createState() => _GoalHistoryScreenState();
}

class _GoalHistoryScreenState extends State<GoalHistoryScreen> {
  List<Map<String, dynamic>> _txs = [];
  bool _loading = true;
  final fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final goalId = widget.goal['id']?.toString() ?? '';
    try {
      final r = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/goal-transactions/$goalId'),
      ).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (mounted) setState(() => _txs = List<Map<String, dynamic>>.from(d['data'] ?? []));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _goalColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'emergency':  return const Color(0xFFDC2626);
      case 'education':  return const Color(0xFF6366F1);
      case 'travel':     return const Color(0xFF0EA5E9);
      case 'home':       return const Color(0xFF8B5CF6);
      case 'business':   return const Color(0xFFF59E0B);
      case 'retirement': return const Color(0xFF059669);
      default:           return AppColors.financeGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g      = widget.goal;
    final name   = g['title']?.toString().isNotEmpty == true ? g['title'] : g['goal_name'] ?? 'Goal';
    final type   = g['goal_type']?.toString() ?? '';
    final color  = _goalColor(type);
    final target = double.tryParse(g['target_amount']?.toString() ?? '0') ?? 0;
    final saved  = double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0;
    final pct    = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name,
            style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: color,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Progress card ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.9), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('KES ${fmt.format(saved)}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                Text('of KES ${fmt.format(target)} target',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${(pct * 100).toStringAsFixed(1)}% complete',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('KES ${fmt.format((target - saved).clamp(0, double.infinity))} to go',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Transaction history ────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Savings History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              Text('${_txs.length} entries',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ]),
            const SizedBox(height: 12),

            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: AppColors.financeGreen),
              ))
            else if (_txs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('No contributions yet',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('Round-up savings and deposits will appear here',
                        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
                  ]),
                ),
              )
            else
              ..._txs.map((tx) => _TxRow(tx: tx, color: color, fmt: fmt)),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final Color color;
  final NumberFormat fmt;
  const _TxRow({required this.tx, required this.color, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final amt  = (tx['amount'] as num?)?.toDouble() ?? 0;
    final type = tx['type']?.toString() ?? 'savings';
    final time = tx['created_at']?.toString() ?? '';
    final isRoundup = type.contains('buy_goods') || type.contains('pay_bill');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isRoundup ? Icons.savings_rounded : Icons.add_circle_outline_rounded,
            size: 20, color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isRoundup ? 'Round-up savings' : 'Manual contribution',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827)),
          ),
          if (time.isNotEmpty)
            Text(_formatTime(time), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ])),
        Text('+KES ${fmt.format(amt)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ]),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final df  = DateFormat('d MMM yyyy');
      final diff = now.difference(dt);
      if (diff.inDays < 1) return DateFormat('HH:mm').format(dt);
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return df.format(dt);
    } catch (_) {
      return '';
    }
  }
}

class GoalsDashboard extends StatefulWidget {
  final String userId;
  const GoalsDashboard({super.key, required this.userId});

  @override
  State<GoalsDashboard> createState() => _GoalsDashboardState();
}

class _GoalsDashboardState extends State<GoalsDashboard> {
  List<Map<String, dynamic>> goals = [];
  bool isLoading = true;
  final fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/goalslist/${widget.userId}'),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['data'] is List) {
          setState(() => goals = List<Map<String, dynamic>>.from(data['data']));
        }
      }
    } catch (_) {}
    setState(() => isLoading = false);
  }

  double _progress(Map<String, dynamic> g) {
    final target = double.tryParse(g['target_amount']?.toString() ?? '0') ?? 0;
    final current = double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0;
    return target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
  }

  int _daysLeft(Map<String, dynamic> g) {
    if (g['deadline'] == null) {
      final days = int.tryParse(g['duration_days']?.toString() ?? '0') ?? 0;
      final created = DateTime.tryParse(g['created_at']?.toString() ?? '') ?? DateTime.now();
      final end = created.add(Duration(days: days));
      return end.difference(DateTime.now()).inDays.clamp(0, days);
    }
    final deadline = DateTime.tryParse(g['deadline'].toString()) ?? DateTime.now();
    return deadline.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  Color _goalColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'emergency': return const Color(0xFFDC2626);
      case 'education': return const Color(0xFF6366F1);
      case 'travel': return const Color(0xFF0EA5E9);
      case 'home': return const Color(0xFF8B5CF6);
      case 'business': return const Color(0xFFF59E0B);
      case 'retirement': return const Color(0xFF059669);
      default: return AppColors.financeGreen;
    }
  }

  IconData _goalIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'emergency': return Icons.health_and_safety_outlined;
      case 'education': return Icons.school_outlined;
      case 'travel': return Icons.flight_outlined;
      case 'home': return Icons.home_outlined;
      case 'business': return Icons.business_center_outlined;
      case 'retirement': return Icons.elderly_outlined;
      default: return Icons.savings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTarget = goals.fold(0.0, (s, g) => s + (double.tryParse(g['target_amount']?.toString() ?? '0') ?? 0));
    final totalSaved = goals.fold(0.0, (s, g) => s + (double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0));
    final overallPct = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.backgroundLight,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('My Goals',
                style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 20)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.financeGreen, size: 26),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => GoalCreationScreen(userId: widget.userId),
                  ));
                  _load();
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFF3F4F6)),
            ),
          ),

          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Overall summary card ──
                  if (goals.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F4023), Color(0xFF1B6631)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Total Savings Progress',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${goals.length} Goal${goals.length == 1 ? '' : 's'}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text('KES ${fmt.format(totalSaved)}',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        Text('of KES ${fmt.format(totalTarget)} target',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: overallPct,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('${(overallPct * 100).toStringAsFixed(1)}% overall',
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Goal cards ──
                  if (goals.isEmpty)
                    _EmptyGoals(onAdd: () async {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GoalCreationScreen(userId: widget.userId),
                      ));
                      _load();
                    })
                  else
                    ...goals.map((g) => _GoalCard(
                      goal: g,
                      progress: _progress(g),
                      daysLeft: _daysLeft(g),
                      color: _goalColor(g['goal_type']),
                      icon: _goalIcon(g['goal_type']),
                      fmt: fmt,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GoalHistoryScreen(goal: g),
                      )),
                    )),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final double progress;
  final int daysLeft;
  final Color color;
  final IconData icon;
  final NumberFormat fmt;
  final VoidCallback? onTap;

  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.daysLeft,
    required this.color,
    required this.icon,
    required this.fmt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final target = double.tryParse(goal['target_amount']?.toString() ?? '0') ?? 0;
    final current = double.tryParse(goal['current_amount']?.toString() ?? '0') ?? 0;
    final name = goal['title']?.toString().isNotEmpty == true
        ? goal['title']
        : goal['goal_name']?.toString().isNotEmpty == true
            ? goal['goal_name']
            : 'My Goal';
    final type = goal['goal_type']?.toString() ?? 'General';
    final isComplete = progress >= 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Top color bar
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: isComplete ? const Color(0xFF059669) : color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isComplete ? Icons.check_circle_rounded : icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(type,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ])),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Complete', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$daysLeft', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: daysLeft <= 7 ? Colors.red : const Color(0xFF111827))),
                  const Text('days left', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                ]),
            ]),
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation(isComplete ? const Color(0xFF059669) : color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Saved', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                Text('KES ${fmt.format(current)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const Text('Progress', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                Text('${(progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Target', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                Text('KES ${fmt.format(target)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151))),
              ]),
            ]),
          ]),
        ),
      ]),
    ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyGoals({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.financeGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.savings_outlined, size: 40, color: AppColors.financeGreen),
        ),
        const SizedBox(height: 20),
        const Text('No goals yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        const Text('Set a savings goal and track your progress towards it.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create First Goal'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.financeGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    ),
  );
}
