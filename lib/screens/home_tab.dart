// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../services/onesignal_service.dart';
import '../services/tab_refresh_registry.dart';
import 'transactiohistory.dart';
import 'notifications_screen.dart';
import 'ask_nia_screen.dart';
import 'save_tab.dart';
import 'loans_tab.dart';
import 'buygoodselect.dart';

class HomeTab extends StatefulWidget {
  final String userId;
  const HomeTab({super.key, required this.userId});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  void refresh() => _load();

  Map<String, dynamic>? _user;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _homeStats;
  Map<String, dynamic>? _roundups;
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _recent = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  final fmt = NumberFormat('#,##0');
  final fmtShort = NumberFormat('#,##0');

  // Derived health score state
  int _healthScore = 0;
  String _healthLabel = '';
  Color _healthColor = AppColors.financeGreen;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    TabRefreshRegistry.register(0, refresh);
    _load();
    OneSignalService.registerUser(widget.userId);
  }

  @override
  void dispose() {
    TabRefreshRegistry.unregister(0);
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchUser(),
      _fetchWallet(),
      _fetchHomeStats(),
      _fetchRoundups(),
      _fetchGoals(),
      _fetchRecent(),
    ]);
    _computeHealthScore();
    setState(() => _loading = false);
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _fetchUser() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.userDetailsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _user = d['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchWallet() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.walletById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _wallet = d['data']);
      }
    } catch (_) {
      setState(() => _wallet = {'balance': 0.0});
    }
  }

  Future<void> _fetchHomeStats() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.homeStatsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _homeStats = d['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchRoundups() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.roundupSettingsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        setState(() => _roundups = d['data'] ?? d);
      }
    } catch (_) {}
  }

  Future<void> _fetchGoals() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.goalsListById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final list = List<Map<String, dynamic>>.from(d['data'] ?? d['goals'] ?? []);
        setState(() => _goals = list);
      }
    } catch (_) {}
  }

  Future<void> _fetchRecent() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.transactionsById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _recent = List<Map<String, dynamic>>.from(d['data'] ?? []).take(4).toList());
        }
      }
    } catch (_) {}
  }

  void _computeHealthScore() {
    int score = 0;
    final stats = _homeStats;

    // ── Savings Behaviour (25 pts) ──────────────────────────────────
    final roundupsActive = _roundups != null &&
        (_roundups!['is_enabled'] == true ||
            (_roundups!['rules'] as List? ?? []).any((r) => r['active'] == true));
    if (roundupsActive) score += 5;

    final totalSaved = _totalSaved;
    if (totalSaved > 0) score += 5;
    if (_goals.isNotEmpty) score += 5;
    if (_goals.any((g) => (g['goal_type']?.toString().toLowerCase() ?? '').contains('emergency'))) score += 5;
    if (totalSaved > 1000) score += 5;

    // ── Debt Management (25 pts) ──────────────────────────────────
    final totalDebt = _numStat('total_debt');
    final totalRepaid = _numStat('total_repaid');
    if (totalDebt == 0) {
      score += 25; // no debt = full score
    } else {
      final repayPct = totalRepaid / (totalDebt + totalRepaid);
      score += (repayPct * 25).round().clamp(0, 25);
    }

    // ── Spending Discipline (20 pts) ──────────────────────────────
    final weekSpend = _numStat('week_spend');
    final monthSpend = _numStat('month_spend');
    // Heuristic: if weekly spend < 5000 = good discipline
    if (weekSpend == 0 && monthSpend == 0) {
      score += 10; // no data baseline
    } else if (weekSpend < 2000) {
      score += 20;
    } else if (weekSpend < 5000) {
      score += 14;
    } else if (weekSpend < 15000) {
      score += 8;
    } else {
      score += 3;
    }

    // ── Consistency & Habits (15 pts) ─────────────────────────────
    if (_recent.isNotEmpty) score += 5;
    if (_goals.isNotEmpty) score += 5;
    if (roundupsActive) score += 5;

    // ── Trust & Accountability (15 pts) ───────────────────────────
    final overdueRafiki = stats != null ? (stats['overdue_rafiki'] as num? ?? 0).toInt() : 0;
    if (overdueRafiki == 0) {
      score += 15; // no overdue = full trust score
    } else {
      score += (15 - (overdueRafiki * 5)).clamp(0, 15);
    }

    score = score.clamp(0, 100);

    String label;
    Color color;
    if (score <= 20) {
      label = 'Financially Vulnerable';
      color = const Color(0xFFDC2626);
    } else if (score <= 40) {
      label = 'Needs Attention';
      color = const Color(0xFFF59E0B);
    } else if (score <= 60) {
      label = 'Improving';
      color = const Color(0xFF0EA5E9);
    } else if (score <= 80) {
      label = 'Financially Healthy';
      color = AppColors.financeGreen;
    } else {
      label = 'Financially Strong';
      color = const Color(0xFF059669);
    }

    setState(() {
      _healthScore = score;
      _healthLabel = label;
      _healthColor = color;
    });
  }

  double _numStat(String key) =>
      (_homeStats?[key] as num? ?? 0).toDouble();

  String get _firstName {
    final name = _user?['full_name'] ?? _user?['user_name'] ?? 'there';
    return name.toString().split(' ').first;
  }

  String get _avatarUrl {
    final path = _user?['selfie_path']?.toString().replaceAll('\\', '/');
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl.replaceAll('/api', '')}/$path';
  }

  double get _balance => double.tryParse(_wallet?['balance']?.toString() ?? '0') ?? 0;
  double get _totalSaved => _numStat('total_saved');
  double get _roundupThisMonth => _numStat('roundup_this_month');

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showPaymentOptions(BuildContext context) {
    Navigator.push(context, _slide(BuyGoodsSelect(userId: widget.userId))).then((_) => _load());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: RefreshIndicator(
        color: AppColors.financeGreen,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Wallet + Quick Actions unified card
                  const SizedBox(height: 16),
                  _loading
                      ? const _Skeleton(height: 180)
                      : FadeTransition(
                          opacity: _fade,
                          child: _WalletQuickCard(
                            balance: _balance,
                            onPay: () => _showPaymentOptions(context),
                            onGoals: () => Navigator.push(context, _slide(SaveTab(userId: widget.userId))).then((_) => _load()),
                            onRafiki: () => Navigator.push(context, _slide(LoansTab(userId: widget.userId))).then((_) => _load()),
                            onCreditReport: () => Navigator.push(context, _slide(TransactionHistory(userId: widget.userId))),
                          ),
                        ),

                  // Financial Health Score
                  const SizedBox(height: 14),
                  _loading ? const _Skeleton(height: 90) : FadeTransition(opacity: _fade, child: _HealthScoreCard(score: _healthScore, label: _healthLabel, color: _healthColor)),

                  // Debt Freedom Journey
                  const SizedBox(height: 14),
                  _loading ? const _Skeleton(height: 140) : FadeTransition(opacity: _fade, child: _DebtJourneyCard(stats: _homeStats)),

                  // Nia says
                  const SizedBox(height: 14),
                  _NiaSaysCard(
                    weekSpend: _numStat('week_spend'),
                    roundupThisMonth: _roundupThisMonth,
                    onTap: () => Navigator.push(context, _slide(AskNiaScreen(userId: widget.userId))),
                  ),

                  // Key Metrics Row
                  const SizedBox(height: 14),
                  _loading
                      ? const _Skeleton(height: 100)
                      : FadeTransition(
                          opacity: _fade,
                          child: _MetricsRow(
                            roundupThisMonth: _roundupThisMonth,
                            totalSaved: _totalSaved,
                            stats: _homeStats,
                          ),
                        ),

                  // Goals
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your Goals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      GestureDetector(
                        onTap: () => Navigator.push(context, _slide(SaveTab(userId: widget.userId))).then((_) => _load()),
                        child: const Text('See all', style: TextStyle(fontSize: 13, color: AppColors.financeGreen, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const _Skeleton(height: 90)
                  else if (_goals.isEmpty)
                    GestureDetector(
                      onTap: () => Navigator.push(context, _slide(SaveTab(userId: widget.userId))).then((_) => _load()),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: AppColors.financeGreen, size: 20),
                            SizedBox(width: 10),
                            Text('Create your first savings goal', style: TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    _GoalsRow(
                      goals: _goals.take(2).toList(),
                      fmt: fmtShort,
                      onTap: (g) => Navigator.push(context, _slide(SaveTab(userId: widget.userId))).then((_) => _load()),
                    ),

                  // Recent Activity
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      GestureDetector(
                        onTap: () => Navigator.push(context, _slide(TransactionHistory(userId: widget.userId))),
                        child: const Text('See all', style: TextStyle(fontSize: 13, color: AppColors.financeGreen, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: _Skeleton(height: 68)))
                  else if (_recent.isEmpty)
                    const _EmptyState(icon: Icons.receipt_long_outlined, message: 'No transactions yet.\nStart saving today!')
                  else
                    ..._recent.map((t) => _TxTile(tx: t, fmt: fmt)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  _Avatar(url: _avatarUrl, name: _firstName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                        Row(
                          children: [
                            Text(_firstName, style: const TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Text('👋', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.notifications_none_rounded,
                    onTap: () => Navigator.push(context, _slide(NotificationsScreen(userId: widget.userId))),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: Icons.smart_toy_outlined,
                    onTap: () => Navigator.push(context, _slide(AskNiaScreen(userId: widget.userId))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Financial Health Score Card ───────────────────────────────────────────────

class _HealthScoreCard extends StatelessWidget {
  final int score;
  final String label;
  final Color color;
  const _HealthScoreCard({required this.score, required this.label, required this.color});

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('How your score is calculated', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 14),
            _ScorePillar('Savings Behaviour', 25, Icons.savings_rounded, 'Round-ups, monthly savings, goals, emergency fund'),
            _ScorePillar('Debt Management', 25, Icons.account_balance_rounded, 'Debt reduction, repayment consistency, debt plan'),
            _ScorePillar('Spending Discipline', 20, Icons.receipt_long_rounded, 'Budget created, adherence, monthly improvement'),
            _ScorePillar('Consistency & Habits', 15, Icons.calendar_today_rounded, 'Weekly app use, financial reviews, Nia engagement'),
            _ScorePillar('Trust & Accountability', 15, Icons.people_alt_rounded, 'Rafiki2Rafiki repayments, no overdue obligations'),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          // Left: text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Financial Health Score',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () => _showInfo(context),
                      child: const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFBBC1CA)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$score',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          height: 1.0,
                          letterSpacing: -1,
                        ),
                      ),
                      const TextSpan(
                        text: '/100',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFF16A34A)),
                    const SizedBox(width: 3),
                    const Text('5 points this month',
                        style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          // Right: speedometer arc with heart-ECG icon
          SizedBox(
            width: 90,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(90, 80),
                  painter: _SpeedometerPainter(score / 100, const Color(0xFF1B6631)),
                ),
                // Heart icon centred inside the arc
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.favorite_border_rounded, color: const Color(0xFF1B6631), size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePillar extends StatelessWidget {
  final String title;
  final int max;
  final IconData icon;
  final String desc;
  const _ScorePillar(this.title, this.max, this.icon, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.financeGreen, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                    Text('$max pts', style: const TextStyle(fontSize: 12, color: AppColors.financeGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Speedometer-style arc: starts bottom-left, sweeps ~210°, open at bottom-right gap.
// Matches the screenshot: thick stroke, dark green fill, light grey track.
class _SpeedometerPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color color;
  const _SpeedometerPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.65; // push centre lower so arc sits in upper portion
    final radius = size.width * 0.46;
    const strokeWidth = 9.0;

    // Arc spans ~210° starting from bottom-left (about 215° clock = ~3.75 rad from positive X)
    // In Flutter: 0 = right, pi/2 = bottom, pi = left, 3pi/2 = top
    const startAngle = math.pi * 0.78;  // ~140° from right = bottom-left
    const sweepFull  = math.pi * 1.44;  // ~260° sweep — leaves gap at bottom-right

    final trackPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Draw full grey track first
    canvas.drawArc(rect, startAngle, sweepFull, false, trackPaint);
    // Draw green progress on top
    if (progress > 0) {
      canvas.drawArc(rect, startAngle, sweepFull * progress, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Wallet + Quick Actions unified card ───────────────────────────────────────

class _WalletQuickCard extends StatefulWidget {
  final double balance;
  final VoidCallback onPay;
  final VoidCallback onGoals;
  final VoidCallback onRafiki;
  final VoidCallback onCreditReport;
  const _WalletQuickCard({required this.balance, required this.onPay, required this.onGoals, required this.onRafiki, required this.onCreditReport});

  @override
  State<_WalletQuickCard> createState() => _WalletQuickCardState();
}

class _WalletQuickCardState extends State<_WalletQuickCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance row
          Row(
            children: [
              const Text('Wallet Balance', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _hidden = !_hidden),
                child: Icon(_hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.financeGreen, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _hidden ? 'KES ••••••' : 'KES ${NumberFormat('#,##0.00').format(widget.balance)}',
            style: const TextStyle(color: Color(0xFF111827), fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          // Divider
          Container(height: 1, color: AppColors.financeGreen.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
          // Quick Actions label
          const Text('Quick Actions', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          // 4 action buttons
          Row(
            children: [
              _WQAction(icon: Icons.send_rounded,         label: 'Pay',           onTap: widget.onPay),
              const SizedBox(width: 10),
              _WQAction(icon: Icons.savings_rounded,      label: 'Goals',         onTap: widget.onGoals),
              const SizedBox(width: 10),
              _WQAction(icon: Icons.people_alt_rounded,   label: 'Rafiki2Rafiki', onTap: widget.onRafiki),
              const SizedBox(width: 10),
              _WQAction(icon: Icons.bar_chart_rounded,    label: 'Credit Report', onTap: widget.onCreditReport),
            ],
          ),
        ],
      ),
    );
  }
}

class _WQAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _WQAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.financeGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 20)),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(color: Color(0xFF374151), fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

// ── Debt Freedom Journey Card ─────────────────────────────────────────────────

class _DebtJourneyCard extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _DebtJourneyCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalDebt = (stats?['total_debt'] as num? ?? 0).toDouble();
    final totalRepaid = (stats?['total_repaid'] as num? ?? 0).toDouble();
    final debtStatus = stats?['debt_status']?.toString() ?? 'No active loans';
    final paid = totalRepaid;
    final total = totalDebt + totalRepaid;
    final remaining = totalDebt;
    final pct = total > 0 ? (paid / total * 100).clamp(0.0, 100.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B6631),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ──
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                const Text('Debt Freedom Journey',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(debtStatus,
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                ),
                const Spacer(),
                const Text('···', style: TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Body ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular progress
              SizedBox(
                width: 78, height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 78, height: 78,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${pct.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.1)),
                        const Text('Complete',
                            style: TextStyle(color: Colors.white70, fontSize: 8.5, letterSpacing: 0.2)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Amounts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KES ${_fmt(paid)}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 1),
                    const Text('Paid so far',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 8),
                    // Dashed divider
                    Row(
                      children: List.generate(
                        18,
                        (i) => Expanded(
                          child: Container(
                            height: 1,
                            color: i.isEven ? Colors.white.withValues(alpha: 0.35) : Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('KES ${_fmt(remaining)}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 1),
                    const Text('Remaining',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              // Mountain + flag illustration
              SizedBox(
                width: 80, height: 78,
                child: CustomPaint(painter: _MountainPainter()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0').format(v);
}

class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back mountain (lighter green)
    final back = Paint()..color = const Color(0xFF2D7A45);
    final backPath = Path()
      ..moveTo(w * 0.55, h * 0.15)
      ..lineTo(w * 0.95, h)
      ..lineTo(w * 0.15, h)
      ..close();
    canvas.drawPath(backPath, back);

    // Front mountain (slightly lighter than card bg)
    final front = Paint()..color = const Color(0xFF256035);
    final frontPath = Path()
      ..moveTo(w * 0.25, h * 0.3)
      ..lineTo(w * 0.72, h)
      ..lineTo(w * -0.05, h)
      ..close();
    canvas.drawPath(frontPath, front);

    // Snow cap on front peak
    final snow = Paint()..color = Colors.white.withValues(alpha: 0.15);
    final snowPath = Path()
      ..moveTo(w * 0.25, h * 0.3)
      ..lineTo(w * 0.35, h * 0.47)
      ..lineTo(w * 0.15, h * 0.47)
      ..close();
    canvas.drawPath(snowPath, snow);

    // Flag pole on back peak
    final pole = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.55, h * 0.15), Offset(w * 0.55, h * -0.05), pole);

    // Flag (green rectangle)
    final flag = Paint()..color = const Color(0xFF4CAF50);
    canvas.drawRect(Rect.fromLTWH(w * 0.55, h * -0.05, w * 0.22, h * 0.13), flag);
  }

  @override
  bool shouldRepaint(_MountainPainter _) => false;
}

// ── Nia Says Card ─────────────────────────────────────────────────────────────

class _NiaSaysCard extends StatelessWidget {
  final double weekSpend;
  final double roundupThisMonth;
  final VoidCallback onTap;
  const _NiaSaysCard({required this.weekSpend, required this.roundupThisMonth, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    final spend = weekSpend.round();
    final String message;
    if (spend == 0) {
      message = "No spending recorded this week. Great start! 🎉";
    } else if (spend < 2000) {
      message = "You've spent KES ${fmt.format(spend)} this week. Low spend — great discipline! 💪";
    } else if (spend < 5000) {
      message = "You've spent KES ${fmt.format(spend)} this week. You're on track — keep it steady.";
    } else if (spend < 15000) {
      message = "You've spent KES ${fmt.format(spend)} this week. Watch your spending to stay on budget.";
    } else {
      message = "You've spent KES ${fmt.format(spend)} this week. High spend — consider slowing down.";
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.smart_toy_outlined, color: AppColors.financeGreen, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Text('Nia says ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
                  Text('✨', style: TextStyle(fontSize: 13)),
                ]),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: Color(0xFF374151), fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.financeGreen, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Ask Nia', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 18),
        ],
      ),
    );
  }
}

// ── Key Metrics Row ───────────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  final double roundupThisMonth;
  final double totalSaved;
  final Map<String, dynamic>? stats;
  const _MetricsRow({required this.roundupThisMonth, required this.totalSaved, required this.stats});

  String _pct(String key) {
    final v = (stats?[key] as num? ?? 0).toInt();
    if (v == 0) return 'Same as last month';
    return '${v > 0 ? '+' : ''}$v% vs last month';
  }

  @override
  Widget build(BuildContext context) {
    final totalRepaid = (stats?['total_repaid'] as num? ?? 0).toDouble();
    return Row(
      children: [
        Expanded(child: _MetricCard(
          icon: Icons.loop_rounded,
          label: 'Round-ups\nThis Month',
          value: 'KES ${NumberFormat('#,##0').format(roundupThisMonth)}',
          change: _pct('roundup_change'),
          positive: (stats?['roundup_change'] as num? ?? 0) >= 0,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
          icon: Icons.savings_rounded,
          label: 'Total\nSaved',
          value: 'KES ${NumberFormat('#,##0').format(totalSaved)}',
          change: _pct('savings_change'),
          positive: (stats?['savings_change'] as num? ?? 0) >= 0,
        )),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
          icon: Icons.trending_up_rounded,
          label: 'Debt\nRepaid',
          value: 'KES ${NumberFormat('#,##0').format(totalRepaid)}',
          change: _pct('week_spend_change'),
          positive: (stats?['week_spend_change'] as num? ?? 0) <= 0,
        )),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String change;
  final bool positive;
  const _MetricCard({required this.icon, required this.label, required this.value, required this.change, this.positive = true});

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final arrow = positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.financeGreen, size: 16),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, height: 1.3)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(arrow, size: 9, color: color),
              Flexible(child: Text(change, style: TextStyle(color: color, fontSize: 8), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Goals Row ─────────────────────────────────────────────────────────────────

class _GoalsRow extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final NumberFormat fmt;
  final void Function(Map<String, dynamic>)? onTap;
  const _GoalsRow({required this.goals, required this.fmt, this.onTap});

  Color _goalColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'emergency':  return const Color(0xFFDC2626);
      case 'education':  return const Color(0xFF6366F1);
      case 'travel':     return const Color(0xFF0EA5E9);
      case 'home':       return const Color(0xFF8B5CF6);
      case 'business':   return const Color(0xFFF59E0B);
      default:           return AppColors.financeGreen;
    }
  }

  IconData _goalIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'emergency':  return Icons.health_and_safety_rounded;
      case 'education':  return Icons.school_rounded;
      case 'travel':     return Icons.flight_rounded;
      case 'home':       return Icons.home_rounded;
      case 'business':   return Icons.business_rounded;
      default:           return Icons.savings_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: goals.asMap().entries.map((e) {
        final idx = e.key;
        final g = e.value;
        final name = g['goal_name']?.toString().isNotEmpty == true ? g['goal_name'] : g['title'] ?? 'Goal';
        final type = g['goal_type']?.toString();
        final current = double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0;
        final target = double.tryParse(g['target_amount']?.toString() ?? '0') ?? 1;
        final pct = (current / target * 100).clamp(0.0, 100.0);
        final color = _goalColor(type);

        return Expanded(
          child: GestureDetector(
            onTap: onTap != null ? () => onTap!(g) : null,
            child: Container(
            margin: EdgeInsets.only(right: idx == 0 && goals.length > 1 ? 8 : 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_goalIcon(type), color: color, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('KES ${fmt.format(current)} / ${fmt.format(target)}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final String name;
  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial())
            : _initial(),
      ),
    );
  }

  Widget _initial() => Container(
        color: AppColors.financeGreenV2,
        child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'N',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.financeGreen, size: 22),
      ),
    );
  }
}


class _TxTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  final NumberFormat fmt;
  const _TxTile({required this.tx, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final type = (tx['type']?.toString() ?? '').toLowerCase();
    final isIn = type.contains('deposit');
    final amount = double.tryParse((tx['total_amount'] ?? tx['amount'] ?? 0).toString()) ?? 0;
    final title = tx['business_name']?.toString().isNotEmpty == true
        ? tx['business_name'].toString()
        : type.contains('deposit') ? 'Deposit'
        : type.contains('pay_bill') ? 'Pay Bill'
        : type.contains('buy_goods') ? 'Buy Goods'
        : 'Transaction';
    final date = tx['created_at'] ?? '';
    String dateStr = '';
    try {
      final dt = DateTime.parse(date).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        dateStr = 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        dateStr = DateFormat('d MMM, HH:mm').format(dt);
      }
    } catch (_) {}

    final iconData = isIn ? Icons.arrow_downward_rounded
        : type.contains('pay_bill') ? Icons.account_balance_rounded
        : type.contains('buy_goods') ? Icons.shopping_bag_rounded
        : Icons.arrow_upward_rounded;
    final color = isIn ? const Color(0xFF059669) : const Color(0xFFDC2626);

    // Status from tx
    final status = (tx['transaction_status'] ?? tx['status'] ?? 'completed').toString().toLowerCase();
    final isPending = status == 'pending';

    return GestureDetector(
      onTap: () => showTransactionDetail(context, tx, fmt),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(iconData, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${isIn ? '+' : '-'}KES ${fmt.format(amount.abs())}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPending ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : const Color(0xFF059669).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPending ? 'Pending' : 'Success',
                    style: TextStyle(fontSize: 9, color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF059669), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

// ── showTransactionDetail (keep existing) ─────────────────────────────────────

void showTransactionDetail(BuildContext context, Map<String, dynamic> tx, NumberFormat fmt) {
  final type = (tx['type']?.toString() ?? '').toLowerCase();
  final isIn = type.contains('deposit');
  final amount = double.tryParse((tx['total_amount'] ?? tx['amount'] ?? 0).toString()) ?? 0;
  final title = tx['business_name']?.toString().isNotEmpty == true
      ? tx['business_name'].toString()
      : type.contains('deposit') ? 'Deposit'
      : type.contains('pay_bill') ? 'Pay Bill'
      : type.contains('buy_goods') ? 'Buy Goods'
      : 'Transaction';
  final color = isIn ? const Color(0xFF059669) : const Color(0xFFDC2626);
  final status = (tx['transaction_status'] ?? tx['status'] ?? 'completed').toString();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text('${isIn ? '+' : '-'}KES ${fmt.format(amount.abs())}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 20),
          _DetailRow(label: 'Type', value: type.replaceAll('_', ' ').toUpperCase()),
          _DetailRow(label: 'Status', value: status),
          if (tx['created_at'] != null)
            _DetailRow(label: 'Date', value: () {
              try { return DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(tx['created_at']).toLocal()); }
              catch (_) { return tx['created_at'].toString(); }
            }()),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Deposit Sheet ─────────────────────────────────────────────────────────────

class _DepositSheet extends StatefulWidget {
  final String userId;
  final TextEditingController phoneCtrl;
  final TextEditingController amtCtrl;
  final VoidCallback onSuccess;
  const _DepositSheet({required this.userId, required this.phoneCtrl, required this.amtCtrl, required this.onSuccess});

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  bool _loading = false;
  String? _error;
  String? _checkoutRef;
  bool _polling = false;
  bool _paid = false;
  int _pollCount = 0;
  static const int _maxPolls = 22;

  @override
  void dispose() { _polling = false; super.dispose(); }

  Future<void> _sendSTK() async {
    final amt = double.tryParse(widget.amtCtrl.text.replaceAll(',', ''));
    if (amt == null || amt < 1) { setState(() => _error = 'Enter a valid amount (min KES 1)'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.getUrl('deposit')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId, 'amount': amt, 'phone': widget.phoneCtrl.text.trim()}),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == 'success') {
        setState(() { _loading = false; _checkoutRef = data['checkout_id']?.toString() ?? ''; });
        _startPolling();
      } else {
        setState(() { _loading = false; _error = data['message'] ?? 'Failed to send STK Push'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Network error — check your connection'; });
    }
  }

  void _startPolling() {
    _polling = true; _pollCount = 0;
    Future.doWhile(() async {
      if (!_polling || !mounted) return false;
      await Future.delayed(const Duration(seconds: 4));
      if (!_polling || !mounted) return false;
      _pollCount++;
      if (_pollCount >= _maxPolls) {
        if (mounted) setState(() { _polling = false; _checkoutRef = null; _error = 'Timed out. If debited, balance will update shortly.'; });
        return false;
      }
      try {
        final ref = _checkoutRef ?? '';
        if (ref.isEmpty) return false;
        final res = await http.get(Uri.parse(ApiConfig.transactionStatus(ref))).timeout(const Duration(seconds: 10));
        final data = jsonDecode(res.body);
        final status = (data['payment_status'] ?? data['status'] ?? '').toString().toUpperCase();
        if (status == 'SUCCESS' || status == 'COMPLETE' || status == 'COMPLETED') {
          if (mounted) { setState(() { _paid = true; _polling = false; }); widget.onSuccess(); }
          return false;
        } else if (status == 'FAILED' || status == 'CANCELLED' || status == 'EXPIRED') {
          if (mounted) setState(() { _polling = false; _checkoutRef = null; _error = 'Payment ${status.toLowerCase()} — please try again'; });
          return false;
        }
      } catch (_) {}
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.viewInsets.bottom + mq.padding.bottom + 24;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          if (_paid) ...[
            Center(child: Column(children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
              const SizedBox(height: 16),
              const Text('Deposit Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              Text('KES ${widget.amtCtrl.text} added to your wallet', style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              )),
            ])),
          ] else if (_checkoutRef != null) ...[
            Center(child: Column(children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.financeGreenV3.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const CircularProgressIndicator(color: AppColors.financeGreen, strokeWidth: 3)),
              const SizedBox(height: 16),
              const Text('Check your phone', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              const Text('Enter your M-Pesa PIN to complete the deposit.\nWaiting for confirmation...', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(onPressed: () => setState(() { _checkoutRef = null; _polling = false; }), child: const Text('Cancel / Try again', style: TextStyle(color: Colors.red))),
            ])),
          ] else ...[
            const Text('Add Money via M-Pesa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 20),
            _field(widget.amtCtrl, 'Amount (KES)', isNumber: true, prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
            const SizedBox(height: 12),
            _field(widget.phoneCtrl, 'M-Pesa Phone Number', isNumber: true, prefix: const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.financeGreen)),
            const SizedBox(height: 6),
            const Text('Your registered M-Pesa number', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)))]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _loading ? null : _sendSTK,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreen, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send STK Push', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {bool isNumber = false, Widget? prefix}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Wallet Card ───────────────────────────────────────────────────────────────

class _WalletCard extends StatefulWidget {
  final double balance;
  final VoidCallback onAddMoney;
  final VoidCallback onPayments;
  const _WalletCard({required this.balance, required this.onAddMoney, required this.onPayments});

  @override
  State<_WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<_WalletCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B6631), Color(0xFF256035)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFF1B6631).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _hidden = !_hidden),
                child: Icon(_hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white54, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _hidden ? 'KES ••••••' : 'KES ${NumberFormat('#,##0.00').format(widget.balance)}',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onAddMoney,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 5),
                        Text('Add Money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onPayments,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Color(0xFF1B6631), size: 18),
                        SizedBox(width: 5),
                        Text('Pay / Send', style: TextStyle(color: Color(0xFF1B6631), fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Withdraw Sheet ────────────────────────────────────────────────────────────

class _WithdrawSheet extends StatefulWidget {
  final String userId;
  final TextEditingController phoneCtrl;
  final TextEditingController amtCtrl;
  final VoidCallback onSuccess;
  const _WithdrawSheet({required this.userId, required this.phoneCtrl, required this.amtCtrl, required this.onSuccess});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  bool _loading = false;
  String? _error;
  bool _done = false;

  Future<void> _withdraw() async {
    final amt = double.tryParse(widget.amtCtrl.text.replaceAll(',', ''));
    if (amt == null || amt < 10) { setState(() => _error = 'Enter a valid amount (min KES 10)'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      String phone = widget.phoneCtrl.text.trim();
      if (phone.startsWith('0')) phone = '254${phone.substring(1)}';
      if (phone.startsWith('+')) phone = phone.substring(1);
      final res = await http.post(
        Uri.parse(ApiConfig.getUrl('withdraw')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId, 'amount': amt.toInt(), 'phone': phone}),
      ).timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == 'success') {
        setState(() { _loading = false; _done = true; });
        widget.onSuccess();
      } else {
        setState(() { _loading = false; _error = data['message'] ?? 'Withdrawal failed'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Network error — check your connection'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPadding = mq.viewInsets.bottom + mq.padding.bottom + 24;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          if (_done) ...[
            Center(child: Column(children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
              const SizedBox(height: 16),
              const Text('Withdrawal Sent!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              const Text('M-Pesa will confirm shortly.', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.financeGreen, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ])),
          ] else ...[
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFDC2626).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFDC2626), size: 22)),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Withdraw to M-Pesa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                Text('Funds sent directly to your phone', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ]),
            const SizedBox(height: 20),
            _wField(widget.amtCtrl, 'Amount (KES)', isNumber: true, prefix: const Text('KES ', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
            const SizedBox(height: 12),
            _wField(widget.phoneCtrl, 'M-Pesa Phone Number', isNumber: true, prefix: const Icon(Icons.phone_android_rounded, size: 18, color: Color(0xFFDC2626))),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)))]),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _loading ? null : _withdraw,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _wField(TextEditingController ctrl, String hint, {bool isNumber = false, Widget? prefix}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: prefix != null ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
