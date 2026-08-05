import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../config/api_config.dart';
import '../services/transaction_auth_service.dart';
import 'rafiki_debt_detail_screen.dart';

const Map<String, String> _debtTypeLabels = {
  'bank_loan': 'Bank Loan',
  'mobile_loan': 'Mobile Loan',
  'sacco': 'SACCO',
  'friend_family': 'Friend / Family',
  'shylock': 'Shylock',
  'credit_card': 'Credit Card',
  'other': 'Other',
};

const Map<String, IconData> _debtTypeIcons = {
  'bank_loan': Icons.account_balance_rounded,
  'mobile_loan': Icons.phone_android_rounded,
  'sacco': Icons.groups_rounded,
  'friend_family': Icons.people_rounded,
  'shylock': Icons.warning_amber_rounded,
  'credit_card': Icons.credit_card_rounded,
  'other': Icons.receipt_long_rounded,
};

class DebtManagerScreen extends StatefulWidget {
  final String userId;
  const DebtManagerScreen({super.key, required this.userId});

  @override
  State<DebtManagerScreen> createState() => _DebtManagerScreenState();
}

class _DebtManagerScreenState extends State<DebtManagerScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _rafikiDebts = [];
  final _fmt = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/debts'))),
        http.get(Uri.parse(ApiConfig.getUrl('rafiki-debts/${widget.userId}'))),
      ]);
      final r = results[0];
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d['status'] == 'success') {
          final list = List<Map<String, dynamic>>.from(d['data'] ?? []);
          list.sort((a, b) {
            const order = {'high': 0, 'medium': 1, 'low': 2};
            final pa = order[a['priority']] ?? 1;
            final pb = order[b['priority']] ?? 1;
            if (pa != pb) return pa.compareTo(pb);
            final da = a['due_date']?.toString() ?? '';
            final db = b['due_date']?.toString() ?? '';
            if (da.isEmpty) return 1;
            if (db.isEmpty) return -1;
            return da.compareTo(db);
          });
          setState(() => _debts = list);
        }
      }
      final rr = results[1];
      if (rr.statusCode == 200) {
        final d = jsonDecode(rr.body);
        if (d['status'] == 'success') {
          setState(() => _rafikiDebts = List<Map<String, dynamic>>.from(d['data'] ?? []));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double get _totalOwed =>
      _debts
          .where((d) => d['status'] != 'paid_off')
          .fold(0.0, (sum, d) => sum + (double.tryParse(d['amount_owed']?.toString() ?? '0') ?? 0)) +
      _rafikiDebts
          .where((d) => d['status'] != 'repaid')
          .fold(0.0, (sum, d) => sum + (double.tryParse(d['outstanding']?.toString() ?? '0') ?? 0));

  int get _activeCount =>
      _debts.where((d) => d['status'] != 'paid_off').length +
      _rafikiDebts.where((d) => d['status'] != 'repaid').length;

  void _openRafikiDetail(Map<String, dynamic> debt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RafikiDebtDetailScreen(userId: widget.userId, debtId: debt['id'].toString()),
      ),
    ).then((_) => _load());
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DebtFormSheet(
        userId: widget.userId,
        existing: existing,
        onSaved: _load,
      ),
    );
  }

  Future<void> _markPaidOff(Map<String, dynamic> debt) async {
    try {
      await http.patch(
        Uri.parse(ApiConfig.getUrl('onboarding/debts/${debt['id']}')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId, 'status': 'paid_off'}),
      );
      _load();
    } catch (_) {}
  }

  void _openTopUp(Map<String, dynamic> debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpSheet(
        userId: widget.userId,
        debt: debt,
        onDone: _load,
      ),
    );
  }

  void _openConfirmRepayment(Map<String, dynamic> debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmRepaymentSheet(
        userId: widget.userId,
        debt: debt,
        onDone: _load,
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> debt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete debt?'),
        content: Text('Remove "${debt['creditor_name']}" from your debt list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await http.delete(
        Uri.parse(ApiConfig.getUrl('onboarding/debts/${debt['id']}')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId}),
      );
      _load();
    } catch (_) {}
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
        title: const Text('Debt Manager',
            style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.financeGreen,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Debt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreen))
          : RefreshIndicator(
              color: AppColors.financeGreen,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFB91C1C)]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Total You Owe', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('KES ${_fmt.format(_totalOwed)}',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('across $_activeCount active ${_activeCount == 1 ? 'debt' : 'debts'}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  if (_debts.isEmpty && _rafikiDebts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(children: [
                        Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No debts tracked', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Tap "Add Debt" to start tracking what you owe',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12), textAlign: TextAlign.center),
                      ]),
                    )
                  else ...[
                    ..._rafikiDebts.map((d) => _RafikiDebtCard(
                          debt: d,
                          fmt: _fmt,
                          onTap: () => _openRafikiDetail(d),
                        )),
                    ..._debts.map((d) => _DebtCard(
                          debt: d,
                          fmt: _fmt,
                          onTap: () => _openForm(existing: d),
                          onTopUp: () => _openTopUp(d),
                          onConfirmRepayment: () => _openConfirmRepayment(d),
                          onMarkPaid: () => _markPaidOff(d),
                          onDelete: () => _delete(d),
                        )),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Rafiki2Rafiki debt card — money borrowed from friends/family via a link ──
class _RafikiDebtCard extends StatelessWidget {
  final Map<String, dynamic> debt;
  final NumberFormat fmt;
  final VoidCallback onTap;
  const _RafikiDebtCard({required this.debt, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPaid = debt['status'] == 'repaid';
    final outstanding = double.tryParse(debt['outstanding']?.toString() ?? '0') ?? 0;
    final walletBalance = double.tryParse(debt['wallet_balance']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
          border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (isPaid ? AppColors.financeGreen : AppColors.financeGreen).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.people_alt_rounded, color: AppColors.financeGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(debt['title']?.toString() ?? 'Rafiki2Rafiki',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(
              isPaid
                  ? 'Rafiki2Rafiki • Fully repaid'
                  : walletBalance > 0
                      ? 'Rafiki2Rafiki • KES ${fmt.format(walletBalance)} ready to repay'
                      : 'Rafiki2Rafiki',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('KES ${fmt.format(outstanding)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14,
                  color: isPaid ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                  decoration: isPaid ? TextDecoration.lineThrough : null,
                )),
            const SizedBox(height: 4),
            if (isPaid)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('Repaid', style: TextStyle(fontSize: 10, color: AppColors.financeGreen, fontWeight: FontWeight.w700)),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF9CA3AF)),
          ]),
        ]),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Map<String, dynamic> debt;
  final NumberFormat fmt;
  final VoidCallback onTap, onTopUp, onConfirmRepayment, onMarkPaid, onDelete;
  const _DebtCard({required this.debt, required this.fmt, required this.onTap, required this.onTopUp, required this.onConfirmRepayment, required this.onMarkPaid, required this.onDelete});

  Color get _priorityColor {
    switch (debt['priority']) {
      case 'high': return const Color(0xFFDC2626);
      case 'low': return const Color(0xFF9CA3AF);
      default: return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = debt['status'] == 'paid_off';
    final type = debt['debt_type']?.toString() ?? 'other';
    final amt = double.tryParse(debt['amount_owed']?.toString() ?? '0') ?? 0;
    final dueDate = debt['due_date']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: (isPaid ? AppColors.financeGreen : _priorityColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_debtTypeIcons[type] ?? Icons.receipt_long_rounded,
                color: isPaid ? AppColors.financeGreen : _priorityColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(debt['creditor_name']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(
              '${_debtTypeLabels[type] ?? 'Other'}${dueDate != null && dueDate.isNotEmpty ? ' • Due ${dueDate.substring(0, 10)}' : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('KES ${fmt.format(amt)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14,
                  color: isPaid ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                  decoration: isPaid ? TextDecoration.lineThrough : null,
                )),
            const SizedBox(height: 4),
            if (isPaid)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('Paid off', style: TextStyle(fontSize: 10, color: AppColors.financeGreen, fontWeight: FontWeight.w700)),
              )
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onTopUp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Top Up', style: TextStyle(fontSize: 11, color: AppColors.financeGreen, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (debt['creditor_id'] != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onConfirmRepayment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Confirm Repayment', style: TextStyle(fontSize: 11, color: Color(0xFF0EA5E9), fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF9CA3AF)),
                  onSelected: (v) => v == 'paid' ? onMarkPaid() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'paid', child: Text('Mark Paid Off')),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ]),
          ]),
        ]),
      ),
    );
  }
}

