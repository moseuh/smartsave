import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../constants/app_constants.dart';
import '../services/transaction_auth_service.dart';

// Detail + repayment screen for a single Rafiki2Rafiki debt: shows the
// original amount borrowed, total repaid, outstanding balance, each lender's
// contribution/share, repayment history, and the "Repay now" flow.
class RafikiDebtDetailScreen extends StatefulWidget {
  final String userId;
  final String debtId;
  const RafikiDebtDetailScreen({super.key, required this.userId, required this.debtId});

  @override
  State<RafikiDebtDetailScreen> createState() => _RafikiDebtDetailScreenState();
}

class _RafikiDebtDetailScreenState extends State<RafikiDebtDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _debt;
  String _userPhone = '';
  final _fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
    _fetchUserPhone();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse(
          ApiConfig.getUrl('rafiki-debts/detail/${widget.debtId}?user_id=${widget.userId}')));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          setState(() => _debt = Map<String, dynamic>.from(d['data']));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchUserPhone() async {
    try {
      final r = await http.get(Uri.parse(ApiConfig.getUrl('user-details/${widget.userId}')));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          final details = Map<String, dynamic>.from(d['data']);
          for (final k in ['phone_number', 'phone', 'msisdn', 'mobile']) {
            final v = details[k]?.toString().trim() ?? '';
            if (v.isNotEmpty) {
              if (mounted) setState(() => _userPhone = v);
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  void _openRepaySheet() {
    if (_debt == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RepaySheet(
        userId: widget.userId,
        debtId: widget.debtId,
        walletBalance: double.tryParse(_debt!['wallet_balance']?.toString() ?? '0') ?? 0,
        outstanding: double.tryParse(_debt!['outstanding']?.toString() ?? '0') ?? 0,
        userPhone: _userPhone,
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
        title: Text(_debt?['title']?.toString() ?? 'Rafiki2Rafiki Debt',
            style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
          : _debt == null
              ? const Center(child: Text('Debt not found'))
              : RefreshIndicator(
                  color: AppColors.financeGreen,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 20),
                      _buildLendersSection(),
                      const SizedBox(height: 20),
                      _buildHistorySection(),
                    ],
                  ),
                ),
      bottomNavigationBar: (_debt != null && _debt!['status'] != 'repaid')
          ? Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (double.tryParse(_debt!['wallet_balance']?.toString() ?? '0') ?? 0) > 0
                      ? _openRepaySheet
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.financeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Repay Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryCard() {
    final principal = double.tryParse(_debt!['principal']?.toString() ?? '0') ?? 0;
    final repaid = double.tryParse(_debt!['total_repaid']?.toString() ?? '0') ?? 0;
    final outstanding = double.tryParse(_debt!['outstanding']?.toString() ?? '0') ?? 0;
    final walletBalance = double.tryParse(_debt!['wallet_balance']?.toString() ?? '0') ?? 0;
    final isPaid = _debt!['status'] == 'repaid';
    final progress = principal > 0 ? (repaid / principal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isPaid
            ? [AppColors.financeGreen, const Color(0xFF15803D)]
            : [const Color(0xFF1B6631), const Color(0xFF27AE60)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Outstanding Balance', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('KES ${_fmt.format(outstanding)}',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress, minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _summaryStat('Borrowed', 'KES ${_fmt.format(principal)}'),
          _summaryStat('Repaid', 'KES ${_fmt.format(repaid)}'),
          _summaryStat('In Wallet', 'KES ${_fmt.format(walletBalance)}'),
        ]),
        if (!isPaid && walletBalance > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'KES ${_fmt.format(walletBalance)} has been deposited and is ready to repay. Tap "Repay Now" to send it to your lenders.',
                  style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _summaryStat(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _buildLendersSection() {
    final lenders = List<Map<String, dynamic>>.from(_debt!['lenders'] ?? []);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Lenders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        ...lenders.map((l) {
          final amt = double.tryParse(l['amount']?.toString() ?? '0') ?? 0;
          final pct = double.tryParse(l['share_pct']?.toString() ?? '0') ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.financeGreen.withValues(alpha: 0.1),
                child: Text(
                  (l['contributor_name']?.toString() ?? '?').characters.first.toUpperCase(),
                  style: const TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l['contributor_name']?.toString() ?? 'Anonymous',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                Text('${pct.toStringAsFixed(1)}% of loan', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ])),
              Text('KES ${_fmt.format(amt)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            ]),
          );
        }),
        if (lenders.isEmpty)
          const Text('No lenders yet', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ]),
    );
  }

  Widget _buildHistorySection() {
    final repayments = List<Map<String, dynamic>>.from(_debt!['repayments'] ?? []);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Repayment History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 12),
        if (repayments.isEmpty)
          const Text('No repayments yet', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))
        else
          ...repayments.map((r) {
            final principal = double.tryParse(r['principal_amount']?.toString() ?? '0') ?? 0;
            final fee = double.tryParse(r['fee_amount']?.toString() ?? '0') ?? 0;
            final status = r['status']?.toString() ?? 'pending';
            String dateStr = '';
            try {
              dateStr = DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(r['created_at'] ?? '').toLocal());
            } catch (_) {}
            final statusColor = status == 'completed'
                ? AppColors.financeGreen
                : status == 'failed'
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFF59E0B);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('KES ${_fmt.format(principal)} repaid', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('Fee: KES ${_fmt.format(fee)} · $dateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                if (r['error_message'] != null && r['error_message'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r['error_message'].toString(), style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                ],
              ]),
            );
          }),
      ]),
    );
  }
}

