// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';

class TransactionHistory extends StatefulWidget {
  final String userId;
  const TransactionHistory({super.key, required this.userId});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory>
    with SingleTickerProviderStateMixin {
  String _filter = 'All';
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _error = false;
  double _walletBalance = 0;
  DateTime? _customStart;
  DateTime? _customEnd;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  final fmt = NumberFormat('#,##0.00');

  static const _filters = ['All', 'Today', 'Week', 'Month'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetch();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = false; });
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${AppConstants.apiBaseUrl}/transactions/${widget.userId}')).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse('${AppConstants.apiBaseUrl}/wallet/${widget.userId}')).timeout(const Duration(seconds: 10)),
      ]);
      final txRes = results[0];
      final walletRes = results[1];
      if (txRes.statusCode == 200) {
        final data = jsonDecode(txRes.body);
        if (data['status'] == 'success' && data['data'] is List) {
          _all = List<Map<String, dynamic>>.from(data['data']);
          _applyFilter(_filter);
        } else {
          setState(() { _loading = false; _error = true; });
          return;
        }
      } else {
        setState(() { _loading = false; _error = true; });
        return;
      }
      if (walletRes.statusCode == 200) {
        final wd = jsonDecode(walletRes.body);
        _walletBalance = double.tryParse((wd['data']?['balance'] ?? 0).toString()) ?? 0;
      }
      setState(() => _loading = false);
      _fadeCtrl.forward(from: 0);
    } catch (_) {
      setState(() { _loading = false; _error = true; });
    }
  }

  void _applyFilter(String f, {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now();
    setState(() {
      _filter = f;
      if (f == 'Custom') {
        _customStart = customStart ?? _customStart;
        _customEnd = customEnd ?? _customEnd;
      }
      _filtered = _all.where((t) {
        if (f == 'All') return true;
        DateTime? dt;
        try { dt = DateTime.parse(t['created_at'] ?? '').toLocal(); } catch (_) { return false; }
        if (f == 'Today') return dt.year == now.year && dt.month == now.month && dt.day == now.day;
        if (f == 'Week') {
          final start = now.subtract(Duration(days: now.weekday - 1));
          return dt.isAfter(DateTime(start.year, start.month, start.day).subtract(const Duration(seconds: 1)));
        }
        if (f == 'Month') return dt.year == now.year && dt.month == now.month;
        if (f == 'Custom') {
          final s = _customStart;
          final e = _customEnd;
          if (s == null) return true;
          final endOfDay = e != null ? DateTime(e.year, e.month, e.day, 23, 59, 59) : DateTime(s.year, s.month, s.day, 23, 59, 59);
          return !dt.isBefore(DateTime(s.year, s.month, s.day)) && !dt.isAfter(endOfDay);
        }
        return true;
      }).toList();
    });
  }

  Future<void> _openCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.financeGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _applyFilter('Custom', customStart: picked.start, customEnd: picked.end);
    }
  }


  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.backgroundLight,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Transaction History',
                style: TextStyle(color: Color(0xFF111827), fontSize: 19, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.financeGreen),
                  onPressed: _fetch,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: const Color(0xFFE5E7EB)),
              ),
            ),
          ],
          body: _loading
              ? const _LoadingShimmer()
              : _error
                  ? _ErrorView(onRetry: _fetch)
                  : FadeTransition(
                      opacity: _fade,
                      child: CustomScrollView(
                        slivers: [
                          // ── Summary card ───────────────────────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _SummaryCard(
                                walletBalance: _walletBalance,
                                count: _filtered.length,
                                fmt: fmt,
                              ),
                            ),
                          ),

                          // ── Filter chips ───────────────────────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ..._filters.map((f) => _FilterChip(
                                      label: f,
                                      selected: _filter == f,
                                      onTap: () => _applyFilter(f),
                                    )),
                                    _FilterChip(
                                      label: _filter == 'Custom' && _customStart != null
                                          ? '${_customStart!.day}/${_customStart!.month} – ${(_customEnd ?? _customStart)!.day}/${(_customEnd ?? _customStart)!.month}'
                                          : 'Custom',
                                      selected: _filter == 'Custom',
                                      onTap: _openCustomRange,
                                      icon: Icons.date_range_rounded,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── List ───────────────────────────────────────────────
                          if (_filtered.isEmpty)
                            SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72, height: 72,
                                      decoration: BoxDecoration(
                                        color: AppColors.financeGreen.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.receipt_long_outlined, color: AppColors.financeGreen, size: 34),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('No transactions found',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                                    const SizedBox(height: 6),
                                    Text('for $_filter', style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                                  ],
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    final t = _filtered[i];
                                    // group header — show date label if different from previous
                                    final showHeader = i == 0 || !_sameDay(
                                      _filtered[i - 1]['created_at'],
                                      t['created_at'],
                                    );
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (showHeader) _DateHeader(raw: t['created_at'] ?? ''),
                                        _TxRow(tx: t, fmt: fmt),
                                      ],
                                    );
                                  },
                                  childCount: _filtered.length,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  bool _sameDay(String? a, String? b) {
    try {
      final da = DateTime.parse(a!).toLocal();
      final db = DateTime.parse(b!).toLocal();
      return da.year == db.year && da.month == db.month && da.day == db.day;
    } catch (_) { return false; }
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double walletBalance;
  final int count;
  final NumberFormat fmt;
  const _SummaryCard({required this.walletBalance, required this.count, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B6631), Color(0xFF2D8A47)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1B6631).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(
                  'KES ${fmt.format(walletBalance)}',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text('$count', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const Text('transactions', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.financeGreen : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.financeGreen : const Color(0xFFE5E7EB),
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? Colors.white : const Color(0xFF6B7280)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Group Header ─────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String raw;
  const _DateHeader({required this.raw});

  @override
  Widget build(BuildContext context) {
    String label = raw;
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        label = 'Today';
      } else if (dt.day == now.day - 1 && dt.month == now.month && dt.year == now.year) {
        label = 'Yesterday';
      } else {
        label = DateFormat('EEEE, d MMMM').format(dt);
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
      ),
    );
  }
}

// ── Transaction Row ───────────────────────────────────────────────────────────
class _TxRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final NumberFormat fmt;
  const _TxRow({required this.tx, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final type = (tx['type']?.toString() ?? '').toLowerCase();
    final isIn = type.contains('deposit');
    final amount = double.tryParse((tx['total_amount'] ?? 0).toString()) ?? 0;

    final title = tx['business_name']?.toString().isNotEmpty == true
        ? tx['business_name'].toString()
        : isIn
            ? 'Wallet Deposit'
            : type.contains('pay_bill')
                ? 'Pay Bill'
                : type.contains('buy_goods')
                    ? 'Buy Goods'
                    : 'Transaction';

    String timeStr = '';
    try {
      timeStr = DateFormat('HH:mm').format(DateTime.parse(tx['created_at'] ?? '').toLocal());
    } catch (_) {}

    final color = isIn ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final bgColor = isIn ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);

    IconData icon;
    if (isIn) {
      icon = Icons.arrow_downward_rounded;
    } else if (type.contains('pay_bill')) {
      icon = Icons.account_balance_rounded;
    } else if (type.contains('buy_goods')) {
      icon = Icons.shopping_bag_rounded;
    } else {
      icon = Icons.arrow_upward_rounded;
    }

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
              width: 46, height: 46,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      const Text('Completed', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w500)),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${isIn ? '+' : '-'}KES ${fmt.format(amount.abs())}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction Detail Bottom Sheet ──────────────────────────────────────────
void showTransactionDetail(BuildContext context, Map<String, dynamic> tx, NumberFormat fmt) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TxDetailSheet(tx: tx, fmt: fmt),
  );
}