class _DebtFormSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _DebtFormSheet({required this.userId, this.existing, required this.onSaved});

  @override
  State<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<_DebtFormSheet> {
  late final _nameCtrl = TextEditingController(text: widget.existing?['creditor_name']?.toString() ?? '');
  late final _amtCtrl = TextEditingController(text: widget.existing?['amount_owed'] != null ? '${double.tryParse(widget.existing!['amount_owed'].toString())?.round()}' : '');
  late String _type = widget.existing?['debt_type']?.toString() ?? 'other';
  late String _priority = widget.existing?['priority']?.toString() ?? 'medium';
  bool _saving = false;

  // Registered creditor picked from the search typeahead below. Null means
  // an informal debt (friend, shylock, etc) — unchanged behavior. Once set,
  // repayments can actually reach the creditor via Confirm Repayment.
  int? _selectedCreditorId;
  String? _selectedCreditorName;
  List<Map<String, dynamic>> _creditorResults = [];
  bool _searchingCreditors = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.existing?['creditor_id'] != null) {
      _selectedCreditorId = int.tryParse(widget.existing!['creditor_id'].toString());
      _selectedCreditorName = widget.existing?['registered_creditor_name']?.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onNameChanged(String value) {
    // Typing again after a creditor was selected means they're changing
    // their mind — go back to plain free text until they pick again.
    if (_selectedCreditorId != null) setState(() => _selectedCreditorId = null);
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _creditorResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () => _searchCreditors(value.trim()));
  }

  Future<void> _searchCreditors(String q) async {
    setState(() => _searchingCreditors = true);
    try {
      final r = await http.get(Uri.parse(ApiConfig.getUrl('creditors/search?q=${Uri.encodeQueryComponent(q)}')));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['status'] == 'success' && mounted) {
        setState(() => _creditorResults = List<Map<String, dynamic>>.from(d['data'] ?? []));
      }
    } catch (_) {}
    if (mounted) setState(() => _searchingCreditors = false);
  }

  void _selectCreditor(Map<String, dynamic> c) {
    setState(() {
      _selectedCreditorId = c['id'] as int?;
      _selectedCreditorName = c['org_name']?.toString();
      _nameCtrl.text = c['org_name']?.toString() ?? '';
      _creditorResults = [];
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.trim());
    if (name.isEmpty || amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a creditor name and valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      final isEdit = widget.existing != null;
      final uri = isEdit
          ? Uri.parse(ApiConfig.getUrl('onboarding/debts/${widget.existing!['id']}'))
          : Uri.parse(ApiConfig.getUrl('onboarding/${widget.userId}/debts'));
      final body = {
        'user_id': widget.userId,
        'creditor_name': name,
        'debt_type': _type,
        'amount_owed': amt,
        'priority': _priority,
        if (_selectedCreditorId != null) 'creditor_id': _selectedCreditorId,
      };
      final r = isEdit
          ? await http.patch(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          : await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      if (r.statusCode == 200) {
        widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save. Try again.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error')));
    }
    if (mounted) setState(() => _saving = false);
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
          Text(widget.existing != null ? 'Edit Debt' : 'Add Debt',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 16),
          const Text('Creditor Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            onChanged: _onNameChanged,
            decoration: _dec('e.g. KCB Bank').copyWith(
              suffixIcon: _searchingCreditors
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : _selectedCreditorId != null
                      ? const Icon(Icons.verified_rounded, color: AppColors.financeGreen, size: 20)
                      : null,
            ),
          ),
          if (_selectedCreditorId != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.financeGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.link_rounded, size: 14, color: AppColors.financeGreen),
                const SizedBox(width: 6),
                Expanded(child: Text('Linked to $_selectedCreditorName — repayments will reach them directly',
                    style: const TextStyle(fontSize: 11, color: AppColors.financeGreen, fontWeight: FontWeight.w600))),
                GestureDetector(
                  onTap: () => setState(() => _selectedCreditorId = null),
                  child: const Icon(Icons.close_rounded, size: 14, color: AppColors.financeGreen),
                ),
              ]),
            ),
          ] else if (_creditorResults.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(10)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _creditorResults.map((c) => InkWell(
                  onTap: () => _selectCreditor(c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.business_rounded, size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c['org_name']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                    ]),
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text('Amount Owed (KES)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          TextField(controller: _amtCtrl, keyboardType: TextInputType.number, decoration: _dec('0')),
          const SizedBox(height: 14),
          const Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: _debtTypeLabels.entries.map((e) {
            final selected = _type == e.key;
            return GestureDetector(
              onTap: () => setState(() => _type = e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.financeGreen.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
                ),
                child: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.financeGreen : const Color(0xFF6B7280))),
              ),
            );
          }).toList()),
          const SizedBox(height: 14),
          const Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Row(children: ['high', 'medium', 'low'].map((p) {
            final selected = _priority == p;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priority = p),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.financeGreen : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB)),
                  ),
                  child: Text(p[0].toUpperCase() + p.substring(1),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF6B7280))),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.existing != null ? 'Save Changes' : 'Add Debt', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ]),
      ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.financeGreen, width: 1.5)),
      );
}