// ── Repay Now bottom sheet: amount entry -> breakdown preview -> confirm ──
class _RepaySheet extends StatefulWidget {
  final String userId, debtId;
  final double walletBalance, outstanding;
  final String userPhone;
  final VoidCallback onDone;
  const _RepaySheet({
    required this.userId,
    required this.debtId,
    required this.walletBalance,
    required this.outstanding,
    required this.userPhone,
    required this.onDone,
  });

  @override
  State<_RepaySheet> createState() => _RepaySheetState();
}

class _RepaySheetState extends State<_RepaySheet> {
  late final _amtCtrl = TextEditingController(
      text: (widget.walletBalance < widget.outstanding ? widget.walletBalance : widget.outstanding).round().toString());
  late final _phoneCtrl = TextEditingController(text: widget.userPhone);
  final _fmt = NumberFormat('#,##0.00');
  bool _loadingPreview = false;
  bool _submitting = false;
  Map<String, dynamic>? _preview;
  String? _error;
  // 'wallet' repays with money already collected from lenders (capped at
  // wallet_balance). 'mpesa' lets the borrower top up with their own fresh
  // money regardless of how much has been collected so far.
  String _source = 'wallet';

  @override
  void dispose() {
    _amtCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPreview() async {
    final amt = double.tryParse(_amtCtrl.text.trim());
    if (amt == null || amt <= 0) {
      setState(() { _error = 'Enter a valid amount'; _preview = null; });
      return;
    }
    if (_source == 'mpesa' && _phoneCtrl.text.trim().isEmpty) {
      setState(() { _error = 'Enter the M-Pesa number to pay from'; _preview = null; });
      return;
    }
    setState(() { _loadingPreview = true; _error = null; _preview = null; });
    try {
      final r = await http.post(
        Uri.parse(ApiConfig.getUrl('rafiki-debts/${widget.debtId}/repay-preview')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId, 'amount': amt, 'source': _source}),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['status'] == 'success') {
        setState(() => _preview = Map<String, dynamic>.from(d['data']));
      } else {
        setState(() => _error = d['message'] ?? 'Could not calculate repayment');
      }
    } catch (_) {
      setState(() => _error = 'Network error — check your connection');
    }
    if (mounted) setState(() => _loadingPreview = false);
  }

