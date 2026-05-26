import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import 'loans_page.dart';
import 'loans_credit_score.dart';
import 'loan_products.dart';

class LoansTab extends StatefulWidget {
  final String userId;
  const LoansTab({super.key, required this.userId});

  @override
  State<LoansTab> createState() => _LoansTabState();
}

class _LoansTabState extends State<LoansTab> {
  Map<String, dynamic>? _eligibility;
  List<Map<String, dynamic>> _loans = [];
  bool _loading = true;
  final fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([_fetchEligibility(), _fetchLoans()]);
    setState(() => _loading = false);
  }

  Future<void> _fetchEligibility() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.loanEligibilityById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') setState(() => _eligibility = d['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchLoans() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.loansById(widget.userId)));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _loans = List<Map<String, dynamic>>.from(d['data'] ?? []));
        }
      }
    } catch (_) {}
  }

  double get _creditScore => double.tryParse(_eligibility?['credit_score']?.toString() ?? '0') ?? 0;
  double get _maxLoan => double.tryParse(_eligibility?['max_loan_amount']?.toString() ?? '0') ?? 0;
  bool get _eligible => _eligibility?['eligible'] == true || _eligibility?['eligible'] == 1;

  Color get _scoreColor {
    if (_creditScore >= 700) return const Color(0xFF059669);
    if (_creditScore >= 500) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  String get _scoreLabel {
    if (_creditScore >= 700) return 'Excellent';
    if (_creditScore >= 600) return 'Good';
    if (_creditScore >= 500) return 'Fair';
    return 'Poor';
  }

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
                          const Text('Loans & Credit', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Borrow responsibly, grow confidently', style: TextStyle(color: Colors.white60, fontSize: 13)),
                          const Spacer(),
                          if (_loading)
                            const LinearProgressIndicator(color: Colors.white, backgroundColor: Colors.white24)
                          else
                            Row(children: [
                              _HStat('Credit Score', _creditScore > 0 ? _creditScore.toInt().toString() : '—', _scoreColor),
                              const SizedBox(width: 24),
                              _HStat('Rating', _creditScore > 0 ? _scoreLabel : '—', _scoreColor),
                              const SizedBox(width: 24),
                              _HStat('Max Loan', _maxLoan > 0 ? 'KES ${fmt.format(_maxLoan)}' : '—', Colors.white),
                            ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              title: const Text('Loans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Credit score card
                  if (!_loading && _creditScore > 0) ...[
                    _CreditScoreCard(score: _creditScore, label: _scoreLabel, color: _scoreColor, maxLoan: _maxLoan, eligible: _eligible, fmt: fmt),
                    const SizedBox(height: 16),
                  ],

                  // Action cards
                  Row(children: [
                    Expanded(child: _ActionCard(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Apply Loan',
                      color: AppColors.financeGreen,
                      onTap: () => _go(LoanProducts(userId: widget.userId)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionCard(
                      icon: Icons.verified_user_outlined,
                      label: 'Credit Health',
                      color: AppColors.financeGreenV2,
                      onTap: () => _go(LoansCreditScore(userId: widget.userId)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionCard(
                      icon: Icons.list_alt_rounded,
                      label: 'My Loans',
                      color: const Color(0xFFF5A623),
                      onTap: () => _go(LoansPage(userId: widget.userId)),
                    )),
                  ]),
                  const SizedBox(height: 24),

                  // Active loans
                  const Text('Active Loans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),

                  if (_loading)
                    ...List.generate(2, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: _Skeleton(height: 90)))
                  else if (_loans.isEmpty)
                    const _EmptyState(icon: Icons.account_balance_outlined, message: 'No active loans.\nCheck your eligibility to get started.')
                  else
                    ..._loans.map((l) => _LoanCard(loan: l, fmt: fmt)),

                  const SizedBox(height: 24),

                  // Loan info tiles
                  const Text('Why Borrow Smart?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  const _InfoTile(icon: Icons.shield_outlined, title: 'No Hidden Fees', body: 'Transparent interest rates calculated on your credit score.', color: Color(0xFF059669)),
                  const SizedBox(height: 8),
                  const _InfoTile(icon: Icons.speed_outlined, title: 'Instant Disbursement', body: 'Approved loans go straight to your M-Pesa within minutes.', color: AppColors.financeGreenV3),
                  const SizedBox(height: 8),
                  const _InfoTile(icon: Icons.trending_up_rounded, title: 'Build Your Score', body: 'Repaying on time improves your credit score and unlocks higher limits.', color: Color(0xFFF5A623)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(Widget page) => Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ));
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
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      );
}

class _CreditScoreCard extends StatelessWidget {
  final double score, maxLoan;
  final String label;
  final Color color;
  final bool eligible;
  final NumberFormat fmt;
  const _CreditScoreCard({required this.score, required this.label, required this.color, required this.maxLoan, required this.eligible, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pct = (score / 850).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Credit Score', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            Text(score.toInt().toString(), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: eligible ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Icon(eligible ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: eligible ? const Color(0xFF059669) : const Color(0xFFDC2626), size: 16),
              const SizedBox(width: 6),
              Text(eligible ? 'Eligible' : 'Not eligible',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                      color: eligible ? const Color(0xFF059669) : const Color(0xFFDC2626))),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: pct, backgroundColor: const Color(0xFFF3F4F6), valueColor: AlwaysStoppedAnimation(color), minHeight: 10),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('300 Poor', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          Text('850 Excellent', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
        ]),
        if (maxLoan > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.financeGreen, size: 16),
              const SizedBox(width: 8),
              Text('Max loan: KES ${fmt.format(maxLoan)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.financeGreen)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _LoanCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final NumberFormat fmt;
  const _LoanCard({required this.loan, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(loan['amount']?.toString() ?? '0') ?? 0;
    final balance = double.tryParse(loan['balance']?.toString() ?? loan['remaining']?.toString() ?? '0') ?? 0;
    final status = loan['status']?.toString() ?? 'active';
    final pct = amount > 0 ? ((amount - balance) / amount).clamp(0.0, 1.0) : 0.0;
    final statusColor = status == 'active' ? const Color(0xFFF59E0B) : status == 'paid' ? const Color(0xFF059669) : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('KES ${fmt.format(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
            Text('Balance: KES ${fmt.format(balance)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: const AlwaysStoppedAnimation(AppColors.financeGreenV3),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(pct * 100).toStringAsFixed(0)}% repaid', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          Text('KES ${fmt.format(amount - balance)} paid', style: const TextStyle(fontSize: 10, color: AppColors.financeGreenV3, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Color color;
  const _InfoTile({required this.icon, required this.title, required this.body, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
          ])),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          Icon(icon, size: 48, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.5)),
        ]),
      );
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(14)),
      );
}