class _TxDetailSheet extends StatelessWidget {
  final Map<String, dynamic> tx;
  final NumberFormat fmt;
  const _TxDetailSheet({required this.tx, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final type = (tx['type']?.toString() ?? '').toLowerCase();
    final isIn = type.contains('deposit');
    final amount = double.tryParse((tx['total_amount'] ?? 0).toString()) ?? 0;
    final savings = double.tryParse((tx['savings_amount'] ?? 0).toString()) ?? 0;
    final status = (tx['transaction_status'] ?? tx['status'] ?? 'completed').toString().toLowerCase();

    final title = tx['business_name']?.toString().isNotEmpty == true
        ? tx['business_name'].toString()
        : isIn
            ? 'Wallet Deposit'
            : type.contains('pay_bill')
                ? 'Pay Bill'
                : type.contains('buy_goods')
                    ? 'Buy Goods'
                    : type.contains('withdraw')
                        ? 'Withdrawal'
                        : 'Transaction';

    String dateStr = '';
    try {
      final dt = DateTime.parse(tx['created_at'] ?? '').toLocal();
      dateStr = DateFormat('EEEE, d MMMM yyyy • HH:mm').format(dt);
    } catch (_) {}

    final color = isIn ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final bgColor = isIn ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);

    IconData icon;
    if (isIn) {
      icon = Icons.arrow_downward_rounded;
    } else if (type.contains('pay_bill')) {
      icon = Icons.account_balance_rounded;
    } else if (type.contains('buy_goods')) {
      icon = Icons.shopping_bag_rounded;
    } else if (type.contains('withdraw')) {
      icon = Icons.arrow_upward_rounded;
    } else {
      icon = Icons.receipt_long_rounded;
    }

    Color statusColor;
    String statusLabel;
    if (status == 'completed') {
      statusColor = const Color(0xFF059669);
      statusLabel = 'Completed';
    } else if (status == 'failed') {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'Failed';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Pending';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),

          // Icon + title
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(
            '${isIn ? '+' : '-'}KES ${fmt.format(amount.abs())}',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(statusLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 20),

          // Detail rows
          _DetailRow(label: 'Date & Time', value: dateStr.isNotEmpty ? dateStr : '—'),
          _DetailRow(label: 'Type', value: _typeLabel(type)),
          if ((tx['business_name']?.toString() ?? '').isNotEmpty)
            _DetailRow(label: 'Merchant', value: tx['business_name'].toString()),
          if (savings > 0)
            _DetailRow(label: 'Amount Saved', value: 'KES ${fmt.format(savings)}', valueColor: const Color(0xFF059669)),
          if ((tx['id'] ?? '').toString().isNotEmpty)
            _DetailRow(label: 'Transaction ID', value: '#${tx['id']}'),

          const SizedBox(height: 24),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.financeGreen,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    if (type.contains('deposit')) return 'Deposit';
    if (type.contains('pay_bill')) return 'Pay Bill';
    if (type.contains('buy_goods')) return 'Buy Goods';
    if (type.contains('withdraw')) return 'Withdrawal';
    if (type.contains('remittance')) return 'Remittance';
    return 'Transaction';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF111827),
                ),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ── Loading Shimmer ───────────────────────────────────────────────────────────
class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          _Shimmer(height: 90, radius: 20),
          const SizedBox(height: 16),
          Row(children: List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Shimmer(height: 36, width: 72, radius: 24),
          ))),
          const SizedBox(height: 20),
          ...List.generate(6, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Shimmer(height: 70, radius: 16),
          )),
        ],
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const _Shimmer({required this.height, this.width, required this.radius});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 0.8).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      height: widget.height,
      width: widget.width ?? double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: _anim.value),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

// ── Error View ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 34),
          ),
          const SizedBox(height: 16),
          const Text('Could not load transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 6),
          const Text('Check your connection', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.financeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
