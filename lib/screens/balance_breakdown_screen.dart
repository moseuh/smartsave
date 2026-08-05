import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../services/transaction_auth_service.dart';

// Shows where a user's money actually is: Available (spendable now), Goals
// (saved toward a target), Debt Repayment (saved to pay off a debt), and
// Rafiki (borrowed money, still locked until released). Each non-Available
// bucket has a "Move to wallet" action so money is never stuck with no way
// back — this screen exists because splitting the Home balance into
// "Wallet"/"Available" without a way to actually move money between them
// left users unable to find or reach their own funds.
class BalanceBreakdownScreen extends StatefulWidget {
  final String userId;
  const BalanceBreakdownScreen({super.key, required this.userId});

  @override
  State<BalanceBreakdownScreen> createState() => _BalanceBreakdownScreenState();
}

class _BalanceBreakdownScreenState extends State<BalanceBreakdownScreen> {
  bool _loading = true;
  double _available = 0;
  List<Map<String, dynamic>> _savingsGoals = [];
  List<Map<String, dynamic>> _debtGoals = []; // debt_payoff goals, joined with user_debts id
  List<Map<String, dynamic>> _rafikiGoals = []; // rafiki_debt goals, joined with rafiki_debts id
  final _fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.goalsListById(widget.userId))),
        http.get(Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/debts'))),
        http.get(Uri.parse(ApiConfig.getUrl('rafiki-debts/${widget.userId}'))),
      ]);

      List<Map<String, dynamic>> goals = [];
      final gr = results[0];
      if (gr.statusCode == 200) {
        final d = jsonDecode(gr.body);
        if (d['status'] == 'success') goals = List<Map<String, dynamic>>.from(d['data'] ?? []);
      }

      List<Map<String, dynamic>> manualDebts = [];
      final dr = results[1];
      if (dr.statusCode == 200) {
        final d = jsonDecode(dr.body);
        if (d['status'] == 'success') manualDebts = List<Map<String, dynamic>>.from(d['data'] ?? []);
      }

      List<Map<String, dynamic>> rafikiDebts = [];
      final rr = results[2];
      if (rr.statusCode == 200) {
        final d = jsonDecode(rr.body);
        if (d['status'] == 'success') rafikiDebts = List<Map<String, dynamic>>.from(d['data'] ?? []);
      }

      double available = 0;
      final savingsGoals = <Map<String, dynamic>>[];
      final debtGoals = <Map<String, dynamic>>[];
      final rafikiGoals = <Map<String, dynamic>>[];

      for (final g in goals) {
        final amt = double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0;
        final type = g['goal_type']?.toString() ?? '';
        if (g['is_default'] == true) {
          available = amt;
        } else if (type == 'debt_payoff') {
          final debt = manualDebts.firstWhere(
            (d) => d['goal_id']?.toString() == g['id']?.toString(),
            orElse: () => {},
          );
          debtGoals.add({...g, 'debt_id': debt['id'], 'creditor_name': debt['creditor_name']});
        } else if (type == 'rafiki_debt') {
          final debt = rafikiDebts.firstWhere(
            (d) => d['goal_id']?.toString() == g['id']?.toString(),
            orElse: () => {},
          );
          rafikiGoals.add({...g, 'rafiki_debt_id': debt['id'], 'wallet_balance': debt['wallet_balance']});
        } else {
          savingsGoals.add(g);
        }
      }

      setState(() {
        _available = available;
        _savingsGoals = savingsGoals;
        _debtGoals = debtGoals;
        _rafikiGoals = rafikiGoals;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double get _goalsTotal => _savingsGoals.fold(0.0, (s, g) => s + (double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0));
  double get _debtTotal => _debtGoals.fold(0.0, (s, g) => s + (double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0));
  double get _rafikiTotal => _rafikiGoals.fold(0.0, (s, g) => s + (double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0));
  double get _total => _available + _goalsTotal + _debtTotal + _rafikiTotal;

  void _openMoveSheet({
    required String title,
    required double maxAmount,
    required String endpointUrl,
    required Map<String, dynamic> body,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoveToWalletSheet(
        title: title,
        maxAmount: maxAmount,
        endpointUrl: endpointUrl,
        body: body,
        onDone: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Where Your Money Is',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
          : RefreshIndicator(
              color: AppColors.financeGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.financeGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total Nebo Balance', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('KES ${_fmt.format(_total)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  _BucketHeader(label: 'Available to Spend', amount: _available, color: AppColors.financeGreen, icon: Icons.check_circle_rounded),
                  const SizedBox(height: 6),
                  const Text('This is the only money that can be used for payments, sending, or withdrawing.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 24),

                  _BucketHeader(label: 'In Goals', amount: _goalsTotal, color: const Color(0xFF6366F1), icon: Icons.savings_rounded),
                  const SizedBox(height: 10),
                  if (_savingsGoals.isEmpty)
                    const _EmptyBucketRow(text: 'No money saved in goals yet.')
                  else
                    ..._savingsGoals.map((g) => _BucketRow(
                          title: g['goal_name']?.toString() ?? 'Goal',
                          amount: double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0,
                          color: const Color(0xFF6366F1),
                          onMove: (amt, ctx) => _openMoveSheet(
                            title: 'Move from "${g['goal_name']}"',
                            maxAmount: double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0,
                            endpointUrl: ApiConfig.goalsWithdraw,
                            body: {'user_id': widget.userId, 'goal_id': g['id']},
                          ),
                        )),
                  const SizedBox(height: 24),

                  _BucketHeader(label: 'Debt Repayment', amount: _debtTotal, color: const Color(0xFFF59E0B), icon: Icons.receipt_long_rounded),
                  const SizedBox(height: 6),
                  const Text('Saved toward paying off a debt. Move it back if you need it before you repay.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 10),
                  if (_debtGoals.isEmpty)
                    const _EmptyBucketRow(text: 'Nothing saved toward a debt yet.')
                  else
                    ..._debtGoals.map((g) => _BucketRow(
                          title: g['creditor_name']?.toString() ?? g['goal_name']?.toString() ?? 'Debt',
                          amount: double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0,
                          color: const Color(0xFFF59E0B),
                          onMove: g['debt_id'] == null
                              ? null
                              : (amt, ctx) => _openMoveSheet(
                                    title: 'Move from "${g['creditor_name'] ?? g['goal_name']}"',
                                    maxAmount: double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0,
                                    endpointUrl: ApiConfig.debtWithdrawToWallet(g['debt_id'].toString()),
                                    body: {'user_id': widget.userId},
                                  ),
                        )),
                  const SizedBox(height: 24),

                  _BucketHeader(label: 'Rafiki (Borrowed)', amount: _rafikiTotal, color: const Color(0xFF0EA5E9), icon: Icons.people_alt_rounded),
                  const SizedBox(height: 6),
                  const Text('Money borrowed via Rafiki2Rafiki. Releasing it doesn\'t reduce what you owe your lenders.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 10),
                  if (_rafikiGoals.isEmpty)
                    const _EmptyBucketRow(text: 'No borrowed funds right now.')
                  else
                    ..._rafikiGoals.map((g) => _BucketRow(
                          title: g['goal_name']?.toString() ?? 'Rafiki link',
                          amount: double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0,
                          color: const Color(0xFF0EA5E9),
                          buttonLabel: 'Release',
                          onMove: g['rafiki_debt_id'] == null
                              ? null
                              : (amt, ctx) => _openMoveSheet(
                                    title: 'Release from "${g['goal_name']}"',
                                    maxAmount: double.tryParse(g['current_amount']?.toString() ?? '0') ?? 0,
                                    endpointUrl: ApiConfig.rafikiReleaseToWallet(g['rafiki_debt_id'].toString()),
                                    body: {'user_id': widget.userId},
                                  ),
                        )),
                ],
              ),
            ),
    );
  }
}

class _BucketHeader extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  const _BucketHeader({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
      Text('KES ${fmt.format(amount)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}

class _BucketRow extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final String buttonLabel;
  final void Function(double amount, BuildContext ctx)? onMove;
  const _BucketRow({required this.title, required this.amount, required this.color, this.buttonLabel = 'Move', this.onMove});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('KES ${fmt.format(amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
        if (onMove != null && amount > 0)
          OutlinedButton(
            onPressed: () => onMove!(amount, context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(buttonLabel, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

class _EmptyBucketRow extends StatelessWidget {
  final String text;
  const _EmptyBucketRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
    );
  }
}

// ── Move-to-wallet sheet: shared by goal/debt/rafiki move actions ─────────
class _MoveToWalletSheet extends StatefulWidget {
  final String title;
  final double maxAmount;
  final String endpointUrl;
  final Map<String, dynamic> body;
  final VoidCallback onDone;
  const _MoveToWalletSheet({
    required this.title,
    required this.maxAmount,
    required this.endpointUrl,
    required this.body,
    required this.onDone,
  });

  @override
  State<_MoveToWalletSheet> createState() => _MoveToWalletSheetState();
}

class _MoveToWalletSheetState extends State<_MoveToWalletSheet> {
  late final _amtCtrl = TextEditingController(text: widget.maxAmount.round().toString());
  final _fmt = NumberFormat('#,##0.00');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amtCtrl.text.trim());
    if (amt == null || amt <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (amt > widget.maxAmount) {
      setState(() => _error = 'Amount exceeds what\'s available here');
      return;
    }
    final authed = await TransactionAuthService.authenticate(context);
    if (!authed || !mounted) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final r = await http.post(
        Uri.parse(widget.endpointUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({...widget.body, 'amount': amt}),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['status'] == 'success') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(d['message']?.toString() ?? 'Moved to your wallet'),
            backgroundColor: AppColors.financeGreen,
            behavior: SnackBarBehavior.floating,
          ));
          widget.onDone();
        }
      } else {
        setState(() => _error = d['message']?.toString() ?? 'Could not move funds');
      }
    } catch (_) {
      setState(() => _error = 'Network error — check your connection');
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, mq.padding.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
            Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('KES ${_fmt.format(widget.maxAmount)} available to move',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            const Text('Amount (KES)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: '0',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.financeGreen,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Move to Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
