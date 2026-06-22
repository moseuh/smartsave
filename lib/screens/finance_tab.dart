import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../services/sms_finance_service.dart';
import '../services/tab_refresh_registry.dart';
import 'package:intl/intl.dart';
import 'expenditure_screen.dart';
import 'finance_manager_screen.dart';
import 'ask_nia_screen.dart';

class FinanceTab extends StatefulWidget {
  final String userId;
  const FinanceTab({super.key, required this.userId});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

enum _Period { today, thisWeek, thisMonth, lastMonth, last3M, last6M, custom }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.today: return 'Today';
      case _Period.thisWeek: return 'This Week';
      case _Period.thisMonth: return 'This Month';
      case _Period.lastMonth: return 'Last Month';
      case _Period.last3M: return 'Last 3 Months';
      case _Period.last6M: return 'Last 6 Months';
      case _Period.custom: return 'Custom';
    }
  }
}

class _FinanceTabState extends State<FinanceTab> {
  List<FinanceTransaction> _txs = [];
  BalanceStatement? _statement;
  bool _loading = true;
  bool _smsGranted = false;
  final fmt = NumberFormat('#,##0.00');

  _Period _period = _Period.thisMonth;
  DateTimeRange? _customRange;

  void refresh() => _init();

  @override
  void initState() {
    super.initState();
    TabRefreshRegistry.register(2, refresh);
    _init();
  }

  @override
  void dispose() {
    TabRefreshRegistry.unregister(2);
    super.dispose();
  }

  Future<void> _init() async {
    _smsGranted = await SmsFinanceService.checkPermission();
    if (_smsGranted) {
      _txs = await SmsFinanceService.loadAll();
      _statement = SmsFinanceService.buildStatement(_txs);
    }
    setState(() => _loading = false);
  }

  Future<void> _requestSms() async {
    final granted = await SmsFinanceService.requestPermission();
    setState(() => _smsGranted = granted);
    if (granted) {
      setState(() => _loading = true);
      _txs = await SmsFinanceService.loadAll(forceRefresh: true);
      _statement = SmsFinanceService.buildStatement(_txs);
      setState(() => _loading = false);
    }
  }

  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      case _Period.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: DateTime(weekStart.year, weekStart.month, weekStart.day), end: now);
      case _Period.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case _Period.lastMonth:
        final lm = DateTime(now.year, now.month - 1);
        return DateTimeRange(
          start: DateTime(lm.year, lm.month, 1),
          end: DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1)),
        );
      case _Period.last3M:
        return DateTimeRange(start: DateTime(now.year, now.month - 2, 1), end: now);
      case _Period.last6M:
        return DateTimeRange(start: DateTime(now.year, now.month - 5, 1), end: now);
      case _Period.custom:
        return _customRange ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  String get _periodSubtitle {
    final r = _range;
    final df = DateFormat('d MMM');
    final now = DateTime.now();
    if (_period == _Period.today) return 'Today, ${DateFormat('d MMM').format(now)}';
    if (_period == _Period.thisMonth) return 'This Month • 1–${now.day} ${DateFormat('MMM').format(now)}';
    return '${df.format(r.start)} – ${df.format(r.end)}';
  }

  List<FinanceTransaction> get _filtered {
    final r = _range;
    return _txs.where((t) => !t.date.isBefore(r.start) && !t.date.isAfter(r.end)).toList();
  }

  double get _income => SmsFinanceService.totalIncome(_filtered);
  double get _expenses => SmsFinanceService.totalExpenses(_filtered);
  double get _balance => _statement?.currentBalance ?? 0;
  double get _savingsRate => _income > 0 ? ((_income - _expenses) / _income * 100).clamp(0.0, 100.0) : 0.0;

  Future<void> _pickPeriod() async {
    final chosen = await showModalBottomSheet<_Period>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PeriodSheet(current: _period),
    );
    if (chosen == null || !mounted) return;
    if (chosen == _Period.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _customRange,
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.financeGreen),
          ),
          child: child!,
        ),
      );
      if (!mounted || range == null) return;
      setState(() { _period = _Period.custom; _customRange = range; });
    } else {
      setState(() => _period = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Header — whitish like home screen
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.backgroundLight,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            expandedHeight: _smsGranted && !_loading ? 200 : 110,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Finance',
                                style: TextStyle(color: Color(0xFF111827), fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            if (_smsGranted && !_loading)
                              GestureDetector(
                                onTap: _pickPeriod,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.financeGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text(_period.label,
                                        style: const TextStyle(color: AppColors.financeGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.financeGreen, size: 16),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _smsGranted ? _periodSubtitle : 'Connect your M-Pesa SMS',
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                        ),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(
                              color: AppColors.financeGreen,
                              backgroundColor: Color(0xFFE5E7EB),
                            ),
                          )
                        else if (_smsGranted) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              children: [
                                Row(children: [
                                  _HStat('Income', 'KES ${fmt.format(_income)}'),
                                  _HStat('Expenses', 'KES ${fmt.format(_expenses)}'),
                                  _HStat('M-Pesa Bal', 'KES ${fmt.format(_balance)}'),
                                ]),
                                const SizedBox(height: 10),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  const Text('Savings Rate',
                                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                                  Text('${_savingsRate.toStringAsFixed(1)}%',
                                      style: const TextStyle(color: AppColors.financeGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                                ]),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _savingsRate / 100,
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    valueColor: const AlwaysStoppedAnimation(AppColors.financeGreen),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                // SMS permission banner
                if (!_smsGranted) ...[
                  _SmsBanner(onTap: _requestSms),
                  const SizedBox(height: 20),
                ],

                // Module cards
                _ModuleCard(
                  icon: Icons.smart_toy_outlined,
                  title: 'Ask Nia',
                  subtitle: 'AI that reads your SMS & answers financial questions',
                  gradient: const LinearGradient(colors: [Color(0xFF0F4023), Color(0xFF1B6631)]),
                  onTap: () => _go(AskNiaScreen(userId: widget.userId)),
                  badge: _txs.isNotEmpty ? '${_txs.length} txns loaded' : null,
                ),
                const SizedBox(height: 12),
                _ModuleCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Finance Manager',
                  subtitle: 'Track income & expenses • Budgets • Manual entries',
                  gradient: const LinearGradient(colors: [Color(0xFF1B6631), Color(0xFF2D8A47)]),
                  onTap: () => _go(FinanceManagerScreen(userId: widget.userId)),
                ),
                const SizedBox(height: 12),
                _ModuleCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'SMS Expenditure',
                  subtitle: 'Auto-parsed M-Pesa & bank transactions by month',
                  gradient: const LinearGradient(colors: [Color(0xFF2D8A47), Color(0xFF51AA44)]),
                  onTap: () => _go(ExpenditureScreen(userId: widget.userId)),
                ),
                const SizedBox(height: 24),

                // Quick stats if data loaded
                if (_smsGranted && _filtered.isNotEmpty) ...[
                  Text('${_period.label} at a Glance',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  _QuickStatsGrid(txs: _filtered, fmt: fmt),
                  const SizedBox(height: 24),

                  // Top categories
                  const Text('Top Spending Categories',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  _TopCategories(txs: _filtered, expenses: _expenses, fmt: fmt),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _go(Widget page) => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
}

class _HStat extends StatelessWidget {
  final String label, value;
  const _HStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final String? badge;
  const _ModuleCard({required this.icon, required this.title, required this.subtitle, required this.gradient, required this.onTap, this.badge});

  // Extract the first color of the gradient as the accent
  Color get _accent => gradient.colors.first;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: _accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 15)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(badge!, style: TextStyle(color: _accent, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB), size: 20),
          ],
        ),
      ),
    );
  }
}

