import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../services/sms_finance_service.dart';
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

class _FinanceTabState extends State<FinanceTab> {
  List<FinanceTransaction> _txs = [];
  bool _loading = true;
  bool _smsGranted = false;
  final fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _smsGranted = await SmsFinanceService.checkPermission();
    if (_smsGranted) {
      _txs = await SmsFinanceService.loadAll();
    }
    setState(() => _loading = false);
  }

  Future<void> _requestSms() async {
    final granted = await SmsFinanceService.requestPermission();
    setState(() => _smsGranted = granted);
    if (granted) {
      setState(() => _loading = true);
      _txs = await SmsFinanceService.loadAll(forceRefresh: true);
      setState(() => _loading = false);
    }
  }

  // Current month transactions
  List<FinanceTransaction> get _thisMonth {
    final now = DateTime.now();
    return _txs.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
  }

  double get _income => SmsFinanceService.totalIncome(_thisMonth);
  double get _expenses => SmsFinanceService.totalExpenses(_thisMonth);
  double get _balance => _income - _expenses;
  double get _savingsRate => _income > 0 ? (_balance / _income * 100).clamp(0.0, 100.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.financeGreen,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F4023), Color(0xFF1B6631), Color(0xFF2D8A47)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Finance', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          _smsGranted ? '${_txs.length} transactions • Last 6 months' : 'Connect your M-Pesa & Bank SMS',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const Spacer(),
                        if (_loading)
                          const LinearProgressIndicator(color: Colors.white, backgroundColor: Colors.white24)
                        else if (_smsGranted) ...[
                          Row(children: [
                            _HStat('Income', 'KES ${fmt.format(_income)}', const Color(0xFF78FF86)),
                            const SizedBox(width: 20),
                            _HStat('Expenses', 'KES ${fmt.format(_expenses)}', const Color(0xFFFF8A80)),
                            const SizedBox(width: 20),
                            _HStat('Balance', 'KES ${fmt.format(_balance)}',
                                _balance >= 0 ? const Color(0xFF78FF86) : const Color(0xFFFF8A80)),
                          ]),
                          const SizedBox(height: 12),
                          // Savings bar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                const Text('Savings Rate', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text('${_savingsRate.toStringAsFixed(1)}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _savingsRate / 100,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation(
                                    _savingsRate >= 20 ? const Color(0xFF78FF86) : _savingsRate >= 10 ? Colors.orange : const Color(0xFFFF8A80),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: const Text('Finance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                if (_smsGranted && _txs.isNotEmpty) ...[
                  const Text('This Month at a Glance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  _QuickStatsGrid(txs: _thisMonth, fmt: fmt),
                  const SizedBox(height: 24),

                  // Top categories
                  const Text('Top Spending Categories',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  _TopCategories(txs: _thisMonth, expenses: _expenses, fmt: fmt),
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
  final Color color;
  const _HStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
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