  Future<void> _confirmRepay() async {
    if (_preview == null) return;
    final authed = await TransactionAuthService.authenticate(context);
    if (!authed || !mounted) return;
    setState(() => _submitting = true);
    try {
      final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0;
      if (_source == 'mpesa') {
        final r = await http.post(
          Uri.parse(ApiConfig.getUrl('rafiki-debts/${widget.debtId}/repay-mpesa')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': widget.userId, 'amount': amt, 'phone': _phoneCtrl.text.trim()}),
        );
        final d = jsonDecode(r.body);
        if (r.statusCode == 200 && d['status'] == 'success') {
          if (mounted) {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              isDismissible: false,
              enableDrag: false,
              backgroundColor: Colors.transparent,
              builder: (_) => _RepayMpesaProcessingSheet(
                ref: (d['checkout_id'] ?? d['ref']).toString(),
                onDone: widget.onDone,
              ),
            );
          }
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(d['message']?.toString() ?? 'Could not send STK push'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      } else {
        final r = await http.post(
          Uri.parse(ApiConfig.getUrl('rafiki-debts/${widget.debtId}/repay')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': widget.userId, 'amount': amt}),
        );
        final d = jsonDecode(r.body);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(d['message']?.toString() ?? (d['status'] == 'success' ? 'Repayment sent' : 'Repayment failed')),
            backgroundColor: d['status'] == 'success' ? AppColors.financeGreen : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ));
          widget.onDone();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Network error — check your connection'),
          backgroundColor: Colors.red,
        ));
      }
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
            const Text('Repay Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('KES ${_fmt.format(widget.walletBalance)} available in your debt wallet',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            const Text('Pay from', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _sourceBtn('Debt Wallet', 'wallet')),
              const SizedBox(width: 10),
              Expanded(child: _sourceBtn('M-Pesa', 'mpesa')),
            ]),
            const SizedBox(height: 14),
            if (_source == 'mpesa') ...[
              const Text('M-Pesa Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() => _preview = null),
                decoration: InputDecoration(
                  hintText: '07XXXXXXXX',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text('Amount to Repay (KES)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _preview = null),
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
            if (_source == 'mpesa') ...[
              const SizedBox(height: 6),
              const Text('Pay any amount — this tops up your debt wallet before it goes to your lenders.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loadingPreview ? null : _fetchPreview,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.financeGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loadingPreview
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.financeGreen))
                    : const Text('Calculate Breakdown', style: TextStyle(color: AppColors.financeGreen, fontWeight: FontWeight.w700)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (_preview != null) ...[
              const SizedBox(height: 16),
              _buildBreakdown(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _confirmRepay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.financeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Repayment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _sourceBtn(String label, String value) {
    final selected = _source == value;
    return GestureDetector(
      onTap: () => setState(() { _source = value; _preview = null; _error = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.financeGreen.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB), width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.financeGreen : const Color(0xFF6B7280),
        )),
      ),
    );
  }

  Widget _buildBreakdown() {
    final p = _preview!;
    final principal = double.tryParse(p['principal_amount']?.toString() ?? '0') ?? 0;
    final fee = double.tryParse(p['fee_amount']?.toString() ?? '0') ?? 0;
    final roundup = double.tryParse(p['roundup_amount']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(p['total_deducted']?.toString() ?? '0') ?? 0;
    final remaining = double.tryParse(p['outstanding_after']?.toString() ?? '0') ?? 0;
    final lenders = List<Map<String, dynamic>>.from(p['lender_breakdown'] ?? []);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row('Amount being repaid', 'KES ${_fmt.format(principal)}'),
        const SizedBox(height: 10),
        const Text('Each lender receives', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        ...lenders.map((l) {
          final amt = double.tryParse(l['amount']?.toString() ?? '0') ?? 0;
          final pct = double.tryParse(l['share_pct']?.toString() ?? '0') ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${l['contributor_name']} (${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              Text('KES ${_fmt.format(amt)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            ]),
          );
        }),
        const Divider(height: 18, color: Color(0xFFD1FAE5)),
        _row('Transaction fee', '+ KES ${_fmt.format(fee)}'),
        if (roundup > 0) ...[
          const SizedBox(height: 6),
          _row('Round-up savings', '+ KES ${_fmt.format(roundup)}'),
        ],
        const SizedBox(height: 6),
        Text(
          p['fee_note']?.toString() ?? 'Third-party M-Pesa transfer fee — not interest or profit.',
          style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
        ),
        const Divider(height: 18, color: Color(0xFFD1FAE5)),
        _row('Total to be deducted', 'KES ${_fmt.format(total)}', bold: true),
        const SizedBox(height: 6),
        _row('Remaining debt after', 'KES ${_fmt.format(remaining)}'),
      ]),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 13 : 12, color: bold ? const Color(0xFF111827) : const Color(0xFF6B7280), fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: bold ? 13 : 12, color: bold ? AppColors.financeGreen : const Color(0xFF374151), fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      );
}

// ── STK push processing sheet for M-Pesa-sourced Rafiki repayments ──
// Polls /transaction-status/:ref until PayHero confirms; the backend's
// RAFIKIMPESA callback branch handles crediting the debt wallet/goal and
// dispatching the repayment to lenders once the STK push is confirmed.
class _RepayMpesaProcessingSheet extends StatefulWidget {
  final String ref;
  final VoidCallback onDone;
  const _RepayMpesaProcessingSheet({required this.ref, required this.onDone});

  @override
  State<_RepayMpesaProcessingSheet> createState() => _RepayMpesaProcessingSheetState();
}

class _RepayMpesaProcessingSheetState extends State<_RepayMpesaProcessingSheet> {
  bool _polling = true;
  bool _success = false;
  bool _failed = false;
  String? _error;
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_polling || !mounted) return;
      _elapsed += 5;
      if (_elapsed >= 60) {
        setState(() { _polling = false; _failed = true; _error = 'Payment timed out. Please try again.'; });
        _timer?.cancel();
        return;
      }
      try {
        final r = await http.get(
          Uri.parse('${AppConstants.apiBaseUrl}/transaction-status/${widget.ref}'),
        ).timeout(const Duration(seconds: 8));
        final d = jsonDecode(r.body);
        final status = ((d['data']?['transaction_status'] ?? d['payment_status'] ?? d['status'] ?? '')).toString().toLowerCase();
        if (status == 'completed' || status == 'success') {
          _timer?.cancel();
          if (mounted) setState(() { _polling = false; _success = true; });
          widget.onDone();
        } else if (status == 'failed' || status == 'cancelled') {
          _timer?.cancel();
          final errMsg = d['data']?['error_message'] ?? d['message'] ?? 'Payment failed. Please try again.';
          if (mounted) setState(() { _polling = false; _failed = true; _error = errMsg.toString(); });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, mq.viewInsets.bottom + mq.padding.bottom + 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 28),
        if (_success) ...[
          Container(width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.financeGreen, size: 40)),
          const SizedBox(height: 16),
          const Text('Repayment Sent!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text('Your M-Pesa payment was received and sent to your lenders.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _greenBtn('Done', () => Navigator.pop(context)),
        ] else if (_failed) ...[
          Container(width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 40)),
          const SizedBox(height: 16),
          const Text('Payment Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(_error ?? 'Something went wrong.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _greenBtn('Close', () => Navigator.pop(context)),
        ] else ...[
          SpinKitFadingCircle(color: AppColors.financeGreenV3, size: 56),
          const SizedBox(height: 24),
          const Text('Check your phone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 8),
          const Text('Enter your M-Pesa PIN to complete the repayment',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () { _polling = false; _timer?.cancel(); Navigator.pop(context); },
            child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 14)),
          ),
        ],
      ]),
    );
  }

  Widget _greenBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.financeGreen,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  );
}