class _SmsBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SmsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.sms_outlined, color: Colors.amber, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Enable SMS Auto-Import', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
              SizedBox(height: 2),
              Text('Let Nia read your M-Pesa & bank SMS for automatic insights', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.amber),
        ]),
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  final List<FinanceTransaction> txs;
  final NumberFormat fmt;
  const _QuickStatsGrid({required this.txs, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final income = SmsFinanceService.totalIncome(txs);
    final expenses = SmsFinanceService.totalExpenses(txs);
    final cats = SmsFinanceService.expensesByCategory(txs);
    return Row(children: [
      Expanded(child: _StatBox('Transactions', '${txs.length}', Icons.receipt_outlined, AppColors.financeGreen)),
      const SizedBox(width: 10),
      Expanded(child: _StatBox('Categories', '${cats.length}', Icons.category_outlined, AppColors.financeGreenV2)),
      const SizedBox(width: 10),
      Expanded(child: _StatBox('Avg Spend', income > 0 ? 'KES ${fmt.format(expenses / (txs.isEmpty ? 1 : txs.where((t) => !t.isIncome).length))}' : '—', Icons.trending_down_rounded, const Color(0xFFDC2626))),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ]),
    );
  }
}

class _PeriodSheet extends StatelessWidget {
  final _Period current;
  const _PeriodSheet({required this.current});

  static const _options = [
    (_Period.today, Icons.today_rounded),
    (_Period.thisWeek, Icons.view_week_rounded),
    (_Period.thisMonth, Icons.calendar_month_rounded),
    (_Period.lastMonth, Icons.history_rounded),
    (_Period.last3M, Icons.date_range_rounded),
    (_Period.last6M, Icons.bar_chart_rounded),
    (_Period.custom, Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Period',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            ),
          ),
          const SizedBox(height: 8),
          ..._options.map((opt) {
            final (period, icon) = opt;
            final selected = period == current;
            return ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: selected ? AppColors.financeGreen.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: selected ? AppColors.financeGreen : const Color(0xFF6B7280)),
              ),
              title: Text(period.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? AppColors.financeGreen : const Color(0xFF111827),
                    fontSize: 14,
                  )),
              trailing: selected
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 20)
                  : null,
              onTap: () => Navigator.pop(context, period),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TopCategories extends StatelessWidget {
  final List<FinanceTransaction> txs;
  final double expenses;
  final NumberFormat fmt;
  const _TopCategories({required this.txs, required this.expenses, required this.fmt});

  static const _colors = {
    'Groceries': Color(0xFF059669), 'Electricity': Color(0xFFF59E0B),
    'Water': Color(0xFF3B82F6), 'Rent': Color(0xFF8B5CF6),
    'Transport': Color(0xFFF97316), 'Food & Dining': Color(0xFFEF4444),
    'Airtime/Data': Color(0xFF14B8A6), 'Education': Color(0xFF6366F1),
    'Health': Color(0xFFEC4899), 'Entertainment': Color(0xFFDB2777),
  };

  @override
  Widget build(BuildContext context) {
    final cats = SmsFinanceService.expensesByCategory(txs);
    if (cats.isEmpty) return const SizedBox.shrink();
    return Column(
      children: cats.entries.take(5).map((e) {
        final pct = expenses > 0 ? e.value / expenses : 0.0;
        final color = _colors[e.key] ?? AppColors.financeGreen;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
          ),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827))),
                Text('KES ${fmt.format(e.value)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF111827))),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: pct, backgroundColor: const Color(0xFFF3F4F6), valueColor: AlwaysStoppedAnimation(color), minHeight: 4),
              ),
            ])),
          ]),
        );
      }).toList(),
    );
  }
}