// ── Top Up sheet: pay money from the wallet toward a manually-tracked debt ──
class _TopUpSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> debt;
  final VoidCallback onDone;
  const _TopUpSheet({required this.userId, required this.debt, required this.onDone});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  late final _amtCtrl = TextEditingController();
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
    final authed = await TransactionAuthService.authenticate(context);
    if (!authed || !mounted) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final r = await http.post(
        Uri.parse(ApiConfig.getUrl('onboarding/debts/${widget.debt['id']}/topup')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId, 'amount': amt}),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['status'] == 'success') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(d['message']?.toString() ?? 'Payment applied'),
            backgroundColor: AppColors.financeGreen,
            behavior: SnackBarBehavior.floating,
          ));
          widget.onDone();
        }
      } else {
        setState(() => _error = d['message']?.toString() ?? 'Could not apply payment');
      }
    } catch (_) {
      setState(() => _error = 'Network error — check your connection');
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final outstanding = double.tryParse(widget.debt['amount_owed']?.toString() ?? '0') ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, mq.padding.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
            Text('Top Up ${widget.debt['creditor_name'] ?? 'Debt'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('KES ${_fmt.format(outstanding)} outstanding',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            const Text('Amount to Pay (KES)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
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
            const SizedBox(height: 6),
            const Text('Paid from your Nebo wallet balance.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
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
                    : const Text('Confirm Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Confirm Repayment sheet: sends money already saved (via Top Up) onward
// to the registered creditor's wallet for real — the lock point, distinct
// from Top Up which only moves money between the user's own goals. Only
// shown for debts with a registered creditor_id (see the _DebtCard button).
class _ConfirmRepaymentSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> debt;
  final VoidCallback onDone;
  const _ConfirmRepaymentSheet({required this.userId, required this.debt, required this.onDone});

  @override
  State<_ConfirmRepaymentSheet> createState() => _ConfirmRepaymentSheetState();
}

class _ConfirmRepaymentSheetState extends State<_ConfirmRepaymentSheet> {
  late final _amtCtrl = TextEditingController(
    text: (double.tryParse(widget.debt['goal_saved_amount']?.toString() ?? '0') ?? 0).round().toString(),
  );
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
    final authed = await TransactionAuthService.authenticate(context);
    if (!authed || !mounted) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final r = await http.post(
        Uri.parse(ApiConfig.getUrl('onboarding/debts/${widget.debt['id']}/confirm-repayment')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': widget.userId, 'amount': amt}),
      );
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['status'] == 'success') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(d['message']?.toString() ?? 'Repayment confirmed'),
            backgroundColor: AppColors.financeGreen,
            behavior: SnackBarBehavior.floating,
          ));
          widget.onDone();
        }
      } else {
        setState(() => _error = d['message']?.toString() ?? 'Could not confirm repayment');
      }
    } catch (_) {
      setState(() => _error = 'Network error — check your connection');
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final saved = double.tryParse(widget.debt['goal_saved_amount']?.toString() ?? '0') ?? 0;
    final creditorName = widget.debt['registered_creditor_name']?.toString() ?? widget.debt['creditor_name']?.toString() ?? 'Creditor';
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, mq.padding.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
            Text('Confirm Repayment to $creditorName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('KES ${_fmt.format(saved)} saved and ready to send',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            const Text('Amount to Send (KES)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
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
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5)),
              ),
            ),
            const SizedBox(height: 6),
            Text('This sends money out of your Nebo account to $creditorName — it cannot be moved back once confirmed.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
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
                  backgroundColor: const Color(0xFF0EA5E9),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Repayment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
